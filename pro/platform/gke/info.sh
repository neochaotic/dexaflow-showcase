#!/usr/bin/env bash
# Print where the GKE demo lives and how to sign in. The password itself stays
# in .out/gke-secrets.yaml (gitignored) and is never printed.
source "$(dirname "$0")/lib-gke.sh"
[[ -f "${GKE_SECRETS}" ]] || die "no credentials yet: run 'make gke-deploy' first"
cat <<INFO
  UI        http://localhost:${GKE_UI_PORT}   (keep 'make gke-ui' running)
  user      ${ADMIN_EMAIL}
  password  the 'bootstrap.password' value in .out/gke-secrets.yaml
  project   ${GCP_PROJECT}
  cluster   ${GKE_CLUSTER} (${GKE_ZONE})
  images    ${AR_HOST}/${GCP_PROJECT}/${AR_REPO}
INFO
