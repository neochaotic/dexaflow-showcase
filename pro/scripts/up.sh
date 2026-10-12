#!/usr/bin/env bash
# Create the local k3d cluster with its registry, deploy throwaway Postgres and
# Redis, and install Dexaflow Pro from the published chart.
source "$(dirname "$0")/lib.sh"
need docker; need k3d; need kubectl; need helm; need curl

LOCAL="${REPO_ROOT}/pro/platform/local"

if k3d cluster get "${CLUSTER_NAME}" >/dev/null 2>&1; then
  log "Cluster ${CLUSTER_NAME} already exists, reusing it"
else
  log "Creating k3d cluster ${CLUSTER_NAME} with registry ${REGISTRY_NAME}:${REGISTRY_PORT}"
  run k3d cluster create "${CLUSTER_NAME}" \
    --image "${K3S_IMAGE}" \
    --agents 1 \
    --registry-create "${REGISTRY_NAME}:0.0.0.0:${REGISTRY_PORT}" \
    --port "${LOCAL_UI_PORT}:8080@loadbalancer" \
    --k3s-arg "--disable=traefik@server:0" \
    --wait
fi

run kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

log "Deploying throwaway Postgres and Redis (no persistence)"
sed -e "s|__POSTGRES_IMAGE__|${POSTGRES_IMAGE}|" -e "s|__REDIS_IMAGE__|${REDIS_IMAGE}|" -e "s|__PG_PASSWORD__|showcase|" \
  "${LOCAL}/datastores.yaml" | kubectl apply -n "${NAMESPACE}" -f -
run kubectl -n "${NAMESPACE}" rollout status deploy/postgres --timeout=180s
run kubectl -n "${NAMESPACE}" rollout status deploy/redis --timeout=120s

log "Installing Dexaflow Pro ${DEXAFLOW_VERSION}"
run helm upgrade --install "${RELEASE}" "${DEXAFLOW_CHART}" --version "${DEXAFLOW_VERSION}" \
  -n "${NAMESPACE}" \
  -f "${REPO_ROOT}/pro/platform/base/values.yaml" \
  -f "${LOCAL}/values-local.yaml" \
  --set taskNamespace="${NAMESPACE}" \
  --wait --timeout 5m

log "Waiting for http://localhost:${LOCAL_UI_PORT}/readyz"
for _ in $(seq 1 60); do
  curl -fsS "http://localhost:${LOCAL_UI_PORT}/readyz" >/dev/null 2>&1 && break
  sleep 2
done
curl -fsS "http://localhost:${LOCAL_UI_PORT}/readyz" >/dev/null \
  || die "the server never became ready; see docs/troubleshooting.md"

log "Dexaflow Pro is up: http://localhost:${LOCAL_UI_PORT}"
log "Sign in as ${ADMIN_EMAIL} / showcase-admin, then run: make demo"
