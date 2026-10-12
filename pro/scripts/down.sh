#!/usr/bin/env bash
# Delete the local cluster, its registry and everything deployed on it.
source "$(dirname "$0")/lib.sh"
need k3d
run k3d cluster delete "${CLUSTER_NAME}"
run k3d registry delete "${REGISTRY_NAME}" 2>/dev/null || true
rm -rf "${REPO_ROOT}/.out"
log "Local environment removed"
