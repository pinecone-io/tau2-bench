# Standard results reporting template (Nexus banking)

**Canonical format** for publishing and live-tracking tau2-bench Nexus runs.  
Live updater: `scripts/campaign/update_opus5_glm52q_scoreboard.py` (pattern to reuse).  
Example: `docs/runs/OPUS5_GLM52Q_LIVE_SCOREBOARD.md`.

---

## 1. Header

```markdown
# Live scoreboard — <agent> · <query model> · <setup>

**Last update:** <UTC timestamp>  
**Status:** `RUNNING` | `DONE` | `STOPPED`  
**Save:** `<save_name>`  
**Usage log:** `<path to nexus_usage.jsonl>`  
**Run pack:** `data/simulations/<save_name>/`
```

---

## 2. Totals vs leaderboard (always on top)

| Metric | Ours (this run) | Published baseline |
|--------|----------------:|-------------------:|
| Progress | **N/97** | 97/97 (trial 0) |
| Pass / rate | **P/N (xx.x%)** | **board pass¹ yy.y%** (and/or traj t0 A/97) |
| Possible final band | min–max/97 (while incomplete) | — |
| Δ vs board pass¹ (on completed) | **±z.z pp** | baseline |
| Agent cost (model) | **$…** | **$…** (if known) |
| Nexus query cost | **$…** (Q queries) | n/a (unless baseline is also Nexus) |

**Notes under the table (one short paragraph):**
- Ours knobs: agent · query model · setup · context · trials · seed · c=
- Published knobs: model · retrieval (e.g. alltools) · trial

---

## 3. Per-task table (required columns)

| task | our_score | our_agent_$ | our_tools | our_msgs | nexus_q | nexus_$ | pub_score | pub_agent_$ | pub_tools | pub_msgs |
|------|----------:|------------:|----------:|---------:|--------:|--------:|----------:|------------:|----------:|---------:|
| task_001 | 1 | $0.22 | 3 | 9 | 2 | $0.31 | 1 | $2.10 | 17 | 30 |
| … | | | | | | | | | | |

### Column definitions

| Column | Source | Meaning |
|--------|--------|---------|
| `our_score` | `reward_info.reward` | `1` pass · `0` fail · `—` not finished |
| `our_agent_$` | `agent_cost` | Agent model $ for that task (not user-sim) |
| `our_tools` | count `messages[].tool_calls` | All tool calls (incl. writes) |
| `our_msgs` | `len(messages)` | Full trajectory length |
| `nexus_q` | count `KB_query` / usage log by `task_id` | Nexus queries this task |
| `nexus_$` | `NEXUS_USAGE_LOG` sum `cost_usd` by `task_id` | Server-side query $ |
| `pub_score` | published traj trial 0 | Same scoring as ours |
| `pub_agent_$` | published `agent_cost` | From trajs (not necessarily `submission.json`) |
| `pub_tools` | published tool_call count | All tools |
| `pub_msgs` | published message count | Full traj length |

**Do not invent published Nexus columns** unless the baseline is also Nexus.

Optional later columns (not in v1 standard): `our_user_$`, message-level token sums, wall_s, non-write tool counts.

---

## 4. Notes footer

- Score legend and cost definitions  
- What published baseline is (and is not)  
- Refresh cadence / run-pack path  

---

## 5. Run pack (single folder for analysis)

Every suite should end up under:

```text
data/simulations/<save_name>/
  results.json
  nexus_usage.jsonl          # task_id, cost_usd, tokens, wall_ms, model
  runner.log
  OPUS5_…_LIVE_SCOREBOARD.md # or RESULTS_SCOREBOARD.md
  RUN_META.json
  published_*_metrics.json   # if comparing to a frozen baseline
  MANIFEST.md
```

While running: scoreboard updates in place every 5 minutes.  
After finish: `scripts/campaign/finalize_run_pack.sh` (or equivalent) copies any `/tmp` scatter into this pack.

---

## 6. Status line (chat / ops pulse)

Keep this one-liner format for 5-minute wakes:

```text
STATS <UTC> | <STATUS> | progress N/97 | pass P/N (xx.x%) | vs board yy.y% Δ±z.zpp (on completed)
STATS cost agent $A user $U | nexus queries Q (task_id tagged T) cost $N | q_wall mean Xs med Ys
STATS band if rest pass/fail: lo-hi/97 (…)
STATS pack data/simulations/<save>/ | scoreboard docs/runs/<SCOREBOARD>.md
```

---

## 7. New runs checklist

1. Launch with `NEXUS_USAGE_LOG` set and query model pinned (concrete catalog id).  
2. Ensure `task_id` is stamped on usage rows (env stamps tools from task).  
3. Point scoreboard updater at save + usage + published cache.  
4. Write live MD to **both** `docs/runs/` and the run pack.  
5. On exit: finalize pack; freeze scoreboard as final RESULTS.  

This template is the default for publishing Nexus banking benchmark results going forward.
