SNOS := sno1,sno2,sno3

##@ Common Tasks
.PHONY: help
help: ## This help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^(\s|[a-zA-Z_0-9-])+:.*?##/ { printf "  \033[36m%-35s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

.PHONY: sno
sno: ## Install an SNO vm on kuemper host
	ansible-playbook -i hosts --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-install.yml

.PHONY: sno-destroy
sno-destroy: ## Destroy installed SNOs and temp folders
	ansible-playbook -i hosts --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-destroy.yml

##@ Patterns Tasks
.PHONY: mcg
mcg: ## Install multicloud gitops on all three snos
	ansible-playbook -vvv -i hosts --extra-vars='{"snos":[$(SNOS)]}' playbooks/sno-mcg.yml

##@ CI / Linter tasks
.PHONY: lint
lint: ## Run ansible-lint on the codebase
	ansible-lint -v
