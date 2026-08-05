#!/usr/bin/env bash
# +10 trial0 flip campaign — retest priority fails with hardened policy/rules
set -uo pipefail
cd /home/harnesser/repos/tau2-bench
LOG=/tmp/plus10_loop.log
SB=/tmp/plus10_scoreboard.jsonl
: > "$SB"
echo "=== plus10 start $(date -u) ===" | tee -a "$LOG"

# Wave 1: smoking guns first (1 seed each, then expand)
# Order by expected flip ease
TARGETS=(
  task_027
  task_001
  task_010
  task_095
  task_056
  task_099
  task_102
  task_017
  task_019
  task_022
  task_018
  task_059
)

SEEDS=(700 701)

for seed in "${SEEDS[@]}"; do
  for task in "${TARGETS[@]}"; do
    echo "---- $(date -u) $task seed=$seed ----" | tee -a "$LOG"
    if bash /tmp/retest_one_task.sh "$task" "$seed" >>"$LOG" 2>&1; then
      echo "OK finished $task s$seed" | tee -a "$LOG"
    else
      echo "ERR $task s$seed exit=$?" | tee -a "$LOG"
    fi
    # scoreboard summary
    python3 - <<'PY' | tee -a "$LOG"
import json
from collections import defaultdict
from pathlib import Path
p=Path("/tmp/plus10_scoreboard.jsonl")
if not p.exists() or not p.read_text().strip():
    print("scoreboard empty"); raise SystemExit
rows=[json.loads(l) for l in p.read_text().splitlines() if l.strip()]
by=defaultdict(list)
for r in rows:
    by[r["task"]].append(r)
wins=0
for t,rs in sorted(by.items()):
    any_p=any(x.get("db_match") or x.get("reward")==1.0 for x in rs)
    wins += 1 if any_p else 0
    marks=" ".join(("P" if (x.get("db_match") or x.get("reward")==1.0) else "F") for x in rs)
    print(f"  {t}: {marks}  any={any_p}")
print(f"TASKS_WITH_ANY_PASS {wins}/{len(by)}  total_runs={len(rows)}")
PY
  done
done
echo "=== plus10 done $(date -u) ===" | tee -a "$LOG"
