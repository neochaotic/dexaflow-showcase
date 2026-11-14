#!/usr/bin/env bash
# Print how to open and sign in to the GKE demo: the UI address (the Web
# Preview link in Cloud Shell), the user and the password. The password comes
# from the cluster, so it is right even in a clone that kept the files of an
# older cluster; it shows on this terminal only.
source "$(dirname "$0")/lib-gke.sh"
# Best effort: refresh the local copy from the cluster, if it is reachable.
sync_secrets || true
[[ -f "${GKE_SECRETS}" ]] || die "no credentials yet: run 'make gke-deploy' first"
PASSWORD="$(sed -n 's/^  password: //p' "${GKE_SECRETS}")"
URL="http://localhost:${GKE_UI_PORT}"
if [[ -n "${CLOUD_SHELL:-}" ]]; then
  URL="$(cloudshell get-web-preview-url -p "${GKE_UI_PORT}" 2>/dev/null || echo "Web Preview > Change port > ${GKE_UI_PORT}")"
fi
B=$'\033[1m' R=$'\033[0m'
cat <<INFO
  open      ${B}${URL}${R}   (needs make gke-ui running)
  user      ${B}${ADMIN_EMAIL}${R}
  password  ${B}${PASSWORD}${R}
  project   ${GCP_PROJECT}
  cluster   ${GKE_CLUSTER} (${GKE_ZONE})
  images    ${AR_HOST}/${GCP_PROJECT}/${AR_REPO}
INFO
