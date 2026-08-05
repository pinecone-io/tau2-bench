# Sources & provenance

## Ours (Nexus gpt-5.2)

| Field | Value |
|-------|--------|
| Source repo | `pinecone-io/tau-bench-nexus` (local: `~/repos/tau-bench-nexus`) |
| Save | `probe_nexus_full97_t1_s300_20260802_190635` |
| Results | `data/simulations/.../results.json` (copied into this pack) |
| Log | `logs/probe_nexus_full97_t1_s300_20260802_190635.log` |
| Git rev (run) | `e50f541aa6f30a20b3c60c9b756c340789146244` |
| Context | `sk-fh-t017-v20-product` |
| Retrieval | `nexus_multiturn` @ `http://localhost` |
| Campaign note | `tau-bench-nexus/docs/runs/CAMPAIGN_RUN_LOG.md` · 2026-08-02 |

## Published (Sierra GPT-5.2 alltools)

| Field | Value |
|-------|--------|
| Submission | `gpt-5-2_sierra_2026-02-26` |
| Board pass¹ banking | 32.22% |
| S3 traj | `s3://sierra-tau-bench-public/submissions/gpt-5-2_sierra_2026-02-26/trajectories/gpt-5.2_high_banking_knowledge_gpt-5.2_4trials.json` |
| HTTPS | https://sierra-tau-bench-public.s3.amazonaws.com/submissions/gpt-5-2_sierra_2026-02-26/trajectories/gpt-5.2_high_banking_knowledge_gpt-5.2_4trials.json |
| Size | ~216 MB (4 trials × 97) |
| Local cache (optional) | `/tmp/gpt-5.2_high_banking_knowledge_gpt-5.2_4trials.json` |

### Re-fetch published trajs

```bash
curl -L -o /tmp/gpt-5.2_high_banking_knowledge_gpt-5.2_4trials.json \
  "https://sierra-tau-bench-public.s3.amazonaws.com/submissions/gpt-5-2_sierra_2026-02-26/trajectories/gpt-5.2_high_banking_knowledge_gpt-5.2_4trials.json"
```

Trial-0 metrics used for the scoreboard are already in `published_trial0_metrics.json` / `message_level_metrics.json` (no need for the full 216 MB blob for most analysis).

## This pack (tau2-bench)

| Field | Value |
|-------|--------|
| Path | `data/simulations/dataset_gpt52_nexus_full97_vs_published_alltools_20260802/` |
| Docs mirror | `docs/runs/GPT52_NEXUS_VS_PUBLISHED_*.md` |
| Template | `docs/runs/REPORTING_TEMPLATE.md` |
