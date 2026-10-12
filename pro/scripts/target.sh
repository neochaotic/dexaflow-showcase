#!/usr/bin/env bash
# Resolves where DAGs go: GKE when this clone has a GKE environment
# (.out/gke.env, written by make gke-up), else the local k3d cluster.
# DEXAFLOW_TARGET=local|gke overrides it. Signs in and exports SERVER,
# REGISTRY and the token. Sourced by deploy-dags.sh and demo.sh.

if [[ -z "${DEXAFLOW_TARGET:-}" ]]; then
  if [[ -f "${REPO_ROOT}/.out/gke.env" ]]; then DEXAFLOW_TARGET=gke; else DEXAFLOW_TARGET=local; fi
fi
log "Target: ${DEXAFLOW_TARGET} (set DEXAFLOW_TARGET=local or gke to choose)"
if [[ "${DEXAFLOW_TARGET}" == "gke" ]]; then
  [[ -f "${REPO_ROOT}/.out/gke.env" ]] || die "run 'make gke-up gke-deploy' first"
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.out/gke.env"
fi

SERVER="${DEXAFLOW_SERVER:-http://localhost:${LOCAL_UI_PORT}}"
REGISTRY="${DEXAFLOW_REGISTRY:-${REGISTRY_NAME}:${REGISTRY_PORT}}"
PASSWORD="${DEXAFLOW_PASSWORD:-showcase-admin}"

curl -fsS "${SERVER}/readyz" >/dev/null 2>&1 \
  || die "no Dexaflow server at ${SERVER} (for GKE, run 'make gke-ui' first)"

log "Signing in to ${SERVER} as ${ADMIN_EMAIL}"
DEXAFLOW_TOKEN="$(printf '%s' "${PASSWORD}" | dexaflow auth create-token \
  --server "${SERVER}" --username "${ADMIN_EMAIL}" --password-stdin)"
export DEXAFLOW_TOKEN

# configure_gcp creates the keyless Google Cloud connection and the Variables
# the GCP DAGs read. Safe to run again.
configure_gcp() {
  [[ -n "${GCP_PROJECT:-}" ]] || return 0
  log "Configuring the keyless Google Cloud connection and Variables"
  run dexaflow connections set google_cloud_default --server "${SERVER}" \
    --conn-type google_cloud_platform --extra "{\"project\": \"${GCP_PROJECT}\"}" \
    --description "Keyless (Workload Identity), set by dexaflow-showcase"
  default_variable GCP_PROJECT "${GCP_PROJECT}"
  default_variable LAB_DATASET "${LAB_DATASET}"
}

# default_variable creates a Variable only when it does not exist yet, so a
# value changed in the UI survives later deploys.
default_variable() {
  if dexaflow variables get "$1" --server "${SERVER}" >/dev/null 2>&1; then
    log "Variable $1 already set, keeping its value (change it in Admin > Variables)"
  else
    run dexaflow variables set "$1" "$2" --server "${SERVER}"
  fi
}

# deploy_dag builds and pushes one DAG's image, then registers its dag.json.
# This is the whole Dexaflow deploy loop: compile, build, push, register.
deploy_dag() {
  local dir="$1" id tag
  id="$(dag_id "${dir}")"
  tag="$(date +%Y%m%d-%H%M%S)"
  log "${id}"
  # The DAG version defaults to `git describe`, so a second deploy of the same
  # commit would be rejected (409). Suffix it with the image tag.
  run dexaflow compile "${dir}" --image "${REGISTRY}/${id}:${tag}" --build --push \
    --dag-version "$(git -C "${dir}" describe --always --dirty 2>/dev/null || echo dev)-${tag}" \
    -o "${REPO_ROOT}/.out/dags/${id}.json"
  run dexaflow push "${REPO_ROOT}/.out/dags/${id}.json" --server "${SERVER}"
}

TRIGGERED_RUNS=()

# trigger_dag starts one run of a DAG, then unpauses it. The run is created
# first because unpausing a scheduled DAG makes the scheduler start its own run,
# which with max_active_runs=1 would block ours. wait_for_runs waits for it.
trigger_dag() {
  local id="$1" run_id
  run_id="$(curl -fsS -X POST "${SERVER}/api/v2/dags/${id}/dagRuns" \
    -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" -H 'Content-Type: application/json' \
    -d '{"logical_date": null}' | sed -n 's/.*"dag_run_id": *"\([^"]*\)".*/\1/p')"
  curl -fsS -X PATCH "${SERVER}/api/v2/dags/${id}" -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" \
    -H 'Content-Type: application/json' -d '{"is_paused": false}' >/dev/null
  TRIGGERED_RUNS+=("${id} ${run_id}")
  log "${id}: run ${run_id} triggered, see ${SERVER}/dags/${id}"
}

# wait_for_runs polls every triggered run until it finishes, prints a summary
# and fails when any run failed. WAIT=0 skips it.
wait_for_runs() {
  [[ "${WAIT:-1}" == "1" && ${#TRIGGERED_RUNS[@]} -gt 0 ]] || return 0
  log "Waiting for ${#TRIGGERED_RUNS[@]} run(s) to finish (WAIT=0 to skip)"
  local entry id run_id state failed=0 deadline=$((SECONDS + ${WAIT_TIMEOUT:-1800}))
  for entry in "${TRIGGERED_RUNS[@]}"; do
    read -r id run_id <<<"${entry}"
    while :; do
      state="$(curl -fsS "${SERVER}/api/v2/dags/${id}/dagRuns/${run_id}" \
        -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" | sed -n 's/.*"state": *"\([^"]*\)".*/\1/p')"
      [[ "${state}" == "success" || "${state}" == "failed" ]] && break
      (( SECONDS < deadline )) || { state="timeout"; break; }
      sleep 10
    done
    if [[ "${state}" == "success" ]]; then
      printf '  \033[32m%-8s\033[0m %s\n' "${state}" "${id}"
    else
      printf '  \033[31m%-8s\033[0m %s  %s/dags/%s/runs/%s\n' "${state}" "${id}" "${SERVER}" "${id}" "${run_id}"
      failed=1
    fi
  done
  [[ "${failed}" == "0" ]] || die "some runs did not succeed; open the links above for the task logs"
}

mkdir -p "${REPO_ROOT}/.out/dags"
