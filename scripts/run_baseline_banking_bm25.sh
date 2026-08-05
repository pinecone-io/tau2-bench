#!/usr/bin/env bash
# Baseline: banking_knowledge + bm25 on pinecone-io/tau2-bench
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
[[ -f .env ]] && source .env
if [[ -n "${NEBIUS_BASE_URL:-}" ]]; then
  export NEBIUS_API_BASE="${NEBIUS_API_BASE:-$NEBIUS_BASE_URL}"
fi
set +a

MODEL="${MODEL:-anthropic/claude-sonnet-4-5-20250929}"
# Leaderboard convention (Sierra submissions): user sim = gpt-5.2, reasoning_effort=low
USER_MODEL="${USER_MODEL:-gpt-5.2}"
USER_LLM_ARGS="${USER_LLM_ARGS:-{\"reasoning_effort\":\"low\"}}"
RETRIEVAL="${RETRIEVAL:-bm25}"
NUM_TASKS="${NUM_TASKS:-}"
NUM_TRIALS="${NUM_TRIALS:-1}"
CONCURRENCY="${CONCURRENCY:-4}"
SAVE_TO="${SAVE_TO:-baseline_banking_${RETRIEVAL}_${MODEL//\//_}_$(date +%Y%m%d_%H%M%S)}"

ARGS=(
  run
  --domain banking_knowledge
  --retrieval-config "$RETRIEVAL"
  --agent llm_agent
  --agent-llm "$MODEL"
  --user user_simulator
  --user-llm "$USER_MODEL"
  --user-llm-args "$USER_LLM_ARGS"
  --num-trials "$NUM_TRIALS"
  --max-concurrency "$CONCURRENCY"
  --save-to "$SAVE_TO"
  --log-level INFO
)
[[ -n "$NUM_TASKS" ]] && ARGS+=(--num-tasks "$NUM_TASKS")

echo "=== tau2-bench baseline (pinecone-io/tau2-bench) ==="
echo "repo=$(pwd) rev=$(git rev-parse --short HEAD) origin=$(git remote get-url origin 2>/dev/null || echo n/a)"
echo "agent=$MODEL user=$USER_MODEL user_args=$USER_LLM_ARGS"
echo "retrieval=$RETRIEVAL trials=$NUM_TRIALS tasks=${NUM_TASKS:-ALL} concurrency=$CONCURRENCY"
echo "save-to=$SAVE_TO"
exec uv run tau2 "${ARGS[@]}"
