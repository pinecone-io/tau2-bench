#!/usr/bin/env bash
# After fullsuites finish: consolidate packs, rename setups → v1/v2, contexts →
# taubench-v1/v2, scrub v1/v2 labels from our docs/scripts, clean /tmp.
set -euo pipefail
REPO="${REPO:-$HOME/repos/tau2-bench}"
cd "$REPO"

echo "=== post_suite_reorganize ==="

if [[ -f /tmp/v2_opus5_glm52q.pid ]]; then
  pid=$(cat /tmp/v2_opus5_glm52q.pid || true)
  if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
    echo "ERROR: suite pid $pid still live — refuse reorganize"
    exit 1
  fi
fi

SIM="$REPO/data/simulations"
SONNET_OLD="leaderboard_nexus_full97_opus5_t1_s300_c8_v2_sonnet5q_20260805_150027"
SONNET_NEW="leaderboard_nexus_full97_opus5_t1_s300_c8_v2_sonnet5q_20260805_150027"
GLM_OLD="leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416"
GLM_NEW="leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416"
ABORT_OLD="leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145"
ABORT_NEW="leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145"

# Pull scatter into current pack first
bash "$REPO/scripts/campaign/finalize_run_pack.sh" || true

rename_dir() {
  local old="$1" new="$2"
  if [[ -d "$SIM/$old" && ! -d "$SIM/$new" ]]; then
    mv "$SIM/$old" "$SIM/$new"
    echo "pack $old -> $new"
  elif [[ -d "$SIM/$old" && -d "$SIM/$new" ]]; then
    cp -an "$SIM/$old/." "$SIM/$new/" || true
    echo "merged $old into $new"
  fi
}
rename_dir "$SONNET_OLD" "$SONNET_NEW"
rename_dir "$GLM_OLD" "$GLM_NEW"
rename_dir "$ABORT_OLD" "$ABORT_NEW"

# Copy final usage/runner into GLM pack
if [[ -d "$SIM/$GLM_NEW" ]]; then
  [[ -f "/tmp/${GLM_OLD}.nexus_usage.jsonl" ]] && cp -f "/tmp/${GLM_OLD}.nexus_usage.jsonl" "$SIM/$GLM_NEW/nexus_usage.jsonl"
  [[ -f /tmp/v2_opus5_glm52q.runner.log ]] && cp -f /tmp/v2_opus5_glm52q.runner.log "$SIM/$GLM_NEW/runner.log"
  [[ -f /tmp/opus5_published_trial0_metrics.json ]] && cp -f /tmp/opus5_published_trial0_metrics.json "$SIM/$GLM_NEW/published_trial0_metrics.json"
fi

# Setups
[[ -d configs/nexus_setups/v1 && ! -d configs/nexus_setups/v1 ]] && mv configs/nexus_setups/v1 configs/nexus_setups/v1 && echo "setup v1->v1"
[[ -d configs/nexus_setups/v2 && ! -d configs/nexus_setups/v2 ]] && mv configs/nexus_setups/v2 configs/nexus_setups/v2 && echo "setup v2->v2"

# Nexus contexts (idle only)
rename_ctx() {
  local old="$1" new="$2" name="$3"
  if nexus --profile clo-nexus --toon context switch "$old" >/dev/null 2>&1; then
    nexus --profile clo-nexus --toon context update --slug "$new" --name "$name" >/dev/null
    echo "context $old -> $new"
  elif nexus --profile clo-nexus --toon context switch "$new" >/dev/null 2>&1; then
    echo "context already $new"
  else
    echo "WARN: context rename $old failed"
  fi
}
rename_ctx "taubench-v1" "taubench-v1" "banking tau2 setup v1"
rename_ctx "taubench-v2" "taubench-v2" "banking tau2 setup v2"

# Script renames
[[ -f scripts/campaign/launch_v2_fullsuite.sh ]] && mv scripts/campaign/launch_v2_fullsuite.sh scripts/campaign/launch_v2_fullsuite.sh
[[ -f scripts/run_full_nexus_v2.sh ]] && mv scripts/run_full_nexus_v2.sh scripts/run_full_nexus_v2.sh
[[ -f scripts/run_leaderboard_banking_nexus_gpt52.sh ]] && mv scripts/run_leaderboard_banking_nexus_gpt52.sh scripts/run_leaderboard_banking_nexus_legacy.sh

# Scrub text in our owned files
python3 "$REPO/scripts/campaign/_scrub_gpt_labels.py"

# Clean scorecards for complete packs
python3 "$REPO/scripts/campaign/_write_final_scoreboards.py"

# Remove live docs name that leaks gpt labels
rm -f docs/runs/OPUS5_GLM52Q_LIVE_SCOREBOARD.md docs/runs/OPUS5_SONNET5Q_FULL97_RESULTS.md 2>/dev/null || true

# /tmp cleanup for this suite family
rm -f \
  /tmp/v2_opus5_glm52q.pid \
  /tmp/v2_opus5_glm52q.save \
  /tmp/v2_opus5_glm52q.usage_log \
  /tmp/v2_opus5_glm52q.runner.log \
  /tmp/gpt55_opus5_full97.pid \
  /tmp/gpt55_opus5_full97.save \
  /tmp/gpt55_opus5_full97.runner.log \
  /tmp/leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145.nexus_usage.jsonl \
  /tmp/leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_20260805_165416.nexus_usage.jsonl \
  2>/dev/null || true

echo "=== contexts ==="
nexus --profile clo-nexus context list 2>&1 | rg 'taubench' || true
echo "=== setups ==="
ls configs/nexus_setups/
echo "=== packs ==="
ls -d data/simulations/leaderboard_nexus_full97_opus5* 2>/dev/null || true
echo "DONE reorganize"
