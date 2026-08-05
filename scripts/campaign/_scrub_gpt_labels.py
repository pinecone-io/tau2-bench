#!/usr/bin/env python3
"""Replace v1/v2/taubench-gpt* labels with v1/v2 in our owned files."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

ROOTS = [
    REPO / "configs/nexus_setups",
    REPO / "docs/runs",
    REPO / "scripts/campaign",
    REPO / "scripts/run_nexus_setup.sh",
    REPO / "scripts/run_baseline_banking_nexus.sh",
    REPO / "scripts/run_full_nexus_v2.sh",
    REPO / "scripts/run_leaderboard_banking_nexus_legacy.sh",
    REPO / "src/tau2/knowledge/README.md",
]
# sim packs (meta/md only)
for p in (REPO / "data/simulations").glob("leaderboard_nexus_full97_opus5*"):
    ROOTS.append(p)

REPLS: list[tuple[str, str]] = [
    (r"taubench-v2", "taubench-v2"),
    (r"taubench-v1", "taubench-v1"),
    (r"configs/nexus_setups/v2", "configs/nexus_setups/v2"),
    (r"configs/nexus_setups/v1", "configs/nexus_setups/v1"),
    (r"SETUP=v2", "SETUP=v2"),
    (r"SETUP=v1", "SETUP=v1"),
    (r"setup=v2", "setup=v2"),
    (r"setup=v1", "setup=v1"),
    (r"\bgpt55\b", "v2"),
    (r"\bgpt51\b", "v1"),
    (
        r"leaderboard_nexus_full97_opus5_t1_s300_c8_v2_sonnet5q_20260805_150027",
        "leaderboard_nexus_full97_opus5_t1_s300_c8_v2_sonnet5q_20260805_150027",
    ),
    (
        r"leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416",
        "leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416",
    ),
    (
        r"leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145",
        "leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145",
    ),
    (r"launch_v2_fullsuite", "launch_v2_fullsuite"),
    (r"run_full_nexus_v2", "run_full_nexus_v2"),
    (r"v2_opus5_glm52q", "v2_opus5_glm52q"),
]

SKIP_NAMES = {"results.json"}
SKIP_SUFFIX = {".pyc"}


def iter_files():
    for root in ROOTS:
        if not root.exists():
            continue
        if root.is_file():
            yield root
            continue
        for p in root.rglob("*"):
            if p.is_file():
                yield p


def main() -> None:
    changed = []
    for p in iter_files():
        if p.name in SKIP_NAMES or p.suffix in SKIP_SUFFIX:
            continue
        if p.suffix not in {".md", ".sh", ".py", ".env", ".txt", ".json"}:
            continue
        # skip huge or binary-ish
        if p.stat().st_size > 2_000_000:
            continue
        try:
            text = p.read_text(encoding="utf-8")
        except Exception:
            continue
        orig = text
        for pat, rep in REPLS:
            text = re.sub(pat, rep, text)
        if text != orig:
            p.write_text(text, encoding="utf-8")
            changed.append(str(p.relative_to(REPO)))
    print(f"scrubbed {len(changed)} files")
    for c in changed[:50]:
        print(" ", c)


if __name__ == "__main__":
    main()
