# Dataset: GPT-5.5 Nexus vs alltools

**Scorecard:** [`SCORECARD_GPT55_NEXUS_VS_ALLTOOLS.md`](../../docs/runs/SCORECARD_GPT55_NEXUS_VS_ALLTOOLS.md)

**ID:** `dataset_gpt55_nexus_v29plus10_run_vs_published_alltools_20260804`  
**Status:** DONE · 2026-08-05 18:37:48 UTC  
**Primary metric:** **pass¹ only**

## Headlines

| Metric | Ours (Nexus run) | Published GPT-5.5 alltools |
|--------|--------------------------:|---------------------------:|
| **Pass¹** | **46.13%** | board **46.39%** (regraded v1.0.1) |
| Trial-0 pass | 44/97 | 36/97 (traj) |
| Agent $ (all 4 trials) | **$189.79** | **$771.35** |
| Agent $ (trial 0) | **$48.34** | **$206.44** |
| **Nexus $ (approx)** | **~$57** (1394 q × $0.0406) | n/a |
| User-sim $ (all) | $6.51 | — |
| H2H net (t0) | **+8** (17 win / 9 lose) | |

Came **within 0.3 pp** of the regraded alltools board on pass¹.

## Knobs

| | Ours | Published |
|--|------|-----------|
| Agent | gpt-5.5 xhigh | gpt-5.5 xhigh |
| User | gpt-5.2 low | gpt-5.2 low |
| Retrieval | nexus multiturn | alltools |
| Context | sk-fh-t028-v24-residual | — |
| Stack | v29plus10 · rules 1–12 · nq-v7 | Sierra scaffold |
| Trials / seed / c | 4 / 300 / 8 | 4 / 300 / — |

## Files

| File | Description |
|------|-------------|
| `SCOREBOARD.md` | Pass¹ totals + per-task t0 H2H |
| `SUMMARY.json` | Machine-readable |
| `per_task.csv` | Spreadsheet |
| `message_level_metrics.json` | t0 message dig |
| `published_trial0_metrics.json` | Pub t0 compact |
| `published_submission.json` | Sierra submission metadata |
| `tool_mix.json` | Our tools |
| `results.json` | Full our trajs (388 sims) |
| `runner.log` | Run log (if present) |
| `SOURCES.md` | Provenance |

## Notes

- Primary metric is **pass¹** only (Sierra pass_hat_1).
- Board **46.39%** is the regraded v1.0.1 number used in campaign; raw published trajs under-score vs board.
- Nexus query $ not logged for this pack.

Nexus $ backfill: 1394 KB_query × $0.0406/q (from GPT-5.2 $25/616) ≈ **$56.57**.

