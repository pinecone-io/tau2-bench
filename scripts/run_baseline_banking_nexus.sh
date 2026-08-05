#!/usr/bin/env bash
# Baseline: banking_knowledge + Nexus KB_query retrieval
set -euo pipefail
cd "$(dirname "$0")/.."
set -a
[[ -f .env ]] && source .env
set +a

MODEL="${MODEL:-anthropic/claude-sonnet-4-5-20250929}"
NUM_TASKS="${NUM_TASKS:-}"
NUM_TRIALS="${NUM_TRIALS:-1}"
CONCURRENCY="${CONCURRENCY:-2}"  # lower: each KB_query can take minutes
SAVE_TO="${SAVE_TO:-baseline_banking_nexus_${MODEL//\//_}_$(date +%Y%m%d_%H%M%S)}"
NEXUS_CTX="${NEXUS_CONTEXT:-taubench-v1}"
NEXUS_API="${NEXUS_URL:-http://localhost}"

: "${NEXUS_CTX:?Set NEXUS_CONTEXT}"
if [[ -z "${PINECONE_API_KEY:-}${NEXUS_TOKEN:-}" ]]; then
  echo "error: set PINECONE_API_KEY or NEXUS_TOKEN" >&2
  exit 1
fi

KWARGS=$(python3 -c "import json; print(json.dumps({'nexus_context':'''$NEXUS_CTX''','nexus_url':'''$NEXUS_API'''}))")

ARGS=(
  run
  --domain banking_knowledge
  --retrieval-config nexus
  --retrieval-config-kwargs "$KWARGS"
  --agent llm_agent
  --agent-llm "$MODEL"
  --user user_simulator
  --user-llm "$MODEL"
  --num-trials "$NUM_TRIALS"
  --max-concurrency "$CONCURRENCY"
  --save-to "$SAVE_TO"
  --log-level INFO
)
[[ -n "$NUM_TASKS" ]] && ARGS+=(--num-tasks "$NUM_TASKS")

echo "=== tau2 nexus baseline ==="
echo "model=$MODEL context=$NEXUS_CTX url=$NEXUS_API tasks=${NUM_TASKS:-ALL}"
echo "save-to=$SAVE_TO"
exec uv run tau2 "${ARGS[@]}"
