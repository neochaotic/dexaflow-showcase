#!/usr/bin/env bash
# Deploy and trigger the use cases: all of them, or the one passed as $1.
# GCP use cases (NN-gcp-*) are skipped unless GCP_PROJECT is set, which
# `make gke-demo` does through .out/gke.env.
source "$(dirname "$0")/lib.sh"
need dexaflow; need curl
source "$(dirname "$0")/target.sh"
[[ "${DEXAFLOW_BUILDER:-docker}" == "cloudbuild" ]] || need docker
configure_gcp

while read -r dir; do
  id="$(dag_id "${dir}")"
  if [[ "${dir}" == *"/use-cases/"[0-9]*"-gcp-"* && -z "${GCP_PROJECT:-}" ]]; then
    warn "${id}: skipped, it needs Google Cloud (run it on GKE, see docs/gke.md)"
    continue
  fi
  deploy_dag "${dir}"
  trigger_dag "${id}"
done < <(use_case_dirs "${1:-all}")

wait_for_runs
