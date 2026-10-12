#!/usr/bin/env bash
# Deploy (build, push, register) the DAG projects under the given paths.
# Used after every edit: `make deploy DAG=labs/bigquery/01-daily-sales`.
# Set TRIGGER=1 to also start a run.
source "$(dirname "$0")/lib.sh"
need dexaflow; need docker; need curl
[[ $# -gt 0 ]] || die "usage: deploy-dags.sh <path> [<path> ...]"
source "$(dirname "$0")/target.sh"
configure_gcp

while read -r dir; do
  deploy_dag "${dir}"
  [[ "${TRIGGER:-0}" == "1" ]] && trigger_dag "$(dag_id "${dir}")"
done < <(dag_dirs "$@")

wait_for_runs
