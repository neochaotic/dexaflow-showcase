#!/usr/bin/env bash
# Provision everything the GKE demo needs, idempotently:
#   1. the APIs (GKE, Artifact Registry, BigQuery)
#   2. an Artifact Registry repository for the DAG images
#   3. a GKE Standard zonal cluster on Spot nodes, with Workload Identity
#   4. a Google service account for task pods, allowed to run BigQuery jobs,
#      bound to the dexaflow-task Kubernetes ServiceAccount (no keys anywhere)
source "$(dirname "$0")/lib-gke.sh"
need kubectl; need docker

log "Project ${GCP_PROJECT}, cluster ${GKE_CLUSTER} in ${GKE_ZONE}"

log "Enabling APIs"
run gcloud services enable container.googleapis.com artifactregistry.googleapis.com \
  bigquery.googleapis.com iam.googleapis.com --project "${GCP_PROJECT}"

if ! gcloud artifacts repositories describe "${AR_REPO}" --location "${GKE_REGION}" \
    --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  log "Creating Artifact Registry repository ${AR_REPO}"
  run gcloud artifacts repositories create "${AR_REPO}" --repository-format docker \
    --location "${GKE_REGION}" --project "${GCP_PROJECT}" \
    --description "DAG images for dexaflow-showcase"
fi
run gcloud auth configure-docker "${AR_HOST}" --quiet

if ! gcloud container clusters describe "${GKE_CLUSTER}" --zone "${GKE_ZONE}" \
    --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  log "Creating GKE cluster ${GKE_CLUSTER} (this is the slow step)"
  run gcloud container clusters create "${GKE_CLUSTER}" \
    --project "${GCP_PROJECT}" --zone "${GKE_ZONE}" \
    --release-channel regular \
    --machine-type "${GKE_MACHINE_TYPE}" --spot \
    --num-nodes 1 --enable-autoscaling --min-nodes 1 --max-nodes "${GKE_MAX_NODES}" \
    --disk-type pd-standard --disk-size 50 \
    --workload-pool "${GCP_PROJECT}.svc.id.goog" \
    --enable-dataplane-v2
fi
run gcloud container clusters get-credentials "${GKE_CLUSTER}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}"

log "Letting the nodes pull DAG images from Artifact Registry"
NODE_SA="$(gcloud container clusters describe "${GKE_CLUSTER}" --zone "${GKE_ZONE}" \
  --project "${GCP_PROJECT}" --format 'value(nodeConfig.serviceAccount)')"
if [[ "${NODE_SA}" == "default" ]]; then
  NUM="$(gcloud projects describe "${GCP_PROJECT}" --format 'value(projectNumber)')"
  NODE_SA="${NUM}-compute@developer.gserviceaccount.com"
fi
run gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" --location "${GKE_REGION}" \
  --project "${GCP_PROJECT}" --member "serviceAccount:${NODE_SA}" \
  --role roles/artifactregistry.reader --condition None >/dev/null

if ! gcloud iam service-accounts describe "${TASK_GSA}" --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  log "Creating the task service account ${TASK_GSA}"
  run gcloud iam service-accounts create dexaflow-tasks --project "${GCP_PROJECT}" \
    --display-name "dexaflow-showcase task pods"
fi
log "Granting BigQuery job and data access to the task service account"
for role in roles/bigquery.jobUser roles/bigquery.dataEditor; do
  run gcloud projects add-iam-policy-binding "${GCP_PROJECT}" --condition None \
    --member "serviceAccount:${TASK_GSA}" --role "${role}" >/dev/null
done
log "Binding it to the dexaflow-task Kubernetes ServiceAccount (Workload Identity)"
run gcloud iam service-accounts add-iam-policy-binding "${TASK_GSA}" --project "${GCP_PROJECT}" \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:${GCP_PROJECT}.svc.id.goog[${NAMESPACE}/dexaflow-task]" >/dev/null

cat > "${GKE_ENV}" <<ENV
# Written by pro/platform/gke/provision.sh. Read by demo.sh with DEXAFLOW_TARGET=gke.
GCP_PROJECT=${GCP_PROJECT}
DEXAFLOW_REGISTRY=${AR_HOST}/${GCP_PROJECT}/${AR_REPO}
DEXAFLOW_SERVER=http://localhost:${GKE_UI_PORT}
ENV
log "Provisioned. Next: make gke-deploy"
