#!/usr/bin/env python3
"""Fidelity micro-probe: curate the A1 manifest over a small trap-doc subset
and read back the built artifacts for verification (papers 0031/0033 gate).

Selects documents spanning the corpus's designed traps (confusable product
trios, waiver-vs-minimum tables, placeholder values, verbatim tool names),
builds a probe context under the given manifest, then dumps the knowledge
tree and every artifact so trap values can be checked against sources.
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

PROBE_PREFIXES = [
    "doc_credit_cards_silver_rewards_card",
    "doc_business_credit_cards_business_silver_rewards_card",
    "doc_business_credit_cards_silver_zoom_card",
    "doc_business_checking_accounts_beige",
    "doc_buy_now_pay_later_bnpl_bronze",
]


def pick_docs() -> list[Path]:
    import re

    picked: list[Path] = []
    for prefix in PROBE_PREFIXES:
        matches = sorted(DOCS_DIR.glob(f"{prefix}_*.json"))[:3]
        picked.extend(matches)
    # The beige fee/waiver trap table lives in beige_010 specifically.
    picked.extend(DOCS_DIR.glob("doc_business_checking_accounts_beige_010.json"))
    # A single-workflow cluster of internal dispute docs, so the corpus-scoped
    # playbook type has >= min_doc_count sources for one workflow, plus
    # verbatim tool-name material.
    for f in sorted(DOCS_DIR.glob("*.json")):
        d = json.loads(f.read_text())
        if d["title"].startswith("Internal:") and re.search(
            r"Dispute|Provisional Credit", d["title"]
        ):
            picked.append(f)
    return sorted(set(picked))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--slug", default="rdev-taub-probe")
    ap.add_argument("--manifest", default=str(REPO_ROOT / "manifests" / "a1-full.json"))
    ap.add_argument("--nexus-url", default=os.environ.get("NEXUS_URL", "https://dev.nexus.pinecone.io"))
    ap.add_argument("--fresh", action="store_true")
    args = ap.parse_args()

    url = args.nexus_url.rstrip("/")
    key = os.environ.get("PINECONE_API_KEY", "").strip()
    if not key:
        sys.exit("Set PINECONE_API_KEY.")
    token = httpx.post(f"{url}/api/v0/auth/login", json={"api_key": key}, timeout=30).json()["token"]
    h = {"Authorization": f"Bearer {token}"}
    api = f"{url}/api/v0"

    def wait_idle(label, timeout_s=2400):
        deadline = time.monotonic() + timeout_s
        while time.monotonic() < deadline:
            stats = httpx.get(f"{api}/contexts/{args.slug}/tasks/stats", headers=h, timeout=60).json()
            if int(stats.get("tasks_failed") or 0) > 0:
                print(f"  {label}: WARNING failed tasks: {json.dumps(stats)}")
            if int(stats.get("tasks_active") or 0) == 0:
                print(f"  {label}: idle")
                return
            time.sleep(10)
        sys.exit(f"{label}: timeout")

    docs = pick_docs()
    print(f"probe docs ({len(docs)}):")
    for f in docs:
        print(f"  {f.stem}")

    if args.fresh:
        r = httpx.delete(f"{api}/contexts/{args.slug}", headers=h, timeout=120)
        print(f"delete: HTTP {r.status_code}")

    manifest = json.loads(Path(args.manifest).read_text())
    r = httpx.post(f"{api}/contexts", headers=h, timeout=60,
                   json={"slug": args.slug, "name": args.slug, "manifest": manifest})
    if r.status_code == 409:
        r = httpx.put(f"{api}/contexts/{args.slug}", headers=h, json={"manifest": manifest}, timeout=60)
    if r.status_code != 200:
        sys.exit(f"context create/update failed HTTP {r.status_code}: {r.text[:500]}")
    print(f"context {args.slug}: manifest accepted (HTTP {r.status_code})")

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        for f in docs:
            d = json.loads(f.read_text())
            zf.writestr(f"{d['id']}.md", f"# {d['title']}\n\n{d['content']}\n")
    r = httpx.post(f"{api}/contexts/{args.slug}/import/upload", headers=h, params={"path": "docs"},
                   files={"file": ("probe-docs.zip", buf.getvalue(), "application/zip")}, timeout=120)
    r.raise_for_status()
    print(f"upload: {r.json()}")
    wait_idle("source-publish")

    r = httpx.post(f"{api}/contexts/{args.slug}/curate", headers=h, json={"force": True}, timeout=60)
    r.raise_for_status()
    print(f"curate: {r.json()}")
    wait_idle("curate")

    r = httpx.get(f"{api}/contexts/{args.slug}/knowledge/list", headers=h, params={"limit": 500}, timeout=60)
    r.raise_for_status()
    listing = r.json()
    print("\n=== knowledge tree ===")
    print(json.dumps(listing, indent=1)[:3000])

    entries = listing if isinstance(listing, list) else listing.get("entries") or listing.get("files") or []
    paths = []
    for e in entries:
        p = e.get("path") if isinstance(e, dict) else str(e)
        if p:
            paths.append(p)
    outdir = Path("/tmp/probe-artifacts")
    outdir.mkdir(exist_ok=True)
    for p in paths[:200]:
        rr = httpx.get(f"{api}/contexts/{args.slug}/knowledge/read/{p}", headers=h, timeout=60)
        if rr.status_code == 200:
            target = outdir / p.replace("/", "__")
            target.write_bytes(rr.content)
    print(f"\nartifacts downloaded to {outdir} ({len(list(outdir.iterdir()))} files)")


if __name__ == "__main__":
    main()
