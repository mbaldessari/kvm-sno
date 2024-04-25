#!/bin/bash
set -e -o pipefail
cd /home/michele/kvm-sno
git pull

# Deploy MCG on sno10 and sno11 
TODAY=$(date +%F)
LOGDIR="/var/log/vp-testing/${TODAY}"

sudo mkdir -p "${LOGDIR}"
sudo chown -R michele: "${LOGDIR}"

# Destroy everything first
time make SNOS=sno1,sno2,sno3,sno4,sno5,sno6,sno7,sno8,sno9,sno10,sno11,sno12 sno-destroy gitea-destroy &> "${LOGDIR}/mcg-destroy.log"
# This gets the latest IIB for gitops and writes it to /tmp/gitops-iib
ansible-playbook playbooks/iib-lookup.yml &> "${LOGDIR}/lookup-iib.log"
time make SNOS=sno10,sno11,sno12 sno &> "${LOGDIR}/mcg-sno.log"
set +e
time make gitops-iib EXTRA_VARS="-e iib=$(cat /tmp/gitops-iib) -e hub=sno10 -e spoke=sno11" &> "${LOGDIR}/gitops-iib.log"
time make mcg EXTRA_VARS="-e hub=sno10 -e spoke=sno11" &> "${LOGDIR}/mcg-install.log"

