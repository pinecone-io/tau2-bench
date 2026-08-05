#!/usr/bin/env python3
"""Refresh the live Opus5+GLM query vs published alltools scoreboard markdown."""

from __future__ import annotations

import json
import os
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean, median

REPO = Path(__file__).resolve().parents[2]
OUT_MD = REPO / "docs/runs/OPUS5_GLM52Q_LIVE_SCOREBOARD.md"
PUB_CACHE = Path("/tmp/opus5_published_trial0_metrics.json")
BOARD_PASS1 = 48.71  # published Claude Opus 5 alltools pass^1 (leaderboard)
BOARD_T0_PASS = 49  # trial0 exact from trajs
BOARD_T0_N = 97


def _load_paths() -> tuple[str, Path, Path]:
    save = Path("/tmp/v2_opus5_glm52q.save").read_text().strip()
    usage = Path(Path("/tmp/v2_opus5_glm52q.usage_log").read_text().strip())
    results = REPO / "data/simulations" / save / "results.json"
    return save, results, usage


def _count_tools(messages: list) -> tuple[int, int]:
    n_tc = 0
    n_kb = 0
    for m in messages or []:
        for tc in m.get("tool_calls") or []:
            n_tc += 1
            name = tc.get("name") or (tc.get("function") or {}).get("name") or ""
            if name == "KB_query":
                n_kb += 1
    return n_tc, n_kb


def _our_rows(results_path: Path) -> dict[str, dict]:
    if not results_path.exists():
        return {}
    d = json.loads(results_path.read_text())
    out: dict[str, dict] = {}
    for s in d.get("simulations") or []:
        if not s:
            continue
        tid = s.get("task_id")
        msgs = s.get("messages") or []
        n_tc, n_kb = _count_tools(msgs)
        rew = (s.get("reward_info") or {}).get("reward")
        out[tid] = {
            "score": float(rew) if rew is not None else None,
            "agent_cost": float(s.get("agent_cost") or 0),
            "user_cost": float(s.get("user_cost") or 0),
            "tool_calls": n_tc,
            "messages": len(msgs),
            "nexus_queries": n_kb,
        }
    return out


def _nexus_by_task(usage_path: Path) -> dict[str, dict]:
    """Aggregate usage log rows keyed by task_id."""
    by: dict[str, dict] = defaultdict(
        lambda: {
            "nexus_queries": 0,
            "nexus_cost": 0.0,
            "wall_s": [],
            "runtime_s": [],
            "input_tokens": 0,
            "output_tokens": 0,
        }
    )
    if not usage_path.exists():
        return {}
    for line in usage_path.read_text().splitlines():
        if not line.strip():
            continue
        try:
            r = json.loads(line)
        except json.JSONDecodeError:
            continue
        tid = r.get("task_id") or "_unknown"
        b = by[tid]
        b["nexus_queries"] += 1
        if r.get("cost_usd") is not None:
            b["nexus_cost"] += float(r["cost_usd"])
        if r.get("wall_ms") is not None:
            b["wall_s"].append(float(r["wall_ms"]) / 1000)
        if r.get("runtime_ms") is not None:
            b["runtime_s"].append(float(r["runtime_ms"]) / 1000)
        b["input_tokens"] += int(r.get("input_tokens") or 0)
        b["output_tokens"] += int(r.get("output_tokens") or 0)
    return dict(by)


def _suite_running() -> bool:
    try:
        pid = int(Path("/tmp/v2_opus5_glm52q.pid").read_text().strip())
    except Exception:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def render() -> str:
    save, results_path, usage_path = _load_paths()
    our = _our_rows(results_path)
    nexus = _nexus_by_task(usage_path)
    pub = json.loads(PUB_CACHE.read_text()) if PUB_CACHE.exists() else {}

    # merge nexus counts into our when log has task_id; prefer log if present
    for tid, n in nexus.items():
        if tid == "_unknown":
            continue
        if tid not in our:
            continue
        # prefer usage-log query count if available (should match KB_query)
        if n["nexus_queries"]:
            our[tid]["nexus_queries"] = n["nexus_queries"]
        our[tid]["nexus_cost"] = n["nexus_cost"]
        our[tid]["nexus_wall_mean"] = mean(n["wall_s"]) if n["wall_s"] else None
        our[tid]["nexus_tokens"] = n["input_tokens"] + n["output_tokens"]

    # for tasks without usage-log task_id yet, nexus_cost may be missing
    for tid, row in our.items():
        row.setdefault("nexus_cost", None)
        row.setdefault("nexus_wall_mean", None)

    done = sorted(our.keys())
    n_done = len(done)
    our_pass = sum(1 for t in done if (our[t]["score"] or 0) >= 1)
    our_agent_cost = sum(our[t]["agent_cost"] for t in done)
    our_nexus_cost = sum(
        (our[t]["nexus_cost"] or 0) for t in done if our[t].get("nexus_cost") is not None
    )
    unknown_nq = nexus.get("_unknown", {}).get("nexus_queries", 0)
    unknown_cost = nexus.get("_unknown", {}).get("nexus_cost", 0.0)
    log_nq = sum(v["nexus_queries"] for v in nexus.values())
    log_cost = sum(v["nexus_cost"] for v in nexus.values())

    our_pct = 100.0 * our_pass / n_done if n_done else 0.0
    board_pct = BOARD_PASS1
    # projected if remaining all fail/pass bounds
    max_pass = our_pass + (97 - n_done)
    min_pass = our_pass

    status = "RUNNING" if _suite_running() else ("DONE" if n_done >= 97 else "STOPPED")
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

    # published totals (full 97 t0)
    pub_pass = sum(1 for r in pub.values() if (r.get("score") or 0) >= 1)
    pub_cost = sum(float(r.get("agent_cost") or 0) for r in pub.values())

    lines: list[str] = []
    lines.append("# Live scoreboard — Opus 5 agent · GLM-5.2 Nexus query · v2")
    lines.append("")
    lines.append(
        "> **Standard template:** [`REPORTING_TEMPLATE.md`](./REPORTING_TEMPLATE.md) "
        "— use this layout for all future published/live Nexus banking results."
    )
    lines.append("")
    lines.append(f"**Last update:** {ts}  ")
    lines.append(f"**Status:** `{status}`  ")
    lines.append(f"**Save:** `{save}`  ")
    lines.append(f"**Usage log:** `{usage_path}`  ")
    lines.append("")
    lines.append("## Totals vs leaderboard")
    lines.append("")
    lines.append("| Metric | Ours (this run) | Published Opus 5 alltools |")
    lines.append("|--------|----------------:|--------------------------:|")
    lines.append(
        f"| Progress | **{n_done}/97** | 97/97 (trial 0) |"
    )
    lines.append(
        f"| Pass / rate | **{our_pass}/{n_done} ({our_pct:.1f}%)** | "
        f"**{pub_pass}/97 ({100*pub_pass/97:.1f}%)** · board pass¹ **{board_pct}%** |"
    )
    if n_done and n_done < 97:
        lines.append(
            f"| Possible final band | {min_pass}–{max_pass}/97 "
            f"({100*min_pass/97:.1f}–{100*max_pass/97:.1f}%) | — |"
        )
    delta = our_pct - board_pct if n_done else float("nan")
    lines.append(
        f"| Δ vs board pass¹ (on completed) | "
        f"{'—' if n_done == 0 else f'**{delta:+.1f} pp**'} | baseline |"
    )
    lines.append(f"| Agent cost (model) | **${our_agent_cost:.2f}** | **${pub_cost:.2f}** (t0 sum) |")
    lines.append(
        f"| Nexus query cost (GLM) | **${log_cost:.2f}** ({log_nq} queries) | n/a |"
    )
    if unknown_nq:
        lines.append(
            f"| Usage rows missing task_id | {unknown_nq} queries · ${unknown_cost:.2f} | — |"
        )
    lines.append("")
    lines.append(
        "Ours = `claude-opus-5` agent + `zai-org/GLM-5.2` query + v2 pack.  "
        "Published = Sierra Claude Opus 5 · **alltools** · trial 0 (not Nexus)."
    )
    lines.append("")
    lines.append("## Per-task table")
    lines.append("")
    lines.append(
        "| task | our_score | our_agent_$ | our_tools | our_msgs | "
        "nexus_q | nexus_$ | pub_score | pub_agent_$ | pub_tools | pub_msgs |"
    )
    lines.append(
        "|------|----------:|------------:|----------:|---------:|"
        "--------:|--------:|----------:|------------:|----------:|---------:|"
    )

    # show completed ours first, then remaining with pub only
    all_tasks = sorted(set(pub.keys()) | set(our.keys()), key=lambda x: x or "")
    for tid in all_tasks:
        o = our.get(tid)
        p = pub.get(tid) or {}
        if o is None:
            # not done yet
            lines.append(
                f"| {tid} | — | — | — | — | — | — | "
                f"{_fmt_score(p.get('score'))} | {_fmt_money(p.get('agent_cost'))} | "
                f"{p.get('tool_calls', '—')} | {p.get('messages', '—')} |"
            )
            continue
        nq = o.get("nexus_queries", 0)
        nc = o.get("nexus_cost")
        lines.append(
            f"| {tid} | {_fmt_score(o.get('score'))} | {_fmt_money(o.get('agent_cost'))} | "
            f"{o.get('tool_calls', 0)} | {o.get('messages', 0)} | {nq} | "
            f"{_fmt_money(nc) if nc is not None else '—'} | "
            f"{_fmt_score(p.get('score'))} | {_fmt_money(p.get('agent_cost'))} | "
            f"{p.get('tool_calls', '—')} | {p.get('messages', '—')} |"
        )

    lines.append("")
    lines.append("## Notes")
    lines.append("")
    lines.append(
        "- `our_score` / `pub_score`: `1` pass · `0` fail · `—` not finished."
    )
    lines.append(
        "- `our_agent_$` / `pub_agent_$`: agent model cost only (not user-sim)."
    )
    lines.append(
        "- `nexus_q` / `nexus_$`: from `NEXUS_USAGE_LOG` joined by `task_id` "
        "(KB_query server tokens/cost/latency)."
    )
    lines.append(
        "- Published has **no** Nexus columns (alltools retrieval)."
    )
    lines.append(
        f"- Auto-refreshed every **5 minutes** while the suite runs. File: `{OUT_MD}`."
    )
    lines.append("")
    return "\n".join(lines)


def _fmt_score(v) -> str:
    if v is None:
        return "—"
    try:
        f = float(v)
    except (TypeError, ValueError):
        return "—"
    if f >= 1:
        return "1"
    return "0"


def _fmt_money(v) -> str:
    if v is None:
        return "—"
    try:
        return f"${float(v):.2f}"
    except (TypeError, ValueError):
        return "—"


def main() -> None:
    text = render()
    OUT_MD.parent.mkdir(parents=True, exist_ok=True)
    OUT_MD.write_text(text)
    print(f"wrote {OUT_MD} ({len(text)} bytes)")
    # Keep a single run pack folder in sync
    try:
        save, results_path, usage_path = _load_paths()
        run_dir = results_path.parent
        run_dir.mkdir(parents=True, exist_ok=True)
        (run_dir / "OPUS5_GLM52Q_LIVE_SCOREBOARD.md").write_text(text)
        # copy live usage + runner log into pack
        import shutil
        if usage_path.exists():
            shutil.copy2(usage_path, run_dir / "nexus_usage.jsonl")
        runner = Path("/tmp/v2_opus5_glm52q.runner.log")
        if runner.exists():
            shutil.copy2(runner, run_dir / "runner.log")
        pub = Path("/tmp/opus5_published_trial0_metrics.json")
        if pub.exists():
            shutil.copy2(pub, run_dir / "published_trial0_metrics.json")
        print(f"synced run pack {run_dir}")
    except Exception as e:
        print(f"run pack sync failed: {e}")


if __name__ == "__main__":
    main()
