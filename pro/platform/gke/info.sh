#!/usr/bin/env bash
# Print where the GKE demo lives and how to sign in. The password itself stays
# in .out/gke-secrets.yaml (gitignored) and is never printed.
source "$(dirname "$0")/lib-gke.sh"
[[ -f "${GKE_SECRETS}" ]] || die "no credentials yet: run 'make gke-deploy' first"
B=$'\033[1m' R=$'\033[0m'
cat <<INFO
  UI        ${B}http://localhost:${GKE_UI_PORT}${R}   (start it with: make gke-ui)
  user      ${B}${ADMIN_EMAIL}${R}
  password  run: ${B}grep -A1 '^bootstrap:' .out/gke-secrets.yaml${R}
  project   ${GCP_PROJECT}
  cluster   ${GKE_CLUSTER} (${GKE_ZONE})
  images    ${AR_HOST}/${GCP_PROJECT}/${AR_REPO}
INFO
