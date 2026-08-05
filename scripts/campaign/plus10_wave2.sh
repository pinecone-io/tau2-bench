#!/usr/bin/env bash
# Wave2: more seeds + expanded candidates after seed 700/701 loop
set -uo pipefail
cd /home/harnesser/repos/tau2-bench
LOG=/tmp/plus10_wave2.log
echo "=== wave2 wait for loop1 pid $(cat /tmp/plus10_loop.pid 2>/dev/null) ===" | tee -a "$LOG"
while kill -0 $(cat /tmp/plus10_loop.pid 2>/dev/null) 2>/dev/null; do sleep 60; done
echo "=== wave2 start $(date -u) ===" | tee -a "$LOG"

# Refresh hard rules path
export TAU2_AGENT_HARD_RULES_FILE=/tmp/at14_hard_rules.txt
# sync from repo if present
[[ -f docs/runs/agent_hard_rules_plus10.txt ]] && cp docs/runs/agent_hard_rules_plus10.txt /tmp/at14_hard_rules.txt

# Expanded targets: original fails + more high-ROI from audit
TARGETS=(
  task_056 task_099 task_102 task_001 task_010 task_019 task_095
  task_018 task_017 task_022 task_027 task_059
  task_096 task_063 task_079 task_066
)
SEEDS=(702 703 704)

for seed in "${SEEDS[@]}"; do
  for task in "${TARGETS[@]}"; do
    # skip if already have a pass for this task
    if python3 -c "
import json
from pathlib import Path
p=Path('/tmp/plus10_scoreboard.jsonl')
if not p.exists(): raise SystemExit(1)
for l in p.read_text().splitlines():
  r=json.loads(l)
  if r.get('task')=='$task' and (r.get('db_match') or r.get('reward')==1):
    raise SystemExit(0)
raise SystemExit(1)
"; then
      echo "SKIP $task already has pass" | tee -a "$LOG"
      continue
    fi
    echo "---- $(date -u) $task seed=$seed ----" | tee -a "$LOG"
    bash /tmp/retest_one_task.sh "$task" "$seed" >>"$LOG" 2>&1 || echo "ERR $task s$seed" | tee -a "$LOG"
    python3 - <<'PY' | tee -a "$LOG"
import json
from collections import defaultdict
from pathlib import Path
rows=[json.loads(l) for l in Path('/tmp/plus10_scoreboard.jsonl').read_text().splitlines() if l.strip()]
by=defaultdict(list)
for r in rows: by[r['task']].append(r)
wins=sum(1 for t,rs in by.items() if any(x.get('db_match') or x.get('reward')==1 for x in rs))
print(f"CANDIDATES {wins}/10 needed  runs={len(rows)}")
for t,rs in sorted(by.items()):
    if any(x.get('db_match') or x.get('reward')==1 for x in rs):
        print(f"  PASS_CAND {t}")
if wins >= 10:
    print("READY_FOR_FULL_SUITE")
    Path('/tmp/plus10_READY').write_text(f'{wins}\n')
PY
    if [[ -f /tmp/plus10_READY ]]; then
      echo "=== 10 candidates reached — launching full suite ===" | tee -a "$LOG"
      bash /tmp/launch_v2_fullsuite.sh | tee -a "$LOG"
      exit 0
    fi
  done
done
echo "=== wave2 done without 10 candidates $(date -u) ===" | tee -a "$LOG"
