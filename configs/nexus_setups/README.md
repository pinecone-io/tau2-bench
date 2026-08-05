# Nexus instruction setups (`v1` · `v2`)

Harness packs for `banking_knowledge` + Nexus retrieval on **tau2-bench** (`nexus` branch).  
Each pack freezes: **Nexus context slug**, **agent policy**, **query directive**, and (for v2) **hard rules**.

Simulation dumps live elsewhere — this tree documents **how to run the packs**, not scores.

## Packs

| Setup | Nexus context | Policy | Directive | Hard rules | Default agent (historical) |
|-------|---------------|--------|-----------|------------|----------------------------|
| **`v1`** | `taubench-v1` (was `sk-fh-t017-v20-product` → `v1`) | short multiturn `@e50f541` | v1 | off | `gpt-5.2` high |
| **`v2`** | `taubench-v2` (was `sk-fh-t028-v24-residual` → `v2`) | full multiturn `@fe18138` (no A1) | v7 | rules 1–12 | `gpt-5.5` xhigh |

Full knobs: [`v1/MANIFEST.md`](./v1/MANIFEST.md) · [`v2/MANIFEST.md`](./v2/MANIFEST.md)

## Layout of each pack

```
configs/nexus_setups/<setup>/
  MANIFEST.md           # full details (this is the source of truth)
  policy.md             # agent additional policy (nexus_multiturn template)
  query_directive.txt   # NEXUS_QUERY_DIRECTIVE body
  hard_rules.txt        # TAU2_AGENT_HARD_RULES_FILE (v2 only; v1 is a stub)
  setup.env             # NEXUS_CONTEXT + defaults
```

## Prerequisites

- Host: **clo-nexus** (or tunnel to same Nexus)
- Auth: `~/clo/keys/keys.env` → `PINECONE_API_KEY` (and OpenAI keys for agent/user)
- CLI profile: `nexus --profile clo-nexus`
- Contexts **`taubench-v1`** and **`taubench-v2`** exist and are queryable (renamed in place from t017/t028)
- Repo: `~/repos/tau2-bench` on branch `nexus`

```bash
nexus --profile clo-nexus context list   # should show taubench-v1, taubench-v2 ready
```

## Run

```bash
cd ~/repos/tau2-bench

# v2 pack with a new agent model
SETUP=v2 AGENT_LLM=claude-opus-5 AGENT_LLM_ARGS='{}' \
  bash scripts/run_nexus_setup.sh

# v1 pack
SETUP=v1 AGENT_LLM=claude-opus-5 AGENT_LLM_ARGS='{}' \
  NUM_TRIALS=1 bash scripts/run_nexus_setup.sh

# single task retest
TASK=task_027 SETUP=v2 bash scripts/campaign/retest_one_task.sh
```

Launcher: [`scripts/run_nexus_setup.sh`](../../scripts/run_nexus_setup.sh)

### Env the launcher owns

| Env | Set from |
|-----|----------|
| `NEXUS_CONTEXT` | `setup.env` → **`taubench-v1`** or **`taubench-v2`** |
| `NEXUS_URL` | default `http://localhost` |
| `NEXUS_QUERY_MODEL` | default **`claude-sonnet-5`** |
| `NEXUS_QUERY_DIRECTIVE` | pack `query_directive.txt` |
| `TAU2_NEXUS_POLICY_FILE` | pack `policy.md` |
| `TAU2_AGENT_HARD_RULES_FILE` | pack `hard_rules.txt` if `SETUP_USE_HARD_RULES=1` |

Optional overrides: `AGENT_LLM`, `AGENT_LLM_ARGS`, `USER_LLM`, `USER_LLM_ARGS`, `NUM_TRIALS`, `SEED`, `CONCURRENCY`, `NUM_TASKS`, `SAVE_TO`, `NEXUS_QUERY_MODEL`.

## Harness code (shared)

| Piece | Path |
|-------|------|
| Nexus HTTP client | `src/tau2/domains/banking_knowledge/nexus_client.py` |
| Retrieval variants | `src/tau2/domains/banking_knowledge/retrieval.py` (`nexus_multiturn`, …) |
| Hard-rules inject | `src/tau2/agent/llm_agent.py` (`TAU2_AGENT_HARD_RULES` / `_FILE`) |
| Policy file override | `TAU2_NEXUS_POLICY_FILE` in `build_policy()` |
| Setup launcher | `scripts/run_nexus_setup.sh` |

## Context rename note

Live slugs on clo-nexus were renamed in place (same Pinecone indexes, same context ids):

| New slug | Former slug | Context id |
|----------|-------------|------------|
| `taubench-v1` | `sk-fh-t017-v20-product` → `v1` | `660c5c49-f73f-4baa-aaf5-2f9435fe1ce8` |
| `taubench-v2` | `sk-fh-t028-v24-residual` → `v2` | `a96b06f0-3cdc-4120-9d1f-7d90c418b8df` |

Old slug names no longer resolve. Always use **`taubench-v1`** / **`taubench-v2`**.
