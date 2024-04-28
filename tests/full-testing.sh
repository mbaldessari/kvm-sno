#!/bin/bash
set -e -o pipefail
cd /home/michele/kvm-sno
git pull > /dev/null

# Deploy MCG on sno10 and sno11 
TODAY=$(date +%F)
LOGDIR="/var/log/vp-testing/${TODAY}"
LOCKFILE=/var/local/lock-vp-testing.lock
if [ -e "${LOCKFILE}" ]; then
   echo "vp testing is already running" | tee -a $logfile
   exit 1
fi

trap "sudo rm -f ${LOCKFILE}; exit" INT TERM EXIT
sudo touch "${LOCKFILE}"

sudo mkdir -p "${LOGDIR}"
sudo chown -R michele: "${LOGDIR}"

START=$(date -Iminutes)
echo "${START}: Start"
echo "${START}: Start" > "${LOGDIR}/start.txt"

TIME=$(date -Iminutes)
echo "${TIME}: Destroying and then installing test SNOs"
make SNOS=sno10,sno11,sno12 sno-destroy sno &> "${LOGDIR}/mcg-sno.log"

set +e
# This gets the latest IIB for gitops and writes it to /tmp/gitops-iib
TIME=$(date -Iminutes)
echo "${TIME}: Lookup gitops IIB"
ansible-playbook playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib.log"
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via gitops IIB"
make gitops-iib EXTRA_VARS="-e iib=$(cat /tmp/gitops-iib) -e hub=sno12" &> "${LOGDIR}/gitops-iib.log"
ret_gitops_iib=$?

TIME=$(date -Iminutes)
echo "${TIME}: Install gitea"
make gitea-destroy gitea &> "${LOGDIR}/gitea-install.log" 

TIME=$(date -Iminutes)
echo "${TIME}: Install mcg on sno10 and sno11"
make mcg EXTRA_VARS="-e hub=sno10 -e spoke=sno11" &> "${LOGDIR}/mcg-install.log"
ret_mcg=$?

# If both jobs were successfull we can just destroy the env if not we leave them running
if [ $ret_mcg -eq 0 ] && [ $ret_gitops_iib ]; then
    TIME=$(date -Iminutes)
    echo "${TIME}: Everyting worked ok. Destroying test SNOs"
    make SNOS=sno10,sno11,sno12 sno-destroy gitea-destroy &> "${LOGDIR}/mcg-destroy-after.log"
fi

# We kick off the setting up of the work SNOs in the background
# That way they can chug along while we test gitops-iib etc
TIME=$(date -Iminutes)
echo "${TIME}: Install fresh SNOs"
make sno-destroy sno &> "${LOGDIR}/mcg-fresh.log"

END=$(date -Iminutes)
echo "${END}: End"
echo "${END}: End" > "${LOGDIR}/end.txt"

S1=$(date +%s.%N -d "${START}")
E1=$(date +%s.%N -d "${END}")
D=$(echo "${E1}-${S1}" | bc)
TOTAL=$(date +%M -d @0${D})
echo "Total minutes: ${TOTAL}"
sudo rm -f "${LOCKFILE}"
