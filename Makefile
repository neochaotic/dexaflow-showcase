# Dexaflow Showcase. Run `make help` for the list of targets.
SHELL := /usr/bin/env bash
SCRIPTS := pro/scripts
USE_CASE ?= all

.PHONY: help doctor dry-run up demo deploy new-dag down gke-up gke-deploy gke-ui gke-demo gke-lab gke-down

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

doctor: ## Check that the tools this repo needs are installed
	@$(SCRIPTS)/doctor.sh

dry-run: ## Validate every DAG and render every manifest, no cluster needed
	@$(SCRIPTS)/dry-run.sh

up: ## Create the local k3d cluster and install Dexaflow Pro on it
	@$(SCRIPTS)/up.sh

demo: ## Build, register and trigger the use cases (USE_CASE=01-hello-pipeline for one)
	@$(SCRIPTS)/demo.sh $(USE_CASE)

deploy: ## Build, push and register the DAGs under DAG=<path> (TRIGGER=1 to also run them)
	@$(SCRIPTS)/deploy-dags.sh $(DAG)

new-dag: ## Scaffold a new DAG under my-dags/ (NAME=my_dag)
	@$(SCRIPTS)/new-dag.sh $(NAME)

down: ## Delete the local cluster and everything in it
	@$(SCRIPTS)/down.sh

gke-up: ## Provision the GKE demo environment (needs gcloud, see docs/gke.md)
	@pro/platform/gke/provision.sh

gke-deploy: ## Install or upgrade Dexaflow Pro on the GKE demo environment
	@pro/platform/gke/deploy.sh

gke-ui: ## Forward the GKE UI to http://localhost:8081
	@source versions.env && kubectl -n $$NAMESPACE port-forward svc/$$RELEASE $$GKE_UI_PORT:8080

gke-demo: ## Build, register and trigger the use cases on GKE (needs make gke-ui running)
	@DEXAFLOW_TARGET=gke $(SCRIPTS)/demo.sh $(USE_CASE)

gke-lab: ## Deploy the BigQuery lab on GKE and run its setup DAG
	@DEXAFLOW_TARGET=gke $(SCRIPTS)/deploy-dags.sh labs/bigquery
	@DEXAFLOW_TARGET=gke TRIGGER=1 $(SCRIPTS)/deploy-dags.sh labs/bigquery/00-setup

gke-down: ## Delete the GKE demo environment
	@pro/platform/gke/teardown.sh
