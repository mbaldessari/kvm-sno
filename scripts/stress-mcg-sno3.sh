#!/bin/bash
set -e
MCG_RUNS=40

for i in $(seq 1 ${MCG_RUNS}); do
  echo "=== MCG run $i/${MCG_RUNS} ==="
  ansible-playbook -i hosts ${TAGS_STRING} --extra-vars='{"snos":[sno3,sno4]}' -e hub=sno3 -e spoke=sno4 ${EXTRA_VARS} playbooks/sno-restore.yml || { echo "FAILED sno-restore on run $i/${MCG_RUNS}"; exit 1; }
  ansible-playbook -i hosts ${TAGS_STRING} --extra-vars='{"snos":[sno3,sno4]}' -e hub=sno3 -e spoke=sno4 ${EXTRA_VARS} playbooks/sno-mcg.yml || { echo "FAILED on run $i/${MCG_RUNS}"; exit 1; }
done
echo "All ${MCG_RUNS} runs passed"

