# Your Dexaflow DAG workspace. Run `make help` for the targets.
# The platform (cluster, registry, login) lives in the dexaflow-showcase clone
# below; this folder only holds your DAGs, so you can version it on its own.
SHELL := /usr/bin/env bash
SHOWCASE ?= __SHOWCASE__
# Empty: GKE when the platform clone has a GKE environment, else local.
TARGET ?=
.PHONY: help new deploy deploy-all list

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-11s\033[0m %s\n", $$1, $$2}'

new: ## Scaffold a DAG project under dags/ (NAME=my_dag)
	@DAGS_DIR=$(CURDIR)/dags bash $(SHOWCASE)/pro/scripts/new-dag.sh $(NAME)

deploy: ## Build, push and register one DAG (DAG=dags/my_dag, TRIGGER=1 to also run it)
	@test -n "$(DAG)" || { echo "usage: make deploy DAG=dags/<name> [TRIGGER=1]"; exit 1; }
	@# A path that is not in this workspace but is in the platform clone
	@# (use-cases/..., labs/...) deploys from the clone.
	@dag="$(abspath $(DAG))"; [ -e "$$dag" ] || [ ! -e "$(SHOWCASE)/$(DAG)" ] || dag="$(SHOWCASE)/$(DAG)"; \
	  DEXAFLOW_TARGET=$(TARGET) bash $(SHOWCASE)/pro/scripts/deploy-dags.sh "$$dag"

deploy-all: ## Build, push and register every DAG under dags/
	@DEXAFLOW_TARGET=$(TARGET) bash $(SHOWCASE)/pro/scripts/deploy-dags.sh $(CURDIR)/dags

list: ## List the DAG projects in this workspace
	@find dags -name dexaflow.yaml -exec dirname {} \; | sort
