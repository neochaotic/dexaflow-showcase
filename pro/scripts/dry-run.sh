#!/usr/bin/env bash
# The dry run: validate and compile every DAG, then render the Helm chart with
# the local and GKE values. Nothing is built, pushed or installed.
source "$(dirname "$0")/lib.sh"
need dexaflow
need helm

OUT="${REPO_ROOT}/.out/dry-run"
rm -rf "${OUT}" && mkdir -p "${OUT}/dags" "${OUT}/manifests"

log "Validating and compiling DAGs"
while read -r dir; do
  id="$(dag_id "${dir}")"
  # validate checks dexaflow.yaml; compile imports dag.py with the real parser.
  dexaflow validate "${dir}"
  dexaflow compile "${dir}" \
    --image "${REGISTRY_NAME}:${REGISTRY_PORT}/${id}:dry-run" \
    -o "${OUT}/dags/${id}.json"
  log "  ${id}: ok"
done < <(dag_dirs "${REPO_ROOT}/use-cases" "${REPO_ROOT}/labs")

log "Rendering the Dexaflow Pro chart ${DEXAFLOW_VERSION}"
render() {
  local env="$1"; shift
  helm template "${RELEASE}" "${DEXAFLOW_CHART}" --version "${DEXAFLOW_VERSION}" \
    -n "${NAMESPACE}" \
    -f "${REPO_ROOT}/pro/platform/base/values.yaml" "$@" \
    > "${OUT}/manifests/${env}.yaml"
  log "  ${env}: $(grep -c '^kind:' "${OUT}/manifests/${env}.yaml") objects"
}
render local -f "${REPO_ROOT}/pro/platform/local/values-local.yaml"
render gke   -f "${REPO_ROOT}/pro/platform/gke/values-gke.yaml" \
  --set database.url='postgres://dexaflow:dry-run@10.0.0.2:5432/dexaflow?sslmode=require' \
  --set redis.url='rediss://10.0.0.3:6378/0' \
  --set auth.jwtSecret=dry-run-jwt-secret-not-used-anywhere \
  --set secretKey=dry-run-secret-key-32-bytes-long \
  --set bootstrap.password=dry-run

if command -v kubeconform >/dev/null 2>&1; then
  log "Schema-checking the rendered manifests"
  kubeconform -strict -summary -ignore-missing-schemas "${OUT}/manifests/"*.yaml
else
  warn "kubeconform not installed, skipping the schema check"
fi

log "Dry run passed. Compiled DAGs and manifests are in .out/dry-run/"
