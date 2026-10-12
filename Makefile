# Dexaflow Showcase. Run `make help` for the list of targets.
SHELL := /usr/bin/env bash
SCRIPTS := pro/scripts
USE_CASE ?= all

.PHONY: help cli doctor workspace dry-run up demo deploy new-dag down gke-up gke-deploy gke-ui gke-ui-stop gke-info gke-demo gke-lab gke-reset gke-down

help: ## Show this help
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

doctor: ## Check that the tools this repo needs are installed
	@bash $(SCRIPTS)/doctor.sh

cli: ## Install the pinned Dexaflow CLI into ~/.dexaflow/bin
	@bash $(SCRIPTS)/install-cli.sh

dry-run: ## Validate every DAG and render every manifest, no cluster needed
	@bash $(SCRIPTS)/dry-run.sh

up: ## Create the local k3d cluster and install Dexaflow Pro on it
	@bash $(SCRIPTS)/up.sh

demo: ## Build, register and trigger the use cases (USE_CASE=01-hello-pipeline for one)
	@DEXAFLOW_TARGET=$${DEXAFLOW_TARGET:-local} bash $(SCRIPTS)/demo.sh $(USE_CASE)

deploy: ## Build, push and register the DAGs under DAG=<path> (TRIGGER=1 to also run them)
	@bash $(SCRIPTS)/deploy-dags.sh $(DAG)

workspace: ## Create your own DAG workspace next to this clone (DIR=path to choose)
	@bash $(SCRIPTS)/workspace.sh $(DIR)

new-dag: ## Scaffold a new DAG under my-dags/ (NAME=my_dag)
	@bash $(SCRIPTS)/new-dag.sh $(NAME)

down: ## Delete the local cluster and everything in it
	@bash $(SCRIPTS)/down.sh

gke-up: ## Provision the GKE demo environment (needs gcloud, see docs/gke.md)
	@bash pro/platform/gke/provision.sh

gke-deploy: ## Install or upgrade Dexaflow Pro on the GKE demo environment
	@bash pro/platform/gke/deploy.sh

gke-ui: ## Open the GKE UI on http://localhost:8081, in the background
	@bash pro/platform/gke/ui.sh

gke-ui-stop: ## Stop the background GKE UI port-forward
	@bash pro/platform/gke/ui.sh stop


gke-info: ## Print the GKE UI address, login user and where the password is
	@bash pro/platform/gke/info.sh

gke-demo: ## Build, register and trigger the use cases on GKE (needs make gke-ui)
	@DEXAFLOW_TARGET=gke bash $(SCRIPTS)/demo.sh $(USE_CASE)

gke-lab: ## Deploy every lab on GKE, run the BigQuery lab setup and one medallion day
	@DEXAFLOW_TARGET=gke bash $(SCRIPTS)/deploy-dags.sh labs/bigquery/01-daily-sales labs/bigquery/02-quality-checks
	@DEXAFLOW_TARGET=gke TRIGGER=1 bash $(SCRIPTS)/deploy-dags.sh labs/bigquery/00-setup labs/medallion

gke-reset: ## Empty the Dexaflow database on GKE (DAGs, runs); keeps cluster, login, BigQuery
	@bash pro/platform/gke/reset.sh

gke-down: ## Delete the GKE demo environment
	@bash pro/platform/gke/teardown.sh
