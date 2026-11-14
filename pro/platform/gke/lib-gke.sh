#!/usr/bin/env bash
# The settings below are read by the scripts that source this file.
# shellcheck disable=SC2034
# GKE settings, derived from versions.env and the active gcloud project.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
need gcloud
# Never let gcloud wait on a yes/no question: some calls hide their output.
export CLOUDSDK_CORE_DISABLE_PROMPTS=1

GCP_PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null)}"
[[ -n "${GCP_PROJECT}" ]] || die "no GCP project: run 'gcloud config set project <id>' or set GCP_PROJECT"
GKE_CLUSTER="${CLUSTER:-${GKE_CLUSTER}}"
GKE_REGION="${REGION:-${GKE_REGION}}"
GKE_ZONE="${ZONE:-${GKE_ZONE}}"
AR_REPO="dexaflow-showcase"
AR_HOST="${GKE_REGION}-docker.pkg.dev"
TASK_GSA="dexaflow-tasks@${GCP_PROJECT}.iam.gserviceaccount.com"
GKE_ENV="${REPO_ROOT}/.out/gke.env"
GKE_SECRETS="${REPO_ROOT}/.out/gke-secrets.yaml"
mkdir -p "${REPO_ROOT}/.out"
CREDS_SECRET=showcase-credentials

# The Secret showcase-credentials on the cluster is the source of truth for the
# login and the database password. sync_secrets copies it over
# .out/gke-secrets.yaml and the password in .out/gke.env, so a clone that kept
# the files of an older cluster (a Cloud Shell reused across labs) signs in
# with the current password. Returns 1 when the cluster has no such Secret.
sync_secrets() {
  local current
  current="$(kubectl --request-timeout=5s -n "${NAMESPACE}" get secret "${CREDS_SECRET}" \
    -o jsonpath='{.data.values\.yaml}' 2>/dev/null | base64 --decode)" || return 1
  [[ -n "${current}" ]] || return 1
  if [[ -f "${GKE_SECRETS}" ]] && [[ "$(cat "${GKE_SECRETS}")" != "${current}" ]]; then
    warn "This clone had the credentials of an older cluster; using the current ones"
  fi
  (umask 077; printf '%s\n' "${current}" > "${GKE_SECRETS}")
  if [[ -f "${GKE_ENV}" ]]; then
    { grep -v '^DEXAFLOW_PASSWORD=' "${GKE_ENV}" || true
      echo "DEXAFLOW_PASSWORD=$(sed -n 's/^  password: //p' "${GKE_SECRETS}")"; } > "${GKE_ENV}.tmp"
    mv "${GKE_ENV}.tmp" "${GKE_ENV}"
  fi
}
