#!/usr/bin/env python3
"""Build a Nexus context from the banking_knowledge corpus.

Converts the domain's JSON documents to markdown, uploads them as one
archive, curates under the given manifest, and runs the one-time optimize
that makes a Search context queryable. After optimize, the manifest is
re-fetched and compared to the submitted one; on drift it is re-PUT and a
forced re-curate runs, so the context ends queryable under the exact
manifest given (optimize's queryable stamp is never cleared by later
curates).

Auth: PINECONE_API_KEY or NEXUS_TOKEN in the environment.

Usage:
  python scripts/nexus_build_context.py --slug rdev-taub-a0 \
      --manifest manifests/a0-chunks-only.json [--nexus-url URL] [--fresh]
"""

import argparse
import io
import json
import os
import sys
import time
import zipfile
from pathlib import Path

import httpx

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_DIR = REPO_ROOT / "data" / "tau2" / "domains" / "banking_knowledge" / "documents"
POLL_SECONDS = 10
SMOKE_QUESTION = (
    "What is the monthly maintenance fee for the Beige business checking "
    "account, and what balance waives it?"
)


def login(url: str) -> str:
    token = os.environ.get("NEXUS_TOKEN", "").strip()
    if token:
        return token
    key = os.environ.get("PINECONE_API_KEY", "").strip()
    if not key:
        sys.exit("Set PINECONE_API_KEY or NEXUS_TOKEN.")
    resp = httpx.post(f"{url}/api/v0/auth/login", json={"api_key": key}, timeout=30)
    resp.raise_for_status()
    return resp.json()["token"]


class Api:
    def __init__(self, url: str, token: str):
        self.url = url
        self.headers = {"Authorization": f"Bearer {token}"}

    def request(self, method: str, path: str, **kwargs) -> httpx.Response:
        return httpx.request(
            method,
            f"{self.url}{path}",
            headers=self.headers,
            timeout=120,
            **kwargs,
        )

    def wait_idle(self, slug: str, label: str, timeout_s: int = 3600) -> None:
        """Poll per-context task stats until no tasks are pending/running."""
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            resp = self.request("GET", f"/contexts/{slug}/tasks/stats")
            resp.raise_for_status()
            stats = resp.json()
            active = int(stats.get("tasks_active") or 0)
            if int(stats.get("tasks_failed") or 0) > 0:
                print(f"  {label}: WARNING failed tasks present ({json.dumps(stats)})")
            if active == 0:
                print(f"  {label}: idle ({json.dumps(stats)})")
                return
            print(f"  {label}: {active} active task(s)...")
            time.sleep(POLL_SECONDS)
        sys.exit(f"{label}: still busy after {timeout_s}s")


def docs_archive() -> bytes:
    buf = io.BytesIO()
    count = 0
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in sorted(DOCS_DIR.glob("*.json")):
            doc = json.loads(f.read_text())
            body = f"# {doc['title']}\n\n{doc['content']}\n"
            zf.writestr(f"{doc['id']}.md", body)
            count += 1
    print(f"archived {count} documents as markdown")
    return buf.getvalue()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", required=True)
    ap.add_argument("--manifest", required=True, help="Path to manifest.json")
    ap.add_argument("--nexus-url", default=os.environ.get("NEXUS_URL", "https://dev.nexus.pinecone.io"))
    ap.add_argument("--fresh", action="store_true", help="Delete the context first if it exists")
    ap.add_argument("--skip-upload", action="store_true", help="Sources already staged; resume from curate")
    ap.add_argument("--skip-smoke", action="store_true")
    args = ap.parse_args()

    manifest = json.loads(Path(args.manifest).read_text())
    url = args.nexus_url.rstrip("/")
    api = Api(f"{url}/api/v0", login(url))

    if args.fresh:
        resp = api.request("DELETE", f"/contexts/{args.slug}")
        print(f"delete {args.slug}: HTTP {resp.status_code}")

    resp = api.request(
        "POST",
        "/contexts",
        json={"slug": args.slug, "name": args.slug, "manifest": manifest},
    )
    if resp.status_code == 409:
        print(f"context {args.slug} exists; updating manifest in place")
        resp = api.request("PUT", f"/contexts/{args.slug}", json={"manifest": manifest})
    resp.raise_for_status()
    print(f"context {args.slug}: ready (HTTP {resp.status_code})")

    if not args.skip_upload:
        resp = api.request(
            "POST",
            f"/contexts/{args.slug}/import/upload",
            params={"path": "docs"},
            files={"file": ("banking-docs.zip", docs_archive(), "application/zip")},
        )
        resp.raise_for_status()
        print(f"upload: HTTP {resp.status_code} {resp.json()}")
    api.wait_idle(args.slug, "source-publish")

    resp = api.request("POST", f"/contexts/{args.slug}/curate", json={"force": True})
    resp.raise_for_status()
    print(f"curate: HTTP {resp.status_code} {resp.json()}")
    api.wait_idle(args.slug, "curate")

    resp = api.request("POST", f"/contexts/{args.slug}/optimize", json={})
    resp.raise_for_status()
    print(f"optimize: HTTP {resp.status_code} {resp.json()}")
    api.wait_idle(args.slug, "optimize", timeout_s=7200)

    resp = api.request("GET", f"/contexts/{args.slug}/manifest")
    resp.raise_for_status()
    live = resp.json()
    if live != manifest:
        print("WARNING: optimize drifted the manifest; restoring the frozen one")
        api.request("PUT", f"/contexts/{args.slug}", json={"manifest": manifest}).raise_for_status()
        api.request("POST", f"/contexts/{args.slug}/curate", json={"force": True}).raise_for_status()
        api.wait_idle(args.slug, "re-curate")
        print("frozen manifest restored and re-curated")
    else:
        print("manifest verified: unchanged by optimize")

    if not args.skip_smoke:
        resp = api.request(
            "POST",
            "/query",
            json={"scope": [args.slug], "ask": SMOKE_QUESTION, "background": True},
        )
        resp.raise_for_status()
        qid = resp.json()["id"]
        for _ in range(120):
            row = api.request("GET", f"/queries/{qid}").json()
            if row.get("status") in ("completed", "failed", "cancelled"):
                break
            time.sleep(5)
        text = "".join(
            part.get("text", "")
            for item in row.get("output") or []
            for part in item.get("content") or []
            if part.get("type") == "output_text"
        )
        print(f"smoke query [{row.get('status')}]: {text[:400]}")

    print(f"context {args.slug} build complete")


if __name__ == "__main__":
    main()
