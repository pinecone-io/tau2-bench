#!/usr/bin/env bash
# Repro public GLM-5.2 banking_knowledge alltools (Z.ai / Fireworks submission shape):
#   agent = user = GLM-5.2, retrieval = alltools, 4 trials.
# Hosted here on Nebius Token Factory (not Fireworks).
#
# OpenAI billing is inactive on this machine — dense arm uses Nebius
# Qwen/Qwen3-Embedding-8B via OpenAI-compatible API (OPENAI_BASE_URL → Nebius).
# True public alltools uses text-embedding-3-large on OpenAI.
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
[[ -f .env ]] && source .env
# clo keys if present
[[ -f "$HOME/clo/keys/keys.env" ]] && source "$HOME/clo/keys/keys.env"
set +a

: "${NEBIUS_API_KEY:?NEBIUS_API_KEY required}"
: "${NEBIUS_BASE_URL:?NEBIUS_BASE_URL required}"
export NEBIUS_API_BASE="${NEBIUS_API_BASE:-$NEBIUS_BASE_URL}"

# Dense embeddings via Nebius OpenAI-compat (unless caller forces real OpenAI)
if [[ "${USE_REAL_OPENAI_EMBEDDINGS:-0}" != "1" ]]; then
  export OPENAI_API_KEY="${NEBIUS_API_KEY}"
  export OPENAI_BASE_URL="${NEBIUS_BASE_URL}"
  export TAU2_DENSE_EMBED_MODEL="${TAU2_DENSE_EMBED_MODEL:-Qwen/Qwen3-Embedding-8B}"
fi

MODEL="${MODEL:-nebius/zai-org/GLM-5.2}"
USER_MODEL="${USER_MODEL:-$MODEL}"
# Public used dual GLM (not gpt-5.2). Empty args = tau2 default temperature=0.
USER_LLM_ARGS="${USER_LLM_ARGS:-{}}"
RETRIEVAL="${RETRIEVAL:-alltools}"
NUM_TASKS="${NUM_TASKS:-}"
NUM_TRIALS="${NUM_TRIALS:-4}"
CONCURRENCY="${CONCURRENCY:-2}"
SAVE_TO="${SAVE_TO:-baseline_banking_${RETRIEVAL}_glm52_$(date +%Y%m%d_%H%M%S)}"

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

echo "=== alltools GLM-5.2 repro (pinecone-io/tau2-bench) ==="
echo "repo=$(pwd) rev=$(git rev-parse --short HEAD)"
echo "agent=$MODEL user=$USER_MODEL retrieval=$RETRIEVAL trials=$NUM_TRIALS concurrency=$CONCURRENCY"
echo "dense_model=${TAU2_DENSE_EMBED_MODEL:-text-embedding-3-large} openai_base=${OPENAI_BASE_URL:-default}"
echo "save-to=$SAVE_TO tasks=${NUM_TASKS:-ALL}"
exec uv run tau2 "${ARGS[@]}"
