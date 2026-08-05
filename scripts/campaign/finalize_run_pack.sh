#!/usr/bin/env bash
# Copy all scattered live-run artifacts into the simulation pack folder.
# Safe to re-run. Does not kill any processes.
set -euo pipefail
REPO="${REPO:-$HOME/repos/tau2-bench}"
SAVE_FILE=/tmp/v2_opus5_glm52q.save
USAGE_PTR=/tmp/v2_opus5_glm52q.usage_log
[[ -f "$SAVE_FILE" ]] || { echo "no save file"; exit 1; }
SAVE=$(cat "$SAVE_FILE")
RUN_DIR="$REPO/data/simulations/$SAVE"
mkdir -p "$RUN_DIR"

# usage log (live path)
if [[ -f "$USAGE_PTR" ]]; then
  ULOG=$(cat "$USAGE_PTR")
  [[ -f "$ULOG" ]] && cp -f "$ULOG" "$RUN_DIR/nexus_usage.jsonl"
fi
# also any matching /tmp usage for this save
[[ -f "/tmp/${SAVE}.nexus_usage.jsonl" ]] && cp -f "/tmp/${SAVE}.nexus_usage.jsonl" "$RUN_DIR/nexus_usage.jsonl"

cp -f /tmp/v2_opus5_glm52q.runner.log "$RUN_DIR/runner.log" 2>/dev/null || true
cp -f "$REPO/docs/runs/OPUS5_GLM52Q_LIVE_SCOREBOARD.md" "$RUN_DIR/OPUS5_GLM52Q_LIVE_SCOREBOARD.md" 2>/dev/null || true
cp -f /tmp/opus5_published_trial0_metrics.json "$RUN_DIR/published_trial0_metrics.json" 2>/dev/null || true

# pointer files for forensics
cp -f /tmp/v2_opus5_glm52q.save "$RUN_DIR/save.name" 2>/dev/null || true
cp -f /tmp/v2_opus5_glm52q.pid "$RUN_DIR/suite.pid" 2>/dev/null || true
cp -f /tmp/v2_opus5_glm52q.usage_log "$RUN_DIR/usage_log.path" 2>/dev/null || true

# aborted prior partial (if exists) - keep as sibling archive note only if different save
if [[ -f /tmp/leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145.nexus_usage.jsonl ]]; then
  cp -f /tmp/leaderboard_nexus_full97_opus5_t1_s300_c8_v2_glm52q_aborted_20260805_164145.nexus_usage.jsonl \
    "$RUN_DIR/archive_prior_partial_164145.nexus_usage.jsonl" 2>/dev/null || true
fi

# prior sonnet fullsuite pointer (optional)
if [[ -f /tmp/gpt55_opus5_full97.save ]]; then
  echo "$(cat /tmp/gpt55_opus5_full97.save)" > "$RUN_DIR/related_sonnet_query_fullsuite.save" 2>/dev/null || true
fi

python3 - "$RUN_DIR" <<'PY'
import json, time
from pathlib import Path
run = Path(__import__('sys').argv[1])
meta_path = run / "RUN_META.json"
meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
meta["finalized_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
meta["pack_files"] = sorted(p.name for p in run.iterdir())
meta_path.write_text(json.dumps(meta, indent=2))
print("finalized", run)
for p in sorted(run.iterdir()):
    print(f"  {p.name:50} {p.stat().st_size:10d}")
PY
