#!/usr/bin/env bash
# Resolves where DAGs go: the local k3d cluster (default) or GKE
# (DEXAFLOW_TARGET=gke), signs in, and exports SERVER, REGISTRY and the token.
# Sourced by deploy-dags.sh and demo.sh.

if [[ "${DEXAFLOW_TARGET:-local}" == "gke" ]]; then
  [[ -f "${REPO_ROOT}/.out/gke.env" ]] || die "run 'make gke-up gke-deploy' first"
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.out/gke.env"
fi

SERVER="${DEXAFLOW_SERVER:-http://localhost:${LOCAL_UI_PORT}}"
REGISTRY="${DEXAFLOW_REGISTRY:-${REGISTRY_NAME}:${REGISTRY_PORT}}"
PASSWORD="${DEXAFLOW_PASSWORD:-showcase-admin}"

curl -fsS "${SERVER}/readyz" >/dev/null 2>&1 \
  || die "no Dexaflow server at ${SERVER} (for GKE, keep 'make gke-ui' running in another terminal)"

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
  run dexaflow variables set GCP_PROJECT "${GCP_PROJECT}" --server "${SERVER}"
  run dexaflow variables set LAB_DATASET "${LAB_DATASET}" --server "${SERVER}"
}

# deploy_dag builds and pushes one DAG's image, then registers its dag.json.
# This is the whole Dexaflow deploy loop: compile, build, push, register.
deploy_dag() {
  local dir="$1" id tag
  id="$(dag_id "${dir}")"
  tag="$(date +%Y%m%d-%H%M%S)"
  log "${id}"
  run dexaflow compile "${dir}" --image "${REGISTRY}/${id}:${tag}" --build --push \
    -o "${REPO_ROOT}/.out/dags/${id}.json"
  run dexaflow push "${REPO_ROOT}/.out/dags/${id}.json" --server "${SERVER}"
}

# trigger_dag unpauses a DAG and starts one run.
trigger_dag() {
  local id="$1"
  curl -fsS -X PATCH "${SERVER}/api/v2/dags/${id}" -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" \
    -H 'Content-Type: application/json' -d '{"is_paused": false}' >/dev/null
  curl -fsS -X POST "${SERVER}/api/v2/dags/${id}/dagRuns" -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" \
    -H 'Content-Type: application/json' -d '{"logical_date": null}' >/dev/null
  log "${id}: run triggered, see ${SERVER}/dags/${id}"
}

mkdir -p "${REPO_ROOT}/.out/dags"
