#!/usr/bin/env bash
set -euo pipefail
cd /home/harnesser/repos/tau2-bench
set -a; source /home/harnesser/clo/keys/keys.env; set +a

export SETUP=v2
export NEXUS_URL=http://localhost
export NEXUS_CONTEXT=taubench-v2
export NEXUS_TIMEOUT=600
export NEXUS_QUERY_MODEL=zai-org/GLM-5.2
export NEXUS_USAGE_LOG="/home/harnesser/repos/tau2-bench/data/simulations/leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028/nexus_usage.jsonl"
export NEXUS_PROFILE=clo-nexus
export AGENT_LLM=gpt-5.2
export AGENT_LLM_ARGS='{"reasoning_effort":"high"}'
export NUM_TRIALS=1
export SEED=300
export CONCURRENCY=8
export SAVE_TO="leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028"
unset OPENAI_BASE_URL TAU2_DENSE_EMBED_MODEL

echo "=== start $(date -u +%Y-%m-%dT%H:%M:%SZ) SETUP=v2 context=taubench-v2 gpt-5.2+glm52q c=8 ===" | tee -a "data/simulations/leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028/runner.log"
bash scripts/run_nexus_setup.sh >> "data/simulations/leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028/runner.log" 2>&1
ec=$?
echo "EXIT:$ec $(date -u +%Y-%m-%dT%H:%M:%SZ)" | tee -a "data/simulations/leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028/runner.log"

python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone
pack=Path("data/simulations/leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028"); save="leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028"; ulog=Path("/home/harnesser/repos/tau2-bench/data/simulations/leaderboard_nexus_full97_gpt52_t1_s300_c8_v2_glm52q_20260805_202028/nexus_usage.jsonl")
res=Path("data/simulations")/save/"results.json"
out={"finished_utc":datetime.now(timezone.utc).isoformat(),"exit":,"save_to":save,"setup":"v2","context":"taubench-v2","agent":"gpt-5.2","query":"zai-org/GLM-5.2"}
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
(pack/"SUMMARY.json").write_text(json.dumps(out,indent=2)+"\n")
print(json.dumps(out, indent=2))
PY
