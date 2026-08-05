#!/usr/bin/env bash
# Full-domain Nexus · gpt-5.5 xhigh · user gpt-5.2 low · leaderboard-shaped.
# Higher concurrency for full runs (default 8 — matches nexus local.toml max_concurrent).
#
# Usage:
#   bash scripts/run_full_nexus_v2.sh              # 97 × 4, seed 300
#   NUM_TRIALS=1 CONCURRENCY=8 bash scripts/run_full_nexus_v2.sh
#   NUM_TASKS=10 bash scripts/run_full_nexus_v2.sh  # optional smoke
set -euo pipefail
cd "$(dirname "$0")/.."

_PRE_NEXUS_URL="${NEXUS_URL-}"
_PRE_NEXUS_CONTEXT="${NEXUS_CONTEXT-}"
_PRE_NEXUS_TIMEOUT="${NEXUS_TIMEOUT-}"
set -a
[[ -f "$HOME/clo/keys/keys.env" ]] && source "$HOME/clo/keys/keys.env"
[[ -f .env ]] && source .env
set +a
[[ -n "${_PRE_NEXUS_URL}" ]] && export NEXUS_URL="${_PRE_NEXUS_URL}"
[[ -n "${_PRE_NEXUS_CONTEXT}" ]] && export NEXUS_CONTEXT="${_PRE_NEXUS_CONTEXT}"
[[ -n "${_PRE_NEXUS_TIMEOUT}" ]] && export NEXUS_TIMEOUT="${_PRE_NEXUS_TIMEOUT}"

: "${OPENAI_API_KEY:?OPENAI_API_KEY required}"
: "${PINECONE_API_KEY:?PINECONE_API_KEY required}"

export NEXUS_URL="${NEXUS_URL:-http://localhost}"
export NEXUS_CONTEXT="${NEXUS_CONTEXT:-taubench-v2}"
unset OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL

if [[ -z "${NEXUS_QUERY_DIRECTIVE:-}" ]]; then
  for f in nq-multiturn-v7-product.txt nq-multiturn-v6.txt nq-multiturn-v5b.txt nq-multiturn-v5.txt nq-multiturn-v3.txt nq-multiturn-v2.txt nq-multiturn-v1.txt; do
    if [[ -f "$HOME/data/benchmark-tau-knowledge/versions/prompts/$f" ]]; then
      export NEXUS_QUERY_DIRECTIVE="$(cat "$HOME/data/benchmark-tau-knowledge/versions/prompts/$f")"
      break
    fi
  done
fi

MODEL="${MODEL:-openai/responses/gpt-5.5}"
# Use single-quoted defaults so bash does not eat nested braces in ${var:-...}
if [[ -z "${AGENT_LLM_ARGS:-}" ]]; then
  AGENT_LLM_ARGS='{"extra_body":{"reasoning_effort":"xhigh"}}'
fi
USER_MODEL="${USER_MODEL:-gpt-5.2}"
if [[ -z "${USER_LLM_ARGS:-}" ]]; then
  USER_LLM_ARGS='{"reasoning_effort":"low"}'
fi
RETRIEVAL="${RETRIEVAL:-nexus_multiturn}"
NUM_TASKS="${NUM_TASKS:-}"
NUM_TRIALS="${NUM_TRIALS:-4}"
SEED="${SEED:-300}"
# Full runs: higher concurrency (nexus config/local.toml max_concurrent = 8)
CONCURRENCY="${CONCURRENCY:-8}"
SAVE_TO="${SAVE_TO:-leaderboard_nexus_full97_gpt55_t4_s${SEED}_c${CONCURRENCY}_$(date +%Y%m%d_%H%M%S)}"

KWARGS=$(python3 -c "import json,os; print(json.dumps({'nexus_context':os.environ['NEXUS_CONTEXT'],'nexus_url':os.environ['NEXUS_URL'],'nexus_timeout':int(os.environ.get('NEXUS_TIMEOUT','600'))}))")

ARGS=(
  run
  --domain banking_knowledge
  --retrieval-config "$RETRIEVAL"
  --retrieval-config-kwargs "$KWARGS"
  --agent llm_agent
  --agent-llm "$MODEL"
  --agent-llm-args "$AGENT_LLM_ARGS"
  --user user_simulator
  --user-llm "$USER_MODEL"
  --user-llm-args "$USER_LLM_ARGS"
  --num-trials "$NUM_TRIALS"
  --seed "$SEED"
  --max-concurrency "$CONCURRENCY"
  --save-to "$SAVE_TO"
  --log-level INFO
)
[[ -n "$NUM_TASKS" ]] && ARGS+=(--num-tasks "$NUM_TASKS")

echo "=== full-domain banking NEXUS · gpt-5.5 ==="
echo "repo=$(pwd) rev=$(git rev-parse --short HEAD)"
echo "agent=$MODEL $AGENT_LLM_ARGS"
echo "user=$USER_MODEL $USER_LLM_ARGS"
echo "retrieval=$RETRIEVAL context=$NEXUS_CONTEXT url=$NEXUS_URL"
echo "query_directive_bytes=${#NEXUS_QUERY_DIRECTIVE}"
echo "trials=$NUM_TRIALS seed=$SEED concurrency=$CONCURRENCY tasks=${NUM_TASKS:-ALL}"
echo "save-to=$SAVE_TO"
exec uv run tau2 "${ARGS[@]}"
