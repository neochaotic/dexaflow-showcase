#!/usr/bin/env bash
# Report which required and optional tools are installed.
source "$(dirname "$0")/lib.sh"

missing=0
check() {
  local tool="$1" why="$2"
  if command -v "${tool}" >/dev/null 2>&1; then
    printf '  \033[32mok\033[0m       %-12s %s\n' "${tool}" "${why}"
  else
    printf '  \033[31mmissing\033[0m  %-12s %s\n' "${tool}" "${why}"
    missing=1
  fi
}

log "Required for the dry run"
check dexaflow "Dexaflow CLI (validate, compile, push)"
check helm     "renders and installs the Dexaflow Pro chart"
log "Required for the local cluster"
check docker   "builds DAG images and runs k3d"
if command -v k3d >/dev/null 2>&1; then
  check k3d "local Kubernetes cluster"
else
  printf '  \033[2mskip\033[0m     %-12s %s\n' "k3d" "only for the local cluster path; not needed on GKE"
fi
check kubectl  "talks to the cluster"
check curl     "health checks and API calls"
log "Required for GKE"
check gcloud      "creates the cluster, registry and service accounts"
check gke-gcloud-auth-plugin "lets kubectl talk to GKE"
check bq          "used by make gke-down to delete the BigQuery datasets"
if command -v gcloud >/dev/null 2>&1; then
  account="$(gcloud config get-value account 2>/dev/null)"
  if [[ -n "${account}" ]]; then
    printf '  \033[32mok\033[0m       %-12s %s\n' "account" "gcloud signed in as ${account}"
  else
    printf '  \033[33mcheck\033[0m    %-12s %s\n' "account" "run: gcloud auth login"
  fi
fi
log "Optional"
if command -v kubeconform >/dev/null 2>&1; then
  printf '  \033[32mok\033[0m       %-12s %s\n' "kubeconform" "schema-checks the rendered manifests in the dry run"
else
  printf '  \033[2mskip\033[0m     %-12s %s\n' "kubeconform" "optional: schema-checks the rendered manifests in the dry run"
fi

if [[ "${missing}" -ne 0 ]]; then
  warn "some tools are missing; docs/prerequisites.md says how to install them"
fi
