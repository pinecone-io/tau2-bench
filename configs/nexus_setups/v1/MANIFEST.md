# Setup: `v1`

Frozen **instruction + Nexus context** pack for banking_knowledge multiturn.

## Identity

| Field | Value |
|-------|--------|
| Setup id | `v1` |
| Pack path | `configs/nexus_setups/v1/` |
| Nexus context slug | **`taubench-v1`** (live on `clo-nexus`) |
| Context id | `660c5c49-f73f-4baa-aaf5-2f9435fe1ce8` |
| Context display name | banking tau2 v1 pack (was t017 product) |
| Former slugs | `sk-fh-t017-v20-product` → `v1` → **`taubench-v1`** (same indexes) |
| Profile | `clo-nexus` |
| NEXUS_URL | `http://localhost` (CLO gateway) |

## Files in this pack

| File | Env / use |
|------|-----------|
| `policy.md` | `TAU2_NEXUS_POLICY_FILE` — agent additional policy for `nexus_multiturn` |
| `query_directive.txt` | `NEXUS_QUERY_DIRECTIVE` — appended to every Nexus `KB_query` |
| `hard_rules.txt` | **not used** (comment only; hard-rules feature off for this pack) |
| `setup.env` | Defaults for context, models, trials, seed, concurrency |

## Retrieval / domain

| Knob | Value |
|------|--------|
| Domain | `banking_knowledge` |
| Retrieval config | `nexus_multiturn` |
| Agent | `llm_agent` |
| User | `user_simulator` |

## Instruction stack

| Layer | Source | Notes |
|-------|--------|--------|
| Agent policy | `policy.md` | Frozen from tau-bench-nexus `@e50f541` `nexus_multiturn.md` (~83 lines). Process checklist, bank date 2025-11-14, product select, signup/promo, transfer, ownership, special code, referral path-forward. |
| Query directive | `query_directive.txt` | Historical **nq-multiturn-v1**. Product filter-rank, promo clock, EcoCard points wording, transfer reason codes, referral Platinum path-forward, bare enums. |
| Hard rules | off | Do **not** set `TAU2_AGENT_HARD_RULES_FILE` for this pack. |

## Context stack

| Layer | Value |
|-------|--------|
| Slug | `taubench-v1` |
| Kind | search |
| Craft era | t017 “product-select” (product_profile, product_select_rule, internal_tool, tool_step, transfer_protocol, …) |
| last_optimized_at | 2026-07-31 |
| last_curated_at | 2026-07-31 |
| has_sources | true |

Do **not** re-curate or re-optimize casually — this index is the frozen v1 KB.

## Historical agent defaults (for replay)

| Role | Model | Args |
|------|--------|------|
| Agent | `gpt-5.2` | `{"reasoning_effort":"high"}` |
| User | `gpt-5.2` | `{"reasoning_effort":"low"}` |
| Trials / seed / concurrency | 1 / 300 / 8 (pack default trials=1) |

For new-model tests: override `AGENT_LLM` / `AGENT_LLM_ARGS` only; leave policy, directive, context, hard-rules-off fixed.

## Query model

Default pin: **`claude-sonnet-5`** (`NEXUS_QUERY_MODEL`). Override with any concrete Nexus catalog id. Empty = server default.

## How to run

```bash
cd ~/repos/tau2-bench
SETUP=v1 AGENT_LLM=<model> [AGENT_LLM_ARGS='{}'] \
  [NUM_TRIALS=1] [SEED=300] [NUM_TASKS=] \
  bash scripts/run_nexus_setup.sh
```

What the launcher sets:

- `NEXUS_CONTEXT=taubench-v1`
- `NEXUS_QUERY_DIRECTIVE` ← `query_directive.txt`
- `TAU2_NEXUS_POLICY_FILE` ← `policy.md`
- unsets hard-rules env
- `NEXUS_QUERY_MODEL=claude-sonnet-5` unless overridden
