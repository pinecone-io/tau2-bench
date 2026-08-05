#!/usr/bin/env python3
"""Write clean RESULTS_SCOREBOARD.md into completed v2 run packs."""
from __future__ import annotations

import json
import shutil
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PUB_CACHE = Path("/tmp/opus5_published_trial0_metrics.json")
BOARD = 48.71


def load_pub() -> dict:
    if PUB_CACHE.exists():
        return json.loads(PUB_CACHE.read_text())
    return {}


def write_pack(pack: Path, title: str, query_model: str) -> None:
    res = pack / "results.json"
    if not res.exists():
        print("skip no results", pack)
        return
    d = json.loads(res.read_text())
    sims = [s for s in (d.get("simulations") or []) if s]
    if len(sims) < 97:
        print(f"skip incomplete {pack.name} n={len(sims)}")
        return
    pub = load_pub()
    nexus: dict[str, dict] = {}
    up = pack / "nexus_usage.jsonl"
    if up.exists():
        for line in up.read_text().splitlines():
            if not line.strip():
                continue
            r = json.loads(line)
            tid = r.get("task_id")
            if not tid:
                continue
            nexus.setdefault(tid, {"q": 0, "cost": 0.0})
            nexus[tid]["q"] += 1
            if r.get("cost_usd") is not None:
                nexus[tid]["cost"] += float(r["cost_usd"])

    pn = sum(1 for s in sims if float((s.get("reward_info") or {}).get("reward") or 0) >= 1)
    ac = sum(float(s.get("agent_cost") or 0) for s in sims)
    nq = sum(v["q"] for v in nexus.values())
    nc = sum(v["cost"] for v in nexus.values())
    pct = 100 * pn / 97

    lines = [
        f"# Results — {title}",
        "",
        "> Standard template: [`REPORTING_TEMPLATE.md`](../../REPORTING_TEMPLATE.md)",
        "",
        f"**Status:** `DONE`  ",
        f"**Save / pack:** `{pack.name}`  ",
        f"**Query model:** `{query_model}`  ",
        f"**Setup:** v2 · context `taubench-v2`  ",
        "",
        "## Totals vs leaderboard",
        "",
        "| Metric | Ours (this run) | Published Opus 5 alltools |",
        "|--------|----------------:|--------------------------:|",
        f"| Progress | **{len(sims)}/97** | 97/97 (trial 0) |",
        f"| Pass / rate | **{pn}/97 ({pct:.1f}%)** | **49/97 (50.5%)** · board pass¹ **{BOARD}%** |",
        f"| Δ vs board pass¹ | **{pct - BOARD:+.1f} pp** | baseline |",
        f"| Agent cost (model) | **${ac:.2f}** | **$1311.51** (t0 sum) |",
        (
            f"| Nexus query cost | **${nc:.2f}** ({nq} queries) | n/a |"
            if nq
            else "| Nexus query cost | not logged | n/a |"
        ),
        "",
        f"Ours = `claude-opus-5` + `{query_model}` + setup **v2**. "
        "Published = Sierra alltools trial 0 (no Nexus).",
        "",
        "## Per-task table",
        "",
        "| task | our_score | our_agent_$ | our_tools | our_msgs | "
        "nexus_q | nexus_$ | pub_score | pub_agent_$ | pub_tools | pub_msgs |",
        "|------|----------:|------------:|----------:|---------:|"
        "--------:|--------:|----------:|------------:|----------:|---------:|",
    ]
    for s in sorted(sims, key=lambda x: x["task_id"]):
        tid = s["task_id"]
        rew = float((s.get("reward_info") or {}).get("reward") or 0)
        acs = float(s.get("agent_cost") or 0)
        msgs = s.get("messages") or []
        n_tc = sum(len(m.get("tool_calls") or []) for m in msgs)
        n_kb = sum(
            1
            for m in msgs
            for tc in (m.get("tool_calls") or [])
            if (tc.get("name") or "") == "KB_query"
        )
        if tid in nexus:
            nq_t, nc_s = nexus[tid]["q"], f"${nexus[tid]['cost']:.2f}"
        else:
            nq_t, nc_s = n_kb, "—"
        p = pub.get(tid) or {}
        ps = 1 if (p.get("score") or 0) >= 1 else 0
        lines.append(
            f"| {tid} | {1 if rew >= 1 else 0} | ${acs:.2f} | {n_tc} | {len(msgs)} | "
            f"{nq_t} | {nc_s} | {ps} | ${float(p.get('agent_cost') or 0):.2f} | "
            f"{p.get('tool_calls', '—')} | {p.get('messages', '—')} |"
        )
    lines += [
        "",
        "## Notes",
        "",
        "- Setup **v2** · `taubench-v2` (clean names).",
        "- Board pass¹ 48.71% is 4-trial; pub_score is trial0 only.",
        "",
    ]
    text = "\n".join(lines) + "\n"
    (pack / "RESULTS_SCOREBOARD.md").write_text(text)
    (pack / "MANIFEST.md").write_text(
        f"# Run pack `{pack.name}`\n\n"
        f"- Agent: claude-opus-5\n- Query: {query_model}\n"
        f"- Setup: v2 / taubench-v2\n- Pass: {pn}/97 ({pct:.1f}%)\n"
        f"- Agent cost: ${ac:.2f}\n"
        f"- Nexus query cost: ${nc:.2f} ({nq} q)\n"
        f"- Files: results.json, RESULTS_SCOREBOARD.md, nexus_usage.jsonl, "
        f"runner.log, RUN_META.json, published_trial0_metrics.json\n"
    )
    meta = {
        "pack": pack.name,
        "setup": "v2",
        "context": "taubench-v2",
        "agent": "claude-opus-5",
        "query_model": query_model,
        "pass": f"{pn}/97",
        "pass_pct": round(pct, 2),
        "agent_cost_usd": round(ac, 2),
        "nexus_query_cost_usd": round(nc, 2) if nq else None,
        "nexus_queries": nq or None,
    }
    (pack / "RUN_META.json").write_text(json.dumps(meta, indent=2))
    if PUB_CACHE.exists():
        shutil.copy2(PUB_CACHE, pack / "published_trial0_metrics.json")
    docs = REPO / "docs/runs"
    if "sonnet" in pack.name:
        (docs / "OPUS5_V2_SONNET5Q_FULL97_RESULTS.md").write_text(text)
    if "glm" in pack.name:
        (docs / "OPUS5_V2_GLM52Q_FULL97_RESULTS.md").write_text(text)
    print(f"scoreboard {pack.name}: {pn}/97 ${ac:.2f}")


def main() -> None:
    pairs = [
        (
            "leaderboard_nexus_full97_opus5_t1_s300_c8_v2_sonnet5q_20260805_150027",
            "Opus 5 agent · Sonnet-5 Nexus query · setup v2",
            "claude-sonnet-5",
        ),
        (
            "leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416",
            "Opus 5 agent · GLM-5.2 Nexus query · setup v2",
            "zai-org/GLM-5.2",
        ),
    ]
    for name, title, qm in pairs:
        p = REPO / "data/simulations" / name
        if p.is_dir():
            write_pack(p, title, qm)


if __name__ == "__main__":
    main()
