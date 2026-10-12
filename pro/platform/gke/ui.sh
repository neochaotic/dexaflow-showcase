#!/usr/bin/env bash
# Forward the GKE UI to localhost in the background, reconnecting when the
# connection drops, so the terminal stays free. `ui.sh stop` ends it.
source "$(dirname "$0")/../../scripts/lib.sh"
need kubectl; need curl
PID_FILE="${REPO_ROOT}/.out/gke-ui.pid"
LOG_FILE="${REPO_ROOT}/.out/gke-ui.log"
URL="http://localhost:${GKE_UI_PORT}"
mkdir -p "${REPO_ROOT}/.out"

running() { [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; }

if [[ "${1:-start}" == "stop" ]]; then
  if running; then
    pid="$(cat "${PID_FILE}")"
    pkill -P "${pid}" 2>/dev/null || true
    kill "${pid}" 2>/dev/null || true
    log "Stopped the UI port-forward"
  else
    log "The UI port-forward is not running"
  fi
  rm -f "${PID_FILE}"
  exit 0
fi

if running; then
  log "The UI port-forward is already running"
else
  # A loop, because kubectl port-forward exits when a connection breaks.
  nohup bash -c "while :; do kubectl -n '${NAMESPACE}' port-forward 'svc/${RELEASE}' '${GKE_UI_PORT}:8080'; sleep 2; done" \
    >"${LOG_FILE}" 2>&1 &
  echo $! > "${PID_FILE}"
  for _ in $(seq 1 30); do
    curl -fsS "${URL}/readyz" >/dev/null 2>&1 && break
    sleep 1
  done
  if ! curl -fsS "${URL}/readyz" >/dev/null 2>&1; then
    pkill -P "$(cat "${PID_FILE}")" 2>/dev/null || true
    kill "$(cat "${PID_FILE}")" 2>/dev/null || true
    rm -f "${PID_FILE}"
    die "the UI did not answer on ${URL}; see .out/gke-ui.log (is 'make gke-deploy' done?)"
  fi
fi
log "UI on ${URL} (runs in the background; stop it with: make gke-ui-stop)"
if [[ -n "${CLOUD_SHELL:-}" ]]; then
  log "Cloud Shell: Web Preview > Change port > ${GKE_UI_PORT} (not the default 8080)"
fi
log "Sign-in details: make gke-info"
