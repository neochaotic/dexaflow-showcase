#!/usr/bin/env bash
# Resolves where DAGs go: GKE when this clone has a GKE environment
# (.out/gke.env, written by make gke-up), else the local k3d cluster.
# DEXAFLOW_TARGET=local|gke overrides it. Signs in and exports SERVER,
# REGISTRY and the token. Sourced by deploy-dags.sh and demo.sh.

if [[ -z "${DEXAFLOW_TARGET:-}" ]]; then
  if [[ -f "${REPO_ROOT}/.out/gke.env" ]]; then DEXAFLOW_TARGET=gke; else DEXAFLOW_TARGET=local; fi
fi
log "Target: ${DEXAFLOW_TARGET} (set DEXAFLOW_TARGET=local or gke to choose)"
# The dexaflow CLI (0.5.7+) reads DEXAFLOW_TARGET as the name of one of its own
# targets and fails on "gke"; keep ours out of the environment it inherits.
export -n DEXAFLOW_TARGET
if [[ "${DEXAFLOW_TARGET}" == "gke" ]]; then
  [[ -f "${REPO_ROOT}/.out/gke.env" ]] || die "run 'make gke-up gke-deploy' first"
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.out/gke.env"
  # Environments from before Cloud Build builds: run make gke-up again.
  [[ -n "${DEXAFLOW_BUILDER:-}" ]] || die "this GKE environment predates Cloud Build image builds: run 'make gke-up' again (safe, it keeps everything)"
  export GCP_PROJECT GKE_REGION
fi

SERVER="${DEXAFLOW_SERVER:-http://localhost:${LOCAL_UI_PORT}}"
REGISTRY="${DEXAFLOW_REGISTRY:-${REGISTRY_NAME}:${REGISTRY_PORT}}"
PASSWORD="${DEXAFLOW_PASSWORD:-showcase-admin}"

if ! curl -fsS "${SERVER}/readyz" >/dev/null 2>&1; then
  [[ "${DEXAFLOW_TARGET}" == "gke" ]] || [[ -f "${REPO_ROOT}/.out/gke.env" ]] \
    || die "no Dexaflow environment in this clone: run 'make gke-up' and 'make gke-deploy' (LAB.md Tasks 3 and 4), or 'make up' for a local one"
  die "no Dexaflow server at ${SERVER}: run 'make gke-ui' (its log is .out/gke-ui.log)"
fi

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

# push_image pushes a built image. Cloud Shell's Docker daemon cannot connect to
# Artifact Registry (containers can), so when `docker push` fails for a
# *.pkg.dev image, the image is pushed from a container with crane instead.
push_image() {
  local image="$1" log_file="$2" tar
  run docker push --quiet "${image}" >>"${log_file}" 2>&1 && return 0
  [[ "${image}" == *.pkg.dev/* ]] || { tail -20 "${log_file}" >&2; die "could not push ${image}"; }
  warn "docker push failed (log: ${log_file#"${REPO_ROOT}/"}); pushing from a container instead"
  tar="$(mktemp "${TMPDIR:-/tmp}/dexaflow-image.XXXXXX")"
  docker save "${image}" -o "${tar}"
  printf '\033[2m$ crane push <image> %s\033[0m\n' "${image}" >&2
  if ! TOKEN="$(gcloud auth print-access-token)" docker run --rm -e TOKEN -v "${tar}:/image.tar:ro" \
      --entrypoint sh "${CRANE_IMAGE}" -c \
      'crane auth login "${0%%/*}" -u oauth2accesstoken -p "${TOKEN}" >/dev/null && crane push /image.tar "$0"' \
      "${image}" >>"${log_file}" 2>&1; then
    rm -f "${tar}"; tail -20 "${log_file}" >&2; die "could not push ${image}; run the same command again"
  fi
  rm -f "${tar}"
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
  local image="${REGISTRY}/${id}:${tag}" build_log="${REPO_ROOT}/.out/build-${id}.log"
  local version
  version="$(git -C "${dir}" describe --always --dirty 2>/dev/null || echo dev)-${tag}"
  if [[ "${DEXAFLOW_BUILDER:-docker}" == "cloudbuild" ]]; then
    # GKE: `dexaflow deploy` builds only what changed, with no local Docker.
    # Unchanged DAG: nothing is built. Only dag.py or sql/ changed: the code is
    # pushed as one layer on the cached dependency image, in seconds. New
    # dependencies: Cloud Build (the remote builder gke-deploy configures on
    # the cluster) builds the dependency image once.
    slow "Deploying: seconds when only the code changed, 1 to 3 minutes for new dependencies (log: .out/build-${id}.log)"
    # The token comes from DEXAFLOW_TOKEN (exported above), never the command
    # line, which run prints on screen and into the log.
    run dexaflow deploy "${dir}" --server "${SERVER}" \
        --registry "${REGISTRY}" --yes >"${build_log}" 2>&1 \
      || { tail -30 "${build_log}" >&2; die "deploying ${id} failed; the error is above (full log: .out/build-${id}.log)"; }
    grep -E '^(builder|Deployed|already)' "${build_log}" >&2 || true
    ok "${id} deployed: ${SERVER}/dags/${id}"
    return 0
  else
    # Docker's layer-by-layer progress goes to a log; it is shown only on failure.
    slow "Compiling and building the image: up to 2 minutes the first time (log: .out/build-${id}.log)"
    run dexaflow compile "${dir}" --image "${image}" --build --dag-version "${version}" \
        -o "${REPO_ROOT}/.out/dags/${id}.json" >"${build_log}" 2>&1 \
      || { tail -40 "${build_log}" >&2; die "compiling ${id} failed; the error is above (full log: .out/build-${id}.log)"; }
    push_image "${image}" "${build_log}"
  fi
  run dexaflow push "${REPO_ROOT}/.out/dags/${id}.json" --server "${SERVER}"
  ok "${id} deployed: ${SERVER}/dags/${id}"
}

TRIGGERED_RUNS=()

# trigger_dag starts one run of a DAG, then unpauses it. A DAG registered by
# `dexaflow push` can already be unpaused, and then the scheduler may have
# started its own run of the latest interval; with max_active_runs=1 our run is
# refused (409). In that case wait_for_runs waits for the scheduler's run.
trigger_dag() {
  local id="$1" run_id body code
  body="$(curl -sS -w '\n%{http_code}' -X POST "${SERVER}/api/v2/dags/${id}/dagRuns" \
    -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" -H 'Content-Type: application/json' \
    -d '{"logical_date": null}')"
  code="${body##*$'\n'}"
  if [[ "${code}" == 2* ]]; then
    run_id="$(sed -n 's/.*"dag_run_id": *"\([^"]*\)".*/\1/p' <<<"${body}")"
    log "${id}: run ${run_id} started"
  elif [[ "${code}" == 409 ]]; then
    run_id="$(curl -fsS "${SERVER}/api/v2/dags/${id}/dagRuns?state=queued&state=running&order_by=-run_after&limit=1" \
      -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" | sed -n 's/.*"dag_run_id": *"\([^"]*\)".*/\1/p' | head -1)"
    [[ -n "${run_id}" ]] || die "${id}: the server refused a new run (409) and no run is active: ${body%$'\n'*}"
    log "${id}: a scheduled run is already active (${run_id}); waiting for it instead"
  else
    die "${id}: starting a run failed (HTTP ${code}): ${body%$'\n'*}"
  fi
  curl -fsS -X PATCH "${SERVER}/api/v2/dags/${id}" -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" \
    -H 'Content-Type: application/json' -d '{"is_paused": false}' >/dev/null
  TRIGGERED_RUNS+=("${id} ${run_id}")
}

# wait_for_runs polls every triggered run until it finishes, prints a summary
# and fails when any run failed. WAIT=0 skips it.
wait_for_runs() {
  [[ "${WAIT:-1}" == "1" && ${#TRIGGERED_RUNS[@]} -gt 0 ]] || return 0
  log "Waiting for ${#TRIGGERED_RUNS[@]} run(s) to finish (WAIT=0 to skip; Ctrl+C stops waiting, not the run)"
  log "Follow them in the UI: ${SERVER}/dags"
  local entry id run_id state failed=0 start=${SECONDS} beat=${SECONDS} deadline=$((SECONDS + ${WAIT_TIMEOUT:-1800}))
  for entry in "${TRIGGERED_RUNS[@]}"; do
    read -r id run_id <<<"${entry}"
    while :; do
      state="$(curl -fsS "${SERVER}/api/v2/dags/${id}/dagRuns/${run_id}" \
        -H "Authorization: Bearer ${DEXAFLOW_TOKEN}" | sed -n 's/.*"state": *"\([^"]*\)".*/\1/p')"
      [[ "${state}" == "success" || "${state}" == "failed" ]] && break
      (( SECONDS < deadline )) || { state="timeout"; break; }
      sleep 10
      # A heartbeat every 30 seconds, so a long run never looks like a frozen terminal.
      if (( SECONDS - beat >= 30 )); then
        beat=${SECONDS}
        printf '   ... %s is %s (%dm%02ds)\n' "${id}" "${state:-queued}" \
          $(((SECONDS - start) / 60)) $(((SECONDS - start) % 60))
      fi
    done
    if [[ "${state}" == "success" ]]; then
      printf '  \033[1;32m%-8s %s\033[0m\n' "${state}" "${id}"
    else
      printf '  \033[1;31m%-8s %s\033[0m  %s/dags/%s/runs/%s\n' "${state}" "${id}" "${SERVER}" "${id}" "${run_id}"
      failed=1
    fi
  done
  [[ "${failed}" == "0" ]] || die "some runs did not succeed; open the links above for the task logs"
}

mkdir -p "${REPO_ROOT}/.out/dags"
