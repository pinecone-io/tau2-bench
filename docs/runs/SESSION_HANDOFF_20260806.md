# Session handoff — 2026-08-06

Branch: **`nexus`** @ `pinecone-io/tau2-bench` (squashed history → single feature commit + this doc).

## Scorecards (committed)

Trial-1 traj scores only (not board pasŝ¹; no regrade of published traj rewards). Per-task tables end with a **total** row.

| Scorecard | Nexus | Published alltools (traj t1) |
|-----------|------:|-----------------------------:|
| [SCORECARD_OPUS5_NEXUS_VS_ALLTOOLS.md](./SCORECARD_OPUS5_NEXUS_VS_ALLTOOLS.md) | **47.42%** (46/97) · agent $261 · nexus $136 (461 q, GLM) | **50.52%** (49/97) · agent $1,311 |
| [SCORECARD_GPT52_NEXUS_VS_ALLTOOLS.md](./SCORECARD_GPT52_NEXUS_VS_ALLTOOLS.md) | **36.08%** (35/97) · agent $27 · nexus ~$25 est (616 q) | **24.74%** (24/97) · agent $141 |
| [SCORECARD_GPT55_NEXUS_VS_ALLTOOLS.md](./SCORECARD_GPT55_NEXUS_VS_ALLTOOLS.md) | **45.36%** (44/97) trial-1 · agent $48 · nexus ~$15 est (372 q) | **37.11%** (36/97) · agent $206 |

**GPT-5.5 multi-trial pasŝ¹ (our run):** **46.13%** (4 trials) — use this when comparing to Sierra pass_1. Scorecard shows trial-1 **45.36%**.

### Links
- https://github.com/pinecone-io/tau2-bench/blob/nexus/docs/runs/SCORECARD_OPUS5_NEXUS_VS_ALLTOOLS.md
- https://github.com/pinecone-io/tau2-bench/blob/nexus/docs/runs/SCORECARD_GPT52_NEXUS_VS_ALLTOOLS.md
- https://github.com/pinecone-io/tau2-bench/blob/nexus/docs/runs/SCORECARD_GPT55_NEXUS_VS_ALLTOOLS.md

### Packs
| Pack | Role |
|------|------|
| `data/simulations/leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416/` | Opus5 + GLM full97 complete (v2 setup + `taubench-v2`) |
| `data/simulations/dataset_gpt52_nexus_full97_vs_published_alltools_20260802/` | GPT-5.2 Nexus original + scorecard |
| `data/simulations/dataset_gpt55_nexus_v29plus10_champion_vs_published_alltools_20260804/` | GPT-5.5 Nexus 4-trial full pack |

---

## Pass¹ vs trial-1 (important)

| Metric | Definition |
|--------|------------|
| **Trial-1 rate** | `#tasks with trial index 0 reward≥1` / 97 |
| **pasŝ¹ / board `pass_1`** | mean over tasks of `successes/trials` (4-trial mean success rate) |

Single-trial runs: trial-1 = pasŝ¹.

**Published GPT-5.2 / 5.5:** submission.json pass_1 is **~7–9 pp higher** than pasŝ¹ computed from public S3 traj rewards. Evidence: v1.0.1 banking **re-grade** (CHANGELOG + GPT-5.2 methodology notes #329/#397/#402). Public traj files still carry older rewards; Opus5 trajs match board pasŝ¹. See investigation notes in session; re-score with `tau2 evaluate-trajs --fresh-tasks` to reconcile.

---

## Context rename

`sk-fh-t017-v20-product` → **`taubench-v1`** (same id `660c5c49-f73f-4baa-aaf5-2f9435fe1ce8`).  
v2 setup uses **`taubench-v2`**.

Always pair **setup pack** (`configs/nexus_setups/v1` or `v2`) with its context — do not mix v2 policy + v1 context.

---

## Experiments this session (partial / stopped — not full leaderboard)

| Save | Stack | Progress | Score (on completed) | Nexus $ | Notes |
|------|--------|----------|---------------------:|--------:|-------|
| `probe_nexus_full97_gpt52_t1_s300_measured_20260805_193340` | gpt-5.2 high · unpinned query · `taubench-v1` · c=2→8 | **20/97** | **85%** (17/20) | **$16.16** (90 q, Gemini) | Measured usage log; ~$0.18/q vs ~$0.04 est |
| `…/rerun_measured_20260805_193340/` | same (report home under dataset pack) | | | | `SCOREBOARD_MEASURED.md` |
| `leaderboard_nexus_full97_opus5_t1_s300_c8_v1_glm52q_20260805_200928` | Opus5 + GLM · **v1 setup+context** · c=8 | **19/97** | **52.6%** (10/19) | **$16.06** (72 q) | Stopped — not looking good |
| `…200828` | Opus5 + GLM · **wrong:** v2 instructions + v1 context | aborted | — | — | Do not use |
| `leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028` | gpt-5.2 + GLM · **v2** · c=8 | **8/97** | early 100% | **$5.67** (13 q) | Stopped for investigation |

Failed launch dirs under `dataset_gpt52…/rerun_measured_20260805_1930{12,203,236}` are arg-parse failures (legacy script `AGENT_LLM_ARGS` brace bug if pre-set); keep only as noise or delete later.

---

## Cost calibration takeaways

| Source | $/query (approx) |
|--------|-----------------:|
| GPT-5.2 scorecard estimate | ~$0.041 |
| Measured unpinned Gemini | ~$0.18 |
| Opus5 full97 GLM-5.2 | ~$0.30 |
| Partial Opus5+GLM v1 | ~$0.22 |

---

## Key code / tooling

| Path | Role |
|------|------|
| `configs/nexus_setups/v1/`, `v2/` | Frozen policy, directive, hard rules, context defaults |
| `scripts/run_nexus_setup.sh` | `SETUP=v1\|v2` launcher |
| `src/tau2/domains/banking_knowledge/nexus_client.py` | `NEXUS_USAGE_LOG` per-query cost + task_id |
| `docs/runs/REPORTING_TEMPLATE.md` | Scorecard template |
| `docs/runs/CAMPAIGN_RUN_LOG.md` | Campaign history |

**Bug:** `scripts/run_leaderboard_banking_nexus_legacy.sh` appends an extra `}` if `AGENT_LLM_ARGS` is pre-exported — leave unset to use script default, or call `tau2` directly with quoted JSON.

---

## Next session ideas

1. Finish or drop partial measured packs; optionally update GPT-5.2 scorecard Nexus $ from measured Gemini rate or re-run with pinned query model.  
2. Re-grade public GPT-5.2/5.5 trajs under current tau2 and refresh published columns.  
3. If retrying Opus on v1: use **SETUP=v1** only (already learned).  
4. gpt-5.2 + GLM + v2 was early-stopped — resume with `--auto-resume` if desired.

---

## Git

Squashed feature branch to one commit on `nexus`; this handoff is an additional commit.  
`origin/nexus` should be up to date after push.
