#!/usr/bin/env bash
# GKE settings, derived from versions.env and the active gcloud project.
source "$(dirname "${BASH_SOURCE[0]}")/../../scripts/lib.sh"
need gcloud

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
