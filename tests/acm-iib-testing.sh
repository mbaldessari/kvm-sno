#!/bin/bash
set -e -o pipefail
cd /home/michele/kvm-sno

TODAY=$(date +%F)
HUB="${HUB:-sno4}"
SPOKE="${SPOKE:-sno5}"
LOCKFILE=/var/local/lock-vp-testing-acm-iib-${HUB}.lock
LOGDIR="/var/log/vp-testing/${TODAY}/acm-iib/${HUB}"
MYSNOS="${HUB},${SPOKE}"
GITREPO="${GITREPO:-https://github.com/validatedpatterns/multicloud-gitops}"
GITBRANCH="${GITBRANCH:-main}"
REUSE_SNOS="${REUSE_SNOS:-false}"
ACM_IIB="${ACM_IIB:-}"
MCE_IIB="${MCE_IIB:-}"

if [ -e "${LOCKFILE}" ]; then
   echo "vp testing is already running" | tee -a $logfile
   exit 1
fi

trap "sudo rm -f ${LOCKFILE}; exit" INT TERM EXIT
sudo touch "${LOCKFILE}"

sudo mkdir -p "${LOGDIR}"
sudo chown -R michele: "${LOGDIR}"

START=$(date -Iminutes)
echo "${START}: Start testing ACM IIB on ${HUB} - ${SPOKE}: ${GITREPO} - ${GITBRANCH}"

if [ ${REUSE_SNOS} = "false" ]; then
  echo "Recreate SNOs ${HUB} - ${SPOKE}"
  TIME=$(date -Iminutes)
  echo "${TIME}: Destroying and then installing test SNOs"
  make SNOS=${MYSNOS} sno-destroy sno &> "${LOGDIR}/acm-iib-test-snos.log"
else
  echo "Reuse SNOs ${HUB} - ${SPOKE}"
fi

set +e
# Let's do the ACM + MCE IIB dance here
TIME=$(date -Iminutes)
echo "${TIME}: Lookup acm + mce IIB"
if [ -n ${ACM_IIB} ]; then
  echo "User ACM IIB: ${ACM_IIB}"
  sudo rm -f /tmp/acm-iib-${HUB}
  echo "${ACM_IIB}" > /tmp/acm-iib-${HUB}
else
  ansible-playbook -e "operator=acm" -e "hub=${HUB}" playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib-acm.log"
fi
if [ -n ${MCE_IIB} ]; then
  echo "User MCE IIB: ${MCE_IIB}"
  sudo rm -f /tmp/multicluster-engine-iib-${HUB}
  echo "${MCE_IIB}" > /tmp/multicluster-engine-iib-${HUB}
else
  ansible-playbook -e "operator=multicluster-engine" -e "hub=${HUB}" playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib-mce.log"
fi
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via acm IIB"
make acm-iib EXTRA_VARS="-e iib_acm=$(cat /tmp/acm-iib-${HUB}) -e iib_mce=$(cat /tmp/multicluster-engine-iib-${HUB}) -e gitrepo=${GITREPO} -e gitbranch=${GITBRANCH} -e hub=${HUB} -e spoke=${SPOKE}" &> "${LOGDIR}/acm-iib-gitops.log"
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
