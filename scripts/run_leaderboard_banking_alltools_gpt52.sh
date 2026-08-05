#!/usr/bin/env bash
# Leaderboard-shaped banking entry (Sierra convention):
#   alltools + OpenAI text-embedding-3-large + gpt-5.2 agent + gpt-5.2-low user
#   4 trials, seed 300
set -euo pipefail
cd "$(dirname "$0")/.."

set -a
[[ -f "$HOME/clo/keys/keys.env" ]] && source "$HOME/clo/keys/keys.env"
[[ -f .env ]] && source .env
set +a

# Force true OpenAI dense (do not point OpenAI client at Nebius)
unset OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL
: "${OPENAI_API_KEY:?OPENAI_API_KEY required}"

MODEL="${MODEL:-gpt-5.2}"
AGENT_LLM_ARGS="${AGENT_LLM_ARGS:-{\"reasoning_effort\":\"high\"}}"
USER_MODEL="${USER_MODEL:-gpt-5.2}"
USER_LLM_ARGS="${USER_LLM_ARGS:-{\"reasoning_effort\":\"low\"}}"
RETRIEVAL="${RETRIEVAL:-alltools}"
NUM_TASKS="${NUM_TASKS:-}"
NUM_TRIALS="${NUM_TRIALS:-4}"
SEED="${SEED:-300}"
CONCURRENCY="${CONCURRENCY:-2}"
SAVE_TO="${SAVE_TO:-leaderboard_banking_alltools_gpt52_$(date +%Y%m%d_%H%M%S)}"

ARGS=(
  run
  --domain banking_knowledge
  --retrieval-config "$RETRIEVAL"
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

echo "=== leaderboard-shaped banking alltools ==="
echo "repo=$(pwd) rev=$(git rev-parse --short HEAD)"
echo "agent=$MODEL $AGENT_LLM_ARGS"
echo "user=$USER_MODEL $USER_LLM_ARGS"
echo "retrieval=$RETRIEVAL trials=$NUM_TRIALS seed=$SEED concurrency=$CONCURRENCY"
echo "OPENAI_BASE_URL=${OPENAI_BASE_URL:-<unset>} TAU2_DENSE_EMBED_MODEL=${TAU2_DENSE_EMBED_MODEL:-<unset>}"
echo "save-to=$SAVE_TO tasks=${NUM_TASKS:-ALL}"
exec uv run tau2 "${ARGS[@]}"
