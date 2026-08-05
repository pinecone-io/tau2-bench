# Banking Nexus — run log (tau2-bench)

**Repo:** [`pinecone-io/tau2-bench`](https://github.com/pinecone-io/tau2-bench) · branch **`nexus`**  
**Base:** Sierra `main` (`1eceb04`) + single squash commit with Nexus harness  
**Host:** clo-nexus · domain `banking_knowledge` · retrieval `nexus_multiturn`

## Reporting standard

All live and published scoreboards use **[`REPORTING_TEMPLATE.md`](./REPORTING_TEMPLATE.md)**  
(totals vs board + per-task table: score · agent_$ · tools · msgs · nexus_q · nexus_$ · pub_*).

Live example: [`OPUS5_GLM52Q_LIVE_SCOREBOARD.md`](./OPUS5_GLM52Q_LIVE_SCOREBOARD.md).

## Setups

| Setup | Context | Directive | Hard rules | Pack |
|-------|---------|-----------|------------|------|
| **v1** | `taubench-v1` | v1 | off | `configs/nexus_setups/v1/` |
| **v2** | `taubench-v2` | v7 | rules 1–12 | `configs/nexus_setups/v2/` |

```bash
cd ~/repos/tau2-bench
SETUP=v2 AGENT_LLM=<model> bash scripts/run_nexus_setup.sh
SETUP=v1 AGENT_LLM=<model> NUM_TRIALS=1 bash scripts/run_nexus_setup.sh
```

Default query model: **`claude-sonnet-5`**.

---

## Scoreboard (new stack)

| # | Run | Setup | Agent | Scope | pass | Cost | Note |
|---|-----|-------|-------|-------|------|------|------|
| **1** | **Opus 5 first** | v2 | `claude-opus-5` | 10 tasks ×1 | **9/10** | ~$6.84 | first run on `nexus` |

---

## Running list (newest first)

### 2026-08-05 · #1 · Claude Opus 5 · v2 · **complete** (first test on new stack)

| Field | Value |
|-------|--------|
| **Save** | `probe_gpt55_opus5_10tasks_s300_20260805_143818` |
| **Repo / branch** | `tau2-bench` · `nexus` |
| **Git (run)** | `f8ea598` (pre-squash tip; content = squash `7239d13`) |
| **Setup** | **v2** |
| **Context** | `taubench-v2` |
| **Retrieval** | `nexus_multiturn` |
| **Policy** | pack `policy.md` (`TAU2_NEXUS_POLICY_FILE`) |
| **Hard rules** | pack `hard_rules.txt` rules **1–12** |
| **Directive** | pack v7 (`NEXUS_QUERY_DIRECTIVE`) |
| **Query model** | `claude-sonnet-5` |
| **Agent** | `claude-opus-5` · `llm_args={}` |
| **User** | `gpt-5.2` · `reasoning_effort=low` |
| **Tasks** | first **10** (`--num-tasks 10`) · trials **1** · seed **300** · c=**4** |
| **Score** | **9/10 = 90%** |
| **Fail** | `task_012` only |
| **Pass** | 001, 002, 003, 004, 005, 006, 007, 008, 010 |
| **Cost** | agent ~$6.73 · user ~$0.11 · **total ~$6.84** |
| **Path** | `data/simulations/probe_gpt55_opus5_10tasks_s300_20260805_143818/results.json` |

### 2026-08-05 · Opus 5 · v2 · GLM-5.2 query · full97×1 · **LIVE** (restarted)

| Field | Value |
|-------|--------|
| **Save** | `leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416` |
| **Status** | running (restarted after `task_id` stamped on Nexus usage log) |
| **Setup** | **v2** · `taubench-v2` |
| **Agent** | `claude-opus-5` · `{}` |
| **User** | `gpt-5.2` low |
| **Query** | **`zai-org/GLM-5.2`** |
| **Nexus usage log** | `/tmp/…165416.nexus_usage.jsonl` — per query: `task_id`, latency, tokens, `cost_usd` |
| **Scope** | full 97 · trials 1 · seed 300 · c=8 |
| **Log** | `/tmp/v2_opus5_glm52q.runner.log` |
| **Prior partial** | `…164145` aborted mid-run (~15/97) |


