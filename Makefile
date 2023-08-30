SNOS ?= sno1,sno2,sno3
NODE ?= sno1

TAGS ?=
ifdef TAGS
	TAGS_STRING = --tags $(TAGS)
endif

##@ Common Tasks
.PHONY: help
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: sno-prepare
sno-prepare: ## Prepares kvm host with utils to install SNOs
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-prepare.yml

.PHONY: sno
sno: sno-prepare ## Install an SNO vm on kuemper host
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-install.yml

.PHONY: sno-parallel
sno-parallel: sno-prepare ## Install snos in parallel (experimental)
	@set -x; echo -n '' > /tmp/parallel; for i in `echo $(SNOS) | tr ',' ' '`; do\
		echo "--extra-vars='{\"snos\":[$$i]}'" >> /tmp/parallel;\
	done;\
	parallel --ungroup -a /tmp/parallel eval ansible-playbook -i hosts playbooks/sno-install.yml

.PHONY: ssl
ssl: ## Install my SSL certs on the SNO nodes
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-ssl.yml

.PHONY: sno-destroy
sno-destroy: ## Destroy installed SNOs and temp folders
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-destroy.yml

##@ Day-2 Tasks
.PHONY: mcg
mcg: ## Install multicloud gitops on all three snos
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-mcg.yml

.PHONY: argo
argo: ## Install argocd from git on sno1
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' -e node=$(NODE) playbooks/sno-argocd-git.yml

.PHONY: private
private: ## Test mcg with private repo
	ansible-playbook -i hosts $(TAGS_STRING) --extra-vars='{"snos":[$(SNOS)]}' -e node=$(NODE) playbooks/sno-private.yml

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
