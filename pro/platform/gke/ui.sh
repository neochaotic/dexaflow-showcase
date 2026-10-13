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
answers() { curl -fsS -m 5 "${URL}/readyz" >/dev/null 2>&1; }
stop() {
  if running; then
    pid="$(cat "${PID_FILE}")"
    pkill -P "${pid}" 2>/dev/null || true
    kill "${pid}" 2>/dev/null || true
  fi
  rm -f "${PID_FILE}"
}

if [[ "${1:-start}" == "stop" ]]; then
  if running; then stop; ok "Stopped the UI port-forward"; else stop; log "The UI port-forward is not running"; fi
  exit 0
fi

if running && ! answers; then
  warn "The UI port-forward is running but not answering; restarting it"
  stop
fi
if running; then
  log "The UI port-forward is already running"
else
  # kubectl port-forward exits when a connection breaks, and can also hang
  # after a pod restarts. The loop restarts it; the watchdog kills it when
  # the UI stops answering three checks in a row.
  nohup bash -c "
    while :; do
      kubectl -n '${NAMESPACE}' port-forward 'svc/${RELEASE}' '${GKE_UI_PORT}:8080' & pf=\$!
      sleep 5; misses=0
      while kill -0 \$pf 2>/dev/null; do
        if curl -fsS -m 5 '${URL}/readyz' >/dev/null 2>&1; then misses=0; else misses=\$((misses + 1)); fi
        [ \$misses -lt 3 ] || { echo 'UI not answering; restarting port-forward'; kill \$pf; }
        sleep 10
      done
      wait \$pf 2>/dev/null; sleep 2
    done" >"${LOG_FILE}" 2>&1 &
  echo $! > "${PID_FILE}"
  for _ in $(seq 1 30); do
    answers && break
    sleep 1
  done
  if ! answers; then
    stop
    die "the UI did not answer on ${URL}; see .out/gke-ui.log and 'kubectl -n ${NAMESPACE} get pods' (is 'make gke-deploy' done?)"
  fi
fi
ok "UI on ${URL}"
log "It runs in the background, so this terminal stays free (stop it with: make gke-ui-stop)"
if [[ -n "${CLOUD_SHELL:-}" ]]; then
  preview="$(cloudshell get-web-preview-url -p "${GKE_UI_PORT}" 2>/dev/null || true)"
  if [[ -n "${preview}" ]]; then
    next "Cloud Shell: open ${preview}"
  else
    next "Cloud Shell: Web Preview > Change port > ${GKE_UI_PORT} (not the default 8080)"
  fi
fi
next "make gke-info  (shows how to sign in)"
