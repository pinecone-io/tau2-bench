# Nexus tooling — tau2-bench

Branch **`nexus`**: Sierra `main` + Pinecone CLO Nexus banking harness.

Primary docs: **[`configs/nexus_setups/README.md`](../../configs/nexus_setups/README.md)**

## Two setups

| Setup | Nexus context | Policy | Directive | Hard rules |
|-------|---------------|--------|-----------|------------|
| [`v1`](../../configs/nexus_setups/v1/MANIFEST.md) | **`taubench-v1`** | short multiturn | v1 | off |
| [`v2`](../../configs/nexus_setups/v2/MANIFEST.md) | **`taubench-v2`** | full multiturn (no A1) | v7 | rules 1–12 |

## Run

```bash
cd ~/repos/tau2-bench
SETUP=v2 AGENT_LLM=<model> bash scripts/run_nexus_setup.sh
SETUP=v1 AGENT_LLM=<model> NUM_TRIALS=1 bash scripts/run_nexus_setup.sh
```

Default query model: **`claude-sonnet-5`**.

## Env reference

| Env | Purpose |
|-----|---------|
| `NEXUS_CONTEXT` | Context slug: `taubench-v1` or `taubench-v2` |
| `NEXUS_URL` | Gateway (default `http://localhost`) |
| `NEXUS_QUERY_MODEL` | Nexus catalog id for KB answers |
| `NEXUS_QUERY_DIRECTIVE` | Text appended to each `KB_query` |
| `TAU2_NEXUS_POLICY_FILE` | Override path for multiturn policy template |
| `TAU2_AGENT_HARD_RULES_FILE` | Optional high-priority agent rules (v2) |
| `PINECONE_API_KEY` / `NEXUS_TOKEN` | Nexus auth |

## Code map

- `src/tau2/domains/banking_knowledge/nexus_client.py` — Nexus query client
- `src/tau2/domains/banking_knowledge/retrieval.py` — variants + `TAU2_NEXUS_POLICY_FILE`
- `src/tau2/domains/banking_knowledge/retrieval_mixins.py` / `retrieval_toolkits.py` — `KB_query` tool
- `src/tau2/agent/llm_agent.py` — hard-rules block in system prompt
- `scripts/run_nexus_setup.sh` — pack activator + `tau2 run`
- `scripts/campaign/retest_one_task.sh` — single-task with pack
- `scripts/campaign/launch_v2_fullsuite.sh` — background fullsuite wrapper

## Contexts

Renamed in place on **clo-nexus** (indexes preserved):

- `sk-fh-t017-v20-product` → **`v1`** → **`taubench-v1`**
- `sk-fh-t028-v24-residual` → **`v2`** → **`taubench-v2`**
