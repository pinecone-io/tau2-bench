# GPT-5.2 measured re-run (STOPPED)

**Status:** STOPPED  
**Save:** `probe_nexus_full97_gpt52_t1_s300_measured_20260805_193340`  
**Context:** `taubench-v1` (ex `sk-fh-t017-v20-product`)  
**Query model:** `gemini-3.1-pro-preview` (unpinned default)  
**Concurrency:** 2 → 8 (auto-resume)

## Results (partial)

| Metric | Measured | Prior scorecard est. |
|--------|---------:|---------------------:|
| Progress | **20/97** | 97/97 |
| Score (on completed) | **85.0%** (17/20) | 36.08% |
| Agent $ | **$2.20** | $26.82 |
| Nexus queries | **90** | 616 |
| Nexus $ | **$16.16** | ~$25 |
| Mean Nexus $/q | **$0.180** | ~$0.041 |
| Agent + Nexus | **$18.36** | ~$52 |

**Takeaway:** unpinned default Gemini is ~**4–5×** more expensive per query than the old $0.04 estimate.
