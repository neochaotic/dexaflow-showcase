#!/usr/bin/env bash
# Deploy (build, push, register) the DAG projects under the given paths.
# Used after every edit: `make deploy DAG=labs/bigquery/01-daily-sales`.
# Set TRIGGER=1 to also start a run.
source "$(dirname "$0")/lib.sh"
need dexaflow; need curl
[[ $# -gt 0 ]] || die "usage: deploy-dags.sh <path> [<path> ...]"
# Check the paths before signing in, so a wrong folder fails at once.
dirs="$(dag_dirs "$@")"
[[ -n "${dirs}" ]] || die "no DAG project (dexaflow.yaml) under: $*"
source "$(dirname "$0")/target.sh"
[[ "${DEXAFLOW_BUILDER:-docker}" == "cloudbuild" ]] || need docker
configure_gcp

while read -r dir; do
  deploy_dag "${dir}"
  if [[ "${TRIGGER:-0}" == "1" ]]; then
    trigger_dag "$(dag_id "${dir}")"
  fi
done <<<"${dirs}"

wait_for_runs
