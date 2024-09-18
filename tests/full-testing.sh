#!/bin/bash
set -e -o pipefail
cd /home/michele/kvm-sno
git pull > /dev/null

TODAY=$(date +%F)
LOGDIR="/var/log/vp-testing/${TODAY}"
LOCKFILE=/var/local/lock-vp-testing.lock
if [ -e "${LOCKFILE}" ]; then
   echo "vp testing is already running" | tee -a $logfile
   exit 1
fi

rm -rf .ansible/retries/*
trap "sudo rm -f ${LOCKFILE}; exit" INT TERM EXIT
sudo touch "${LOCKFILE}"

sudo mkdir -p "${LOGDIR}"
sudo chown -R michele: "${LOGDIR}"

START=$(date -Iminutes)
echo "${START}: Start"
echo "${START}: Start" > "${LOGDIR}/start.txt"
echo "${TIME}: New OC mirror"
make ocp-mirror &> "${LOGDIR}/00-ocp-mirror.log"
echo "${TIME}: Set up gitea vm"
make gitea-destroy gitea &> "${LOGDIR}/00-gitea-vm.log"
echo "${TIME}: Set up nginx vm"
make nginx-destroy nginx &> "${LOGDIR}/00-nginx-vm.log"

echo "${TIME}: Install fresh SNOs"
make SNOS=sno1,sno2,sno3,sno4,sno5,sno6 sno-destroy &> "${LOGDIR}/01-mcg-fresh-destroy.log"
set +e
make SNOS=sno1,sno2,sno3,sno4,sno5,sno6 sno-direct &> "${LOGDIR}/02-mcg-fresh.log"
ret=$?
set -e
if [ $ret -ne 0 ]; then
	BROKEN_SNOS=$(cat .ansible/retries/sno-install.retry | paste -sd "," -)
	echo "Some VMs failed, retry only those: ${BROKEN_SNOS}"
	ansible-playbook -i hosts --extra-vars='{"snos":['$BROKEN_SNOS']}' playbooks/sno-destroy.yml &> "${LOGDIR}/02-retry-failed-ones-destroy.log"
	ansible-playbook -i hosts --extra-vars='{"snos":['$BROKEN_SNOS']}' --extra-vars='{enable_disconnected: False}' playbooks/sno-install.yml &> "${LOGDIR}/02-retry-failed-ones-create.log"
fi
set +e

exit 0

# Let's do the ACM + MCE IIB dance here
TIME=$(date -Iminutes)
echo "${TIME}: Lookup acm + mce IIB"
ansible-playbook -i hosts -e "operator=acm" -e "hub=sno1" playbooks/iib-lookup.yml &> "${LOGDIR}/03-lookup-iib-acm.log"
ansible-playbook -i hosts -e "operator=multicluster-engine" -e "hub=sno1" playbooks/iib-lookup.yml &> "${LOGDIR}/04-lookup-iib-mce.log"
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via acm IIB"
make acm-iib EXTRA_VARS="-e iib_acm=$(cat /tmp/acm-iib-sno1) -e iib_mce=$(cat /tmp/multicluster-engine-iib-sno1) -e hub=sno1 -e spoke=sno2" &> "${LOGDIR}/05-acm-iib-gitops.log"
ret_acm_iib=$?

# This gets the latest IIB for gitops and writes it to /tmp/gitops-iib
TIME=$(date -Iminutes)
echo "${TIME}: Lookup gitops IIB"
ansible-playbook playbooks/iib-lookup.yml -i hosts -e hub=sno3 &> "${LOGDIR}/06-lookup-gitops-iib.log"
TIME=$(date -Iminutes)
echo "${TIME}: Install mcg via gitops IIB"
make gitops-iib EXTRA_VARS="-e iib=$(cat /tmp/openshift-gitops-1-gitops-operator-bundle-iib-sno3) -e hub=sno3 -e spoke=sno4" &> "${LOGDIR}/07-gitops-iib-gitops.log"
ret_gitops_iib=$?

# Both tests went fine
if [ $ret_acm_iib -eq 0 ] && [ $ret_gitops_iib -eq 0 ]; then 
	echo "${TIME}: Everyting worked ok. Destroying test SNOs"
	make SNOS=sno1,sno2,sno3,sno4 sno-destroy &> "${LOGDIR}/08-mcg-destroy-after.log"
	make SNOS=sno1,sno2,sno3,sno4 sno-direct &> "${LOGDIR}/09-mcg-recreate-after.log"
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
