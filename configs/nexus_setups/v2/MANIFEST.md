# Setup: `v2`

Frozen **instruction + Nexus context** pack for banking_knowledge multiturn.

## Identity

| Field | Value |
|-------|--------|
| Setup id | `v2` |
| Pack path | `configs/nexus_setups/v2/` |
| Nexus context slug | **`taubench-v2`** (live on `clo-nexus`) |
| Context id | `a96b06f0-3cdc-4120-9d1f-7d90c418b8df` |
| Context display name | banking tau2 v2 pack (was t028 residual) |
| Former slugs | `sk-fh-t028-v24-residual` → `v2` → **`taubench-v2`** (same indexes) |
| Profile | `clo-nexus` |
| NEXUS_URL | `http://localhost` (CLO gateway) |

## Files in this pack

| File | Env / use |
|------|-----------|
| `policy.md` | `TAU2_NEXUS_POLICY_FILE` — agent additional policy for `nexus_multiturn` |
| `query_directive.txt` | `NEXUS_QUERY_DIRECTIVE` — appended to every Nexus `KB_query` |
| `hard_rules.txt` | `TAU2_AGENT_HARD_RULES_FILE` — rules **1–12** only |
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
| Agent policy | `policy.md` | Frozen from tau-bench-nexus `@fe18138` `nexus_multiturn.md` (~249 lines). Full multiturn craft: process protocol, enums, retention, dual-open, interest formula, referral checklist, cashback stop, freeze path. **No A1 multi-call block.** |
| Query directive | `query_directive.txt` | Historical **nq-multiturn-v7**. Bank date, COPY_LITERALS for enums/standard tools/transfer/cashback/referral/apply/open/interest/ATM. |
| Hard rules | `hard_rules.txt` | Rules **1–12** only (user standard tools, multi-dispute PC, multi-card close, cashback set S, apply 4 fields, referral done, referral maximize, interest formula, ATM free allowance, business savings enums, dual open, freeze). **No rule 13 A1, no rule 14 ATM arithmetic add-on.** |

## Context stack

| Layer | Value |
|-------|--------|
| Slug | `taubench-v2` |
| Kind | search |
| Description | v24 residual: standard apply/referral tools, retention apply-first, dual-open, interest formula, referral verify |
| Craft era | t028 residual (richer enums: `account_class_enum`, `enum_card_type`, `referral_account_type`, discoverable user tools, transfer do_not_use_when) |
| last_optimized_at | 2026-08-03 |
| last_curated_at | 2026-08-03 |
| has_sources | true |

Do **not** re-curate or re-optimize casually — this index is the frozen v2 KB.

## Historical agent defaults (for replay)

| Role | Model | Args |
|------|--------|------|
| Agent | `openai/responses/gpt-5.5` | `{"extra_body":{"reasoning_effort":"xhigh"}}` |
| User | `gpt-5.2` | `{"reasoning_effort":"low"}` |
| Trials / seed / concurrency | 4 / 300 / 8 |

For new-model tests: override `AGENT_LLM` / `AGENT_LLM_ARGS` only; leave policy, directive, hard rules, context fixed.

## Query model

Default pin: **`claude-sonnet-5`** (`NEXUS_QUERY_MODEL`).  
Note: the original champion run sometimes used the **server default** (unpinned). For exact historical query-model replay, unset `NEXUS_QUERY_MODEL`. For all new tests, keep Sonnet 5.

## How to run

```bash
cd ~/repos/tau2-bench
SETUP=v2 AGENT_LLM=<model> [AGENT_LLM_ARGS='{}'] \
  [NUM_TRIALS=4] [SEED=300] [NUM_TASKS=] \
  bash scripts/run_nexus_setup.sh
```

What the launcher sets:

- `NEXUS_CONTEXT=taubench-v2`
- `NEXUS_QUERY_DIRECTIVE` ← `query_directive.txt`
- `TAU2_NEXUS_POLICY_FILE` ← `policy.md`
- `TAU2_AGENT_HARD_RULES_FILE` ← `hard_rules.txt`
- `NEXUS_QUERY_MODEL=claude-sonnet-5` unless overridden
