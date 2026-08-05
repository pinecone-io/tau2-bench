# Leaderboard-shaped banking alltools — GPT-5.2 (2026-08-01)

## Goal

Reproduce a Sierra-style **τ³-Banking** leaderboard entry on
`pinecone-io/tau2-bench` (@ `363133a`, grading **v1.0.1**):

| Knob | Value |
|------|--------|
| Domain | `banking_knowledge` |
| Retrieval | **`alltools`** (BM25 + OpenAI `text-embedding-3-large` + sandboxed shell) |
| Agent | `gpt-5.2` · `reasoning_effort: high` |
| User sim | `gpt-5.2` · `reasoning_effort: low` |
| Trials | **4** |
| Seed | **300** |
| Concurrency | 2 |

Public reference (Sierra submission, alltools, GPT-5.2): **Pass^1 ≈ 32.2%**.

## Artifacts

| Path | Role |
|------|------|
| `data/simulations/leaderboard_banking_alltools_gpt52_20260801_153648/results.json` | trajectories + rewards |
| `logs/leaderboard_banking_alltools_gpt52_20260801_153648.log` | full run log |
| `scripts/run_leaderboard_banking_alltools_gpt52.sh` | runner used |

Smoke before full run: `smoke_leaderboard_alltools_gpt52_1task` (task_001 reward 1.0).

## Outcome

### Run interrupted by infra (trial 4)

At ~**2026-08-02 05:45 UTC**, `/tmp` **inode exhaustion** (tmpfs, ~1M inodes,
~1491 leftover `agentic_search_*` sandbox dirs from alltools shell). Trial **4**
failed with `ENOSPC` for **56 tasks** (permanent after retries). Process was
**stopped**; `/tmp` cleaned (inodes back to healthy).

**Do not treat post-ENOSPC “complete” counts as leaderboard-valid.**

### Valid metrics (pre-ENOSPC / non-infra sims only)

From `results.json` (reward-bearing simulations only):

| Metric | Value | Notes |
|--------|-------|--------|
| Real sims with reward | **301** | 56 infra / null-reward |
| Tasks with any reward | **97** | all base tasks touched |
| Tasks with **3** trials | **87** | full k=1..3 |
| Tasks with **4** trials | **10** | k=4 incomplete |
| **Pass^1** | **34.0%** (97 tasks) | first-trial success rate |
| **Pass^2** | **25.8%** (97) | all of first 2 trials pass |
| **Pass^3** | **18.6%** (97) | all of first 3 trials pass |
| **Pass^4** | n/a | only 10 tasks have 4 real trials |
| Mean reward (all real trials) | **0.326** | matches ~32.6% trial success |
| Avg agent cost / real sim | **~$0.83** | total agent ~**$249** |

### vs public leaderboard

| | This run | Public GPT-5.2 alltools |
|--|----------|-------------------------|
| Pass^1 | **34.0%** | **32.2%** |
| Host / scaffold | OpenAI API + tau2 v1.0.1 | Sierra submission |
| k=4 complete? | **No** (ENOSPC) | Yes |

**Verdict:** through **k=3**, this is a **successful leaderboard-style repro**
(Pass^1 within ~2pp of the published GPT-5.2 alltools number). Finish trial 4
only after `/tmp` hygiene (or point sandbox temp dir off the small inode tmpfs)
if a full Pass^4 is required.

## Lessons for next runs

1. **`/tmp` inodes** — alltools/terminal shell sandboxes leave dirs; clean
   periodically or set a large-inode temp root. Monitor `df -ih /tmp`.
2. Prefer **concurrency 2** for cost/rate; do not raise until temp is stable.
3. Checkpoint/`--auto-resume` is useful after infra stalls — re-run **only**
   missing trial-4 cells rather than full 388.

## Follow-on: Nexus retrieval arm

Same leaderboard recipe (gpt-5.2 high / gpt-5.2-low user, 4 trials, seed 300)
with `--retrieval-config nexus` against a curated banking context, instead of
alltools. Runner + smoke live under `tau-bench-nexus` (has Nexus peer arm).
See `docs/runs/nexus-banking-leaderboard.md` (or repo `BASELINE_RUN.md` there).
