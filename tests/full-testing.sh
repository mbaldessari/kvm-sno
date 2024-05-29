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
echo "${TIME}: Install fresh SNOs"
make sno-destroy &> "${LOGDIR}/mcg-fresh-destroy.log"
make SNOS=${NEWSNOS} sno &> "${LOGDIR}/mcg-fresh.log"

exit 0
TIME=$(date -Iminutes)
echo "${TIME}: Destroying and then installing test SNOs"
make SNOS=sno10,sno11,sno12 sno-destroy sno &> "${LOGDIR}/mcg-test-snos.log"

set +e
# Let's do the ACM + MCE IIB dance here
TIME=$(date -Iminutes)
echo "${TIME}: Lookup acm + mce IIB"
ansible-playbook -e "operator=acm" -e "hub=sno10" playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib-acm.log"
ansible-playbook -e "operator=multicluster-engine" -e "hub=sno10" playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib-mce.log"
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via acm IIB"
make acm-iib EXTRA_VARS="-e iib_acm=$(cat /tmp/acm-iib-sno10) -e iib_mce=$(cat /tmp/multicluster-engine-iib-sno10) -e hub=sno10 -e spoke=sno11" &> "${LOGDIR}/acm-iib-gitops.log"
ret_acm_iib=$?

# This gets the latest IIB for gitops and writes it to /tmp/gitops-iib
TIME=$(date -Iminutes)
echo "${TIME}: Lookup gitops IIB"
ansible-playbook playbooks/iib-lookup.yml -e hub=sno12 &> "${LOGDIR}/lookup-iib.log"
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via gitops IIB"
make gitops-iib EXTRA_VARS="-e iib=$(cat /tmp/openshift-gitops-1-gitops-operator-bundle-iib-sno12) -e hub=sno12" &> "${LOGDIR}/gitops-iib-gitops.log"
ret_gitops_iib=$?

# Both tests went fine
if [ $ret_acm_iib -eq 0 ] && [ $ret_gitops_iib -eq 0 ]; then 
	echo "${TIME}: Everyting worked ok. Destroying test SNOs"
	make SNOS=sno10,sno11,sno12 sno-destroy &> "${LOGDIR}/mcg-destroy-after.log"
	NEWSNOS=sno1,sno2,sno3,sno4,sno5
else # If one of the tests failed leave the VMs there and only deploy two snos
	NEWSNOS=sno1,sno2
fi

#TIME=$(date -Iminutes)
#echo "${TIME}: Install gitea in the background"
#make gitea-destroy gitea &> "${LOGDIR}/gitea-install.log" &

# We kick off the setting up of the work SNOs in the background
# That way they can chug along while we test gitops-iib etc
TIME=$(date -Iminutes)
echo "${TIME}: Install fresh SNOs"
make sno-destroy &> "${LOGDIR}/mcg-fresh-destroy.log"
make SNOS=${NEWSNOS} sno &> "${LOGDIR}/mcg-fresh.log"


END=$(date -Iminutes)
echo "${END}: End"
echo "${END}: End" > "${LOGDIR}/end.txt"

S1=$(date +%s.%N -d "${START}")
E1=$(date +%s.%N -d "${END}")
D=$(echo "${E1}-${S1}" | bc)
TOTAL=$(echo "${D}/60" | bc)
echo "Total minutes: ${TOTAL}"
sudo rm -f "${LOCKFILE}"
