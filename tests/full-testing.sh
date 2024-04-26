#!/bin/bash
set -e -o pipefail
cd /home/michele/kvm-sno
git pull

# Deploy MCG on sno10 and sno11 
TODAY=$(date +%F)
LOGDIR="/var/log/vp-testing/${TODAY}"

sudo mkdir -p "${LOGDIR}"
sudo chown -R michele: "${LOGDIR}"


# Destroy testing VMs first
make SNOS=sno10,sno11,sno12 sno-destroy sno &> "${LOGDIR}/mcg-sno.log"

set +e
# This gets the latest IIB for gitops and writes it to /tmp/gitops-iib
ansible-playbook playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib.log"
make gitops-iib EXTRA_VARS="-e iib=$(cat /tmp/gitops-iib) -e hub=sno12" &> "${LOGDIR}/gitops-iib.log"
ret_gitops_iib=$?

make gitea-destroy gitea &> "${LOGDIR}/gitea-install.log" 
make mcg EXTRA_VARS="-e hub=sno10 -e spoke=sno11" &> "${LOGDIR}/mcg-install.log"
ret_mcg=$?

# If both jobs were successfull we can just destroy the env if not we leave them running
if [ $ret_mcg -eq 0 ] && [ $ret_gitops_iib ]; then
    make SNOS=sno10,sno11,sno12 sno-destroy gitea-destroy &> "${LOGDIR}/mcg-destroy-after.log"
fi

# We kick off the setting up of the work SNOs in the background
# That way they can chug along while we test gitops-iib etc
make SNOS=sno1,sno2,sno3,sno4,sno5 sno-destroy sno &> "${LOGDIR}/mcg-fresh.log"
