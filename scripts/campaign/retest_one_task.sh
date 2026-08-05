#!/usr/bin/env bash
# Retest one task id with a frozen setup (default v2).
# Usage: TASK=task_027 [SETUP=v2] [SEED=900] bash scripts/campaign/retest_one_task.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
: "${TASK:?set TASK=task_NNN}"
export SETUP="${SETUP:-v2}"
export NUM_TRIALS="${NUM_TRIALS:-1}"
export SEED="${SEED:-900}"
export CONCURRENCY="${CONCURRENCY:-1}"
# tau2 accepts --task-ids; run_nexus_setup uses NUM_TASKS for count only —
# call tau2 after activating env via a thin path:
PACK="$ROOT/configs/nexus_setups/$SETUP"
set -a
[[ -f "$HOME/clo/keys/keys.env" ]] && source "$HOME/clo/keys/keys.env"
[[ -f "$ROOT/.env" ]] && source "$ROOT/.env"
# shellcheck disable=SC1091
source "$PACK/setup.env"
set +a
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
SAVE_TO="${SAVE_TO:-retest_${SETUP}_${TASK}_s${SEED}_$(date +%Y%m%d_%H%M%S)}"
KWARGS=$(python3 -c "import json,os; print(json.dumps({'nexus_context':os.environ['NEXUS_CONTEXT'],'nexus_url':os.environ['NEXUS_URL'],'nexus_timeout':int(os.environ.get('NEXUS_TIMEOUT','600'))}))")
cd "$ROOT"
echo "=== retest $TASK setup=$SETUP agent=$AGENT_LLM ==="
exec uv run tau2 run \
  --domain banking_knowledge \
  --retrieval-config nexus_multiturn \
  --retrieval-config-kwargs "$KWARGS" \
  --agent llm_agent \
  --agent-llm "$AGENT_LLM" \
  --agent-llm-args "$AGENT_LLM_ARGS" \
  --user user_simulator \
  --user-llm "$USER_LLM" \
  --user-llm-args "$USER_LLM_ARGS" \
  --task-ids "$TASK" \
  --num-trials "$NUM_TRIALS" \
  --seed "$SEED" \
  --max-concurrency "$CONCURRENCY" \
  --save-to "$SAVE_TO" \
  --log-level INFO
