#!/bin/bash
set -e -o pipefail
cd /home/michele/kvm-sno

TODAY=$(date +%F)
LOGDIR="/var/log/vp-testing/${TODAY}/acm-iib"
LOCKFILE=/var/local/lock-vp-testing-acm-iib.lock
HUB="${HUB:-sno4}"
SPOKE="${SPOKE:-sno5}"
MYSNOS="${HUB},${SPOKE}"
GITREPO="${GITREPO:-https://github.com/validatedpatterns/multicloud-gitops}"
GITBRANCH="${GITBRANCH:-main}"

if [ -e "${LOCKFILE}" ]; then
   echo "vp testing is already running" | tee -a $logfile
   exit 1
fi

trap "sudo rm -f ${LOCKFILE}; exit" INT TERM EXIT
sudo touch "${LOCKFILE}"

sudo mkdir -p "${LOGDIR}"
sudo chown -R michele: "${LOGDIR}"

START=$(date -Iminutes)
echo "${START}: Start testing ACM IIB on ${HUB} - ${SPOKE}"

TIME=$(date -Iminutes)
echo "${TIME}: Destroying and then installing test SNOs"
make SNOS=${MYSNOS} sno-destroy sno &> "${LOGDIR}/acm-iib-test-snos.log"

set +e
# Let's do the ACM + MCE IIB dance here
TIME=$(date -Iminutes)
echo "${TIME}: Lookup acm + mce IIB"
ansible-playbook -e "operator=acm" playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib-acm.log"
ansible-playbook -e "operator=multicluster-engine" playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib-mce.log"
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via acm IIB"
make acm-iib EXTRA_VARS="-e iib_acm=$(cat /tmp/acm-iib) -e iib_mce=$(cat /tmp/multicluster-engine-iib) -e gitrepo=${GITREPO} -e gitbranch=${GITBRANCH} -e hub=${HUB} -e spoke=${SPOKE}" &> "${LOGDIR}/acm-iib-gitops.log"
ret_acm_iib=$?
# Both tests went fine
if [ $ret_acm_iib -eq 0 ]; then 
	echo "${TIME}: Everyting worked ok"
fi

END=$(date -Iminutes)
echo "${END}: End"
echo "${END}: End" > "${LOGDIR}/end.txt"

S1=$(date +%s.%N -d "${START}")
E1=$(date +%s.%N -d "${END}")
D=$(echo "${E1}-${S1}" | bc)
TOTAL=$(echo "${D}/60" | bc)
echo "Total minutes: ${TOTAL}"
sudo rm -f "${LOCKFILE}"
