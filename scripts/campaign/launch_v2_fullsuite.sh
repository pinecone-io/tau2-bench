#!/usr/bin/env bash
# Full97×4 with v2 frozen pack (wrapper around run_nexus_setup.sh)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export SETUP=v2
export AGENT_LLM="${AGENT_LLM:-openai/responses/gpt-5.5}"
export AGENT_LLM_ARGS="${AGENT_LLM_ARGS:-{\"extra_body\":{\"reasoning_effort\":\"xhigh\"}}}"
export NUM_TRIALS="${NUM_TRIALS:-4}"
export SEED="${SEED:-300}"
export CONCURRENCY="${CONCURRENCY:-8}"
export SAVE_TO="${SAVE_PREFIX:-leaderboard_nexus_full97_gpt55}_$(date +%Y%m%d_%H%M%S)"
echo "$SAVE_TO" > /tmp/champion_fullsuite.save
nohup bash "$ROOT/scripts/run_nexus_setup.sh" > /tmp/champion_fullsuite.runner.log 2>&1 &
echo $! > /tmp/champion_fullsuite.pid
echo "launched fullsuite pid=$(cat /tmp/champion_fullsuite.pid) save=$SAVE_TO setup=v2"
