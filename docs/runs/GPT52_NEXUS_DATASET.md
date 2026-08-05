# Dataset: GPT-5.2 Nexus vs alltools

**Scorecard:** [`SCORECARD_GPT52_NEXUS_VS_ALLTOOLS.md`](SCORECARD_GPT52_NEXUS_VS_ALLTOOLS.md)

**ID:** `dataset_gpt52_nexus_full97_vs_published_alltools_20260802`  
**Status:** DONE · 2026-08-05 18:37:48 UTC  
**Primary metric:** **pass¹ only**

## Headlines

| Metric | Ours (Nexus gpt-5.2) | Published GPT-5.2 alltools |
|--------|---------------------:|---------------------------:|
| **Pass¹** | **36.08%** | board **32.22%** |
| Agent $ | **$26.82** | **$140.52** (t0) · **$493.59** (all 4) |
| Nexus queries | **616** | n/a |
| **Nexus $ (approx)** | **~$25** | n/a |
| **Agent + Nexus** | **~$51.82** | — |
| User-sim $ | $1.98 | $2.69 (t0) |

Ours: 1 trial · seed 300 · nexus multiturn · `sk-fh-t017-v20-product`.  
Published: Sierra alltools · 4 trials · seed 300.

Nexus $ is an **aggregate ~$25 estimate** (no per-query breakdown; pack predates `NEXUS_USAGE_LOG`).

## Files

See pack directory. Scoreboard: `SCOREBOARD.md` · CSV: `per_task.csv` · trajs: `results.json`.

Nexus $ backfill: 616 KB_query × $0.0406/q ≈ **$25.00** (era unpinned default; no usage log).

