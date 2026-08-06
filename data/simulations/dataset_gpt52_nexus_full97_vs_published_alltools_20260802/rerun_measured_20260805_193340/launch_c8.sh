#!/usr/bin/env bash
set -euo pipefail
cd /home/harnesser/repos/tau2-bench
RERUN=data/simulations/dataset_gpt52_nexus_full97_vs_published_alltools_20260802/rerun_measured_20260805_193340
SAVE=probe_nexus_full97_gpt52_t1_s300_measured_20260805_193340
ULOG="$(pwd)/$RERUN/nexus_usage.jsonl"

set -a; source /home/harnesser/clo/keys/keys.env; set +a
export NEXUS_URL=http://localhost
export NEXUS_CONTEXT=taubench-v1
export NEXUS_TIMEOUT=600
export NEXUS_USAGE_LOG="$ULOG"
export NEXUS_QUERY_DIRECTIVE="$(cat "$HOME/data/benchmark-tau-knowledge/versions/prompts/nq-multiturn-v1.txt")"
unset NEXUS_QUERY_MODEL OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL

KWARGS=$(python3 -c 'import json,os; print(json.dumps({"nexus_context":os.environ["NEXUS_CONTEXT"],"nexus_url":os.environ["NEXUS_URL"],"nexus_timeout":int(os.environ.get("NEXUS_TIMEOUT","600"))}))')

uv run tau2 run \
  --domain banking_knowledge \
  --retrieval-config nexus_multiturn \
  --retrieval-config-kwargs "$KWARGS" \
  --agent llm_agent \
  --agent-llm gpt-5.2 \
  --agent-llm-args '{"reasoning_effort":"high"}' \
  --user user_simulator \
  --user-llm gpt-5.2 \
  --user-llm-args '{"reasoning_effort":"low"}' \
  --num-trials 1 \
  --seed 300 \
  --max-concurrency 8 \
  --save-to "$SAVE" \
  --auto-resume \
  --log-level INFO \
  >> "$RERUN/runner.log" 2>&1

ec=$?
echo "EXIT:$ec $(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$RERUN/runner.log"
[[ -f "data/simulations/$SAVE/results.json" ]] && cp -a "data/simulations/$SAVE/results.json" "$RERUN/results.json"

python3 - <<PY
import json
from pathlib import Path
from datetime import datetime, timezone
rerun=Path("$RERUN"); save="$SAVE"; ulog=Path("$ULOG")
res=Path("data/simulations")/save/"results.json"
out={"finished_utc":datetime.now(timezone.utc).isoformat(),"save_to":save,"exit":$ec,"concurrency":8}
if res.exists():
    d=json.loads(res.read_text()); sims=[s for s in d.get("simulations") or [] if s]
    pn=sum(1 for s in sims if float((s.get("reward_info") or {}).get("reward") or 0)>=1)
    ac=sum(float(s.get("agent_cost") or 0) for s in sims)
    out.update(n=len(sims),pass_n=pn,pass_pct=round(100*pn/max(len(sims),1),2),agent_usd=round(ac,4))
nq=ncost=0
if ulog.exists():
    for line in ulog.read_text().splitlines():
        if not line.strip(): continue
        r=json.loads(line); nq+=1
        if r.get("cost_usd") is not None: ncost+=float(r["cost_usd"])
out["nexus_queries"]=nq; out["nexus_usd"]=round(ncost,4)
out["agent_plus_nexus"]=round((out.get("agent_usd") or 0)+ncost,4)
(rerun/"MEASURED_SUMMARY.json").write_text(json.dumps(out,indent=2)+"\n")
(rerun/"SCOREBOARD_MEASURED.md").write_text(f"""# GPT-5.2 measured re-run

**Status:** DONE  
**Save:** \`{save}\`  
**Context:** \`taubench-v1\`  
**Concurrency:** 8

| Metric | Measured | Prior est. |
|--------|---------:|-----------:|
| Score | **{out.get('pass_pct','—')}%** ({out.get('pass_n','—')}/{out.get('n','—')}) | 36.08% |
| Agent \$ | **\${out.get('agent_usd',0):.2f}** | \$26.82 |
| Nexus queries | **{nq}** | 616 |
| Nexus \$ | **\${ncost:.2f}** | ~\$25 |
| Agent + Nexus | **\${out['agent_plus_nexus']:.2f}** | ~\$52 |
""")
print(json.dumps(out, indent=2))
PY
