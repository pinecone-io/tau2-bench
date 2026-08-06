#!/usr/bin/env bash
set -euo pipefail
cd /home/harnesser/repos/tau2-bench
RERUN_DIR="data/simulations/dataset_gpt52_nexus_full97_vs_published_alltools_20260802/rerun_measured_20260805_193340"
SAVE_TO="probe_nexus_full97_gpt52_t1_s300_measured_20260805_193340"
USAGE_LOG="/home/harnesser/repos/tau2-bench/data/simulations/dataset_gpt52_nexus_full97_vs_published_alltools_20260802/rerun_measured_20260805_193340/nexus_usage.jsonl"

set -a
source /home/harnesser/clo/keys/keys.env
set +a

export NEXUS_URL=http://localhost
export NEXUS_CONTEXT=taubench-v1
export NEXUS_TIMEOUT=600
export NEXUS_USAGE_LOG="$USAGE_LOG"
export NEXUS_QUERY_DIRECTIVE="$(cat "$HOME/data/benchmark-tau-knowledge/versions/prompts/nq-multiturn-v1.txt")"
unset NEXUS_QUERY_MODEL OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL
# critical: leave unset so legacy script defaults expand correctly
unset AGENT_LLM_ARGS USER_LLM_ARGS

export MODEL=gpt-5.2
export USER_MODEL=gpt-5.2
export RETRIEVAL=nexus_multiturn
export NUM_TRIALS=1
export SEED=300
export CONCURRENCY=2
export SAVE_TO

: > "$NEXUS_USAGE_LOG"

{
  echo "=== start $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
  echo "context=$NEXUS_CONTEXT save=$SAVE_TO usage=$NEXUS_USAGE_LOG"
} | tee -a "$RERUN_DIR/runner.log"

bash scripts/run_leaderboard_banking_nexus_legacy.sh >> "$RERUN_DIR/runner.log" 2>&1
ec=$?
echo "EXIT:$ec $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "$RERUN_DIR/runner.log"

if [[ -f "data/simulations/${SAVE_TO}/results.json" ]]; then
  cp -a "data/simulations/${SAVE_TO}/results.json" "$RERUN_DIR/results.json"
fi

python3 - "$RERUN_DIR" "$SAVE_TO" "$USAGE_LOG" "$ec" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone
rerun, save, ulog, ec = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]), int(sys.argv[4])
out = {"finished_utc": datetime.now(timezone.utc).isoformat(), "save_to": save, "exit": ec}
res = Path("data/simulations") / save / "results.json"
if res.exists():
    d = json.loads(res.read_text())
    sims = [s for s in (d.get("simulations") or []) if s]
    pn = sum(1 for s in sims if float((s.get("reward_info") or {}).get("reward") or 0) >= 1)
    ac = sum(float(s.get("agent_cost") or 0) for s in sims)
    out.update(n=len(sims), pass_n=pn, pass_pct=round(100*pn/max(len(sims),1),2), agent_usd=round(ac,4))
nq=ncost=0
if ulog.exists():
    for line in ulog.read_text().splitlines():
        if not line.strip(): continue
        r=json.loads(line)
        nq+=1
        if r.get("cost_usd") is not None: ncost+=float(r["cost_usd"])
out["nexus_queries"]=nq
out["nexus_usd"]=round(ncost,4)
out["agent_plus_nexus"]=round((out.get("agent_usd") or 0)+ncost,4)
(rerun/"MEASURED_SUMMARY.json").write_text(json.dumps(out, indent=2)+"\n")
md = f"""# GPT-5.2 measured re-run

**Status:** {"DONE" if ec==0 else "FAILED"}  
**Save:** `{save}`  
**Context:** `taubench-v1` (ex `sk-fh-t017-v20-product`)

## Results

| Metric | Measured | Prior scorecard est. |
|--------|---------:|---------------------:|
| Score | **{out.get('pass_pct','—')}%** ({out.get('pass_n','—')}/{out.get('n','—')}) | 36.08% |
| Agent $ | **${out.get('agent_usd',0):.2f}** | $26.82 |
| Nexus queries | **{nq}** | 616 |
| Nexus $ | **${ncost:.2f}** | ~$25 |
| Agent + Nexus | **${out['agent_plus_nexus']:.2f}** | ~$52 |
"""
(rerun/"SCOREBOARD_MEASURED.md").write_text(md)
print(json.dumps(out, indent=2))
PY
