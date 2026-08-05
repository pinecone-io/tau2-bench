#!/usr/bin/env bash
# Run banking_knowledge with a frozen Nexus instruction setup.
#
# Usage:
#   SETUP=v2 AGENT_LLM=claude-opus-5 AGENT_LLM_ARGS='{}' bash scripts/run_nexus_setup.sh
#   SETUP=v1 NUM_TRIALS=1 bash scripts/run_nexus_setup.sh
#
# SETUP is required: v1 | v2
# AGENT_LLM defaults to the setup's historical agent if unset.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SETUP="${SETUP:?SET SETUP=v1 or SETUP=v2}"
PACK="$ROOT/configs/nexus_setups/$SETUP"
[[ -d "$PACK" ]] || { echo "unknown setup: $SETUP (expected under configs/nexus_setups/)"; exit 1; }

set -a
[[ -f "$HOME/clo/keys/keys.env" ]] && source "$HOME/clo/keys/keys.env"
[[ -f "$ROOT/.env" ]] && source "$ROOT/.env"
# shellcheck disable=SC1091
source "$PACK/setup.env"
set +a

# True OpenAI for agent/user (avoid Nebius OPENAI_BASE_URL override)
unset OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL

export NEXUS_QUERY_DIRECTIVE="$(cat "$PACK/query_directive.txt")"
export TAU2_NEXUS_POLICY_FILE="$PACK/policy.md"

if [[ "${SETUP_USE_HARD_RULES:-0}" == "1" ]]; then
  export TAU2_AGENT_HARD_RULES_FILE="$PACK/hard_rules.txt"
else
  unset TAU2_AGENT_HARD_RULES_FILE TAU2_AGENT_HARD_RULES || true
fi

AGENT_LLM="${AGENT_LLM:-$SETUP_HISTORICAL_AGENT_LLM}"
AGENT_LLM_ARGS="${AGENT_LLM_ARGS:-$SETUP_HISTORICAL_AGENT_LLM_ARGS}"
USER_LLM="${USER_LLM:-$SETUP_HISTORICAL_USER_LLM}"
USER_LLM_ARGS="${USER_LLM_ARGS:-$SETUP_HISTORICAL_USER_LLM_ARGS}"
NUM_TRIALS="${NUM_TRIALS:-$SETUP_DEFAULT_NUM_TRIALS}"
SEED="${SEED:-$SETUP_DEFAULT_SEED}"
CONCURRENCY="${CONCURRENCY:-$SETUP_DEFAULT_CONCURRENCY}"
NUM_TASKS="${NUM_TASKS:-}"
SAVE_TO="${SAVE_TO:-nexus_${SETUP}_${AGENT_LLM//\//_}_t${NUM_TRIALS}_s${SEED}_$(date +%Y%m%d_%H%M%S)}"

KWARGS=$(python3 -c "import json,os; print(json.dumps({
  'nexus_context': os.environ['NEXUS_CONTEXT'],
  'nexus_url': os.environ['NEXUS_URL'],
  'nexus_timeout': int(os.environ.get('NEXUS_TIMEOUT','600')),
}))")

ARGS=(
  run
  --domain banking_knowledge
  --retrieval-config nexus_multiturn
  --retrieval-config-kwargs "$KWARGS"
  --agent llm_agent
  --agent-llm "$AGENT_LLM"
  --agent-llm-args "$AGENT_LLM_ARGS"
  --user user_simulator
  --user-llm "$USER_LLM"
  --user-llm-args "$USER_LLM_ARGS"
  --num-trials "$NUM_TRIALS"
  --seed "$SEED"
  --max-concurrency "$CONCURRENCY"
  --save-to "$SAVE_TO"
  --log-level "${LOG_LEVEL:-INFO}"
)
[[ -n "$NUM_TASKS" ]] && ARGS+=(--num-tasks "$NUM_TASKS")

echo "=== nexus setup run ==="
echo "setup=$SETUP pack=$PACK"
echo "policy=$TAU2_NEXUS_POLICY_FILE"
echo "hard_rules=${TAU2_AGENT_HARD_RULES_FILE:-OFF}"
echo "context=$NEXUS_CONTEXT url=$NEXUS_URL query_model=${NEXUS_QUERY_MODEL:-unpinned}"
echo "directive_bytes=${#NEXUS_QUERY_DIRECTIVE}"
echo "agent=$AGENT_LLM $AGENT_LLM_ARGS"
echo "user=$USER_LLM $USER_LLM_ARGS"
echo "trials=$NUM_TRIALS seed=$SEED concurrency=$CONCURRENCY tasks=${NUM_TASKS:-ALL}"
echo "save-to=$SAVE_TO"
echo "repo=$(pwd) rev=$(git rev-parse --short HEAD 2>/dev/null || echo n/a)"
exec uv run tau2 "${ARGS[@]}"
