#!/usr/bin/env bash
# Leaderboard-shaped banking entry with Nexus retrieval (peer of alltools):
#   agent gpt-5.2 high · user gpt-5.2 low · 4 trials · seed 300 · retrieval nexus
set -euo pipefail
cd "$(dirname "$0")/.."
# Preserve caller overrides — sourcing .env must not clobber them.
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

: "${OPENAI_API_KEY:?OPENAI_API_KEY required for user/agent gpt-5.2}"
: "${PINECONE_API_KEY:?PINECONE_API_KEY required for Nexus auth}"

export NEXUS_URL="${NEXUS_URL:-http://localhost}"
export NEXUS_CONTEXT="${NEXUS_CONTEXT:-taubench-v1}"
# true OpenAI for agent/user (not Nebius override of OPENAI_BASE_URL)
unset OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL

# Multi-turn answer-shape contract for every KB_query (optional override)
if [[ -z "${NEXUS_QUERY_DIRECTIVE:-}" && -f "$HOME/data/benchmark-tau-knowledge/versions/prompts/nq-multiturn-v1.txt" ]]; then
  export NEXUS_QUERY_DIRECTIVE="$(cat "$HOME/data/benchmark-tau-knowledge/versions/prompts/nq-multiturn-v1.txt")"
fi

MODEL="${MODEL:-gpt-5.2}"
AGENT_LLM_ARGS="${AGENT_LLM_ARGS:-{\"reasoning_effort\":\"high\"}}"
USER_MODEL="${USER_MODEL:-gpt-5.2}"
USER_LLM_ARGS="${USER_LLM_ARGS:-{\"reasoning_effort\":\"low\"}}"
# Agent policy with process checklist + multi-turn transfer/enum rules
RETRIEVAL="${RETRIEVAL:-nexus_multiturn}"
NUM_TASKS="${NUM_TASKS:-}"
NUM_TRIALS="${NUM_TRIALS:-4}"
SEED="${SEED:-300}"
# Default 2 for small probes; full runs: CONCURRENCY=8 (or scripts/run_full_nexus_v2.sh)
CONCURRENCY="${CONCURRENCY:-2}"
SAVE_TO="${SAVE_TO:-leaderboard_banking_nexus_gpt52_$(date +%Y%m%d_%H%M%S)}"

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

echo "=== leaderboard-shaped banking NEXUS ==="
echo "repo=$(pwd) rev=$(git rev-parse --short HEAD)"
echo "agent=$MODEL $AGENT_LLM_ARGS"
echo "user=$USER_MODEL $USER_LLM_ARGS"
echo "retrieval=$RETRIEVAL context=$NEXUS_CONTEXT url=$NEXUS_URL"
echo "query_directive_bytes=${#NEXUS_QUERY_DIRECTIVE}"
echo "trials=$NUM_TRIALS seed=$SEED concurrency=$CONCURRENCY tasks=${NUM_TASKS:-ALL}"
echo "save-to=$SAVE_TO"
exec uv run tau2 "${ARGS[@]}"
