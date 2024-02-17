SNOS ?= sno1,sno2,sno3,sno4,sno5
NODE ?= sno1
IIB ?=

TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

EXTRA_VARS ?=

##@ Common Tasks
.PHONY: help
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: ocp-versions
ocp-versions: ## Prints latest minor versions for ocp
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/print-ocp-versions.yml

.PHONY: ocp-clients
ocp-clients: ## Reads ocp_versions list and makes sure client tools are downloaded and uncompressed
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/ocp-clients.yml

.PHONY: ocp-mirror
ocp-mirror: ## Reads ocp_versions list and makes sure client tools are downloaded and uncompressed
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/ocp-mirror.yml

.PHONY: sno
sno: ## Install an SNO vm on kuemper host
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' $(EXTRA_VARS) playbooks/sno-install.yml

.PHONY: sno-nomirror
sno-nomirror: ## Install SNO without using docker pull through caches (needed for IIB)
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' --extra-vars='{enable_local_docker_mirror: False}' playbooks/sno-install.yml

.PHONY: sno-parallel
sno-parallel: ## Install snos in parallel (experimental)
	@set -x; echo -n '' > /tmp/parallel; for i in `echo $(SNOS) | tr ',' ' '`; do\
		echo "--extra-vars='{\"snos\":[$$i]}'" >> /tmp/parallel;\
	done;\
	parallel --ungroup -a /tmp/parallel eval ansible-playbook -i hosts playbooks/sno-install.yml

.PHONY: ssl
ssl: ## Install my SSL certs on the SNO nodes
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' $(EXTRA_VARS) playbooks/sno-ssl.yml

.PHONY: sno-destroy
sno-destroy: ## Destroy installed SNOs and temp folders
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' $(EXTRA_VARS) playbooks/sno-destroy.yml

.PHONY: rhels
rhels: ## Create RHEL vms
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/rhels.yml

.PHONY: rhels-destroy
rhels-destroy: ## Destroy installed RHELs VMS
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/rhels-destroy.yml

.PHONY: gitea
gitea: ## Create RHEL vms
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/gitea.yml

.PHONY: gitea-destroy
gitea-destroy: ## Destroy installed RHELs VMS
	ansible-playbook -i hosts $(TAGS_STRING) $(EXTRA_VARS) playbooks/gitea-destroy.yml
##@ Day-2 Tasks
.PHONY: mcg
mcg: ## Install multicloud gitops on all three snos
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' $(EXTRA_VARS) playbooks/sno-mcg.yml

.PHONY: agof
agof: ## Install AGOF on the two RHEL boxes
	ansible-playbook -i hosts $(TAGS_STRING) -e automation_hub_token_vault=`cat ~/.ansible-hub-token` $(EXTRA_VARS) playbooks/agof.yml

.PHONY: vehicle
vehicle: ## Install Connected Vehicle Architecture on SNO1
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' $(EXTRA_VARS) playbooks/sno-connectedvehicle.yml

.PHONY: argo
argo: ## Install argocd from git on sno1
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' -e node=$(NODE) $(EXTRA_VARS) playbooks/sno-argocd-git.yml

.PHONY: gitops-iib
gitops-iib: ## Install mcg with gitops from iib
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' -e node=$(NODE) -e iib=$(IIB) $(EXTRA_VARS) playbooks/sno-gitops-iib.yml

.PHONY: acm-iib
acm-iib: ## Install mcg with acm from iib
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' -e node=$(NODE) -e iib=$(IIB) $(EXTRA_VARS) playbooks/sno-acm-iib.yml

.PHONY: private
private: ## Test mcg with private repo
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' -e node=$(NODE) playbooks/sno-private.yml

.PHONY: poweroff
poweroff: ## powers off kuemper
	ansible -i hosts -m shell -a "poweroff" kvm

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
