#!/usr/bin/env bash
# Provision everything the GKE demo needs, idempotently:
#   1. the APIs (GKE, Artifact Registry, BigQuery)
#   2. an Artifact Registry repository for the DAG images
#   3. a GKE Standard zonal cluster (regular nodes; GKE_SPOT=true for Spot),
#      with Workload Identity
#   4. a Google service account for task pods, allowed to run BigQuery jobs,
#      bound to the dexaflow-task Kubernetes ServiceAccount (no keys anywhere)
source "$(dirname "$0")/lib-gke.sh"
need kubectl; need docker

log "Project ${GCP_PROJECT}, cluster ${GKE_CLUSTER} in ${GKE_ZONE}"

log "Enabling APIs"
slow "Up to 2 minutes on a new project"
run gcloud services enable container.googleapis.com artifactregistry.googleapis.com \
  bigquery.googleapis.com iam.googleapis.com cloudbuild.googleapis.com --project "${GCP_PROJECT}"

if ! gcloud artifacts repositories describe "${AR_REPO}" --location "${GKE_REGION}" \
    --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  log "Creating Artifact Registry repository ${AR_REPO}"
  run gcloud artifacts repositories create "${AR_REPO}" --repository-format docker \
    --location "${GKE_REGION}" --project "${GCP_PROJECT}" \
    --description "DAG images for dexaflow-showcase"
fi
run gcloud auth configure-docker "${AR_HOST}" --quiet

SPOT_FLAG=()
[[ "${GKE_SPOT}" != "true" ]] || SPOT_FLAG=(--spot)
if ! gcloud container clusters describe "${GKE_CLUSTER}" --zone "${GKE_ZONE}" \
    --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  log "Creating GKE cluster ${GKE_CLUSTER}"
  slow "About 8 minutes. gcloud shows a spinner; wait for the next ==> line"
  run gcloud container clusters create "${GKE_CLUSTER}" \
    --project "${GCP_PROJECT}" --zone "${GKE_ZONE}" \
    --release-channel regular \
    --machine-type "${GKE_MACHINE_TYPE}" "${SPOT_FLAG[@]+"${SPOT_FLAG[@]}"}" \
    --num-nodes 1 --enable-autoscaling --min-nodes 1 --max-nodes "${GKE_MAX_NODES}" \
    --disk-type pd-standard --disk-size 50 \
    --workload-pool "${GCP_PROJECT}.svc.id.goog" \
    --enable-dataplane-v2
else
  warn "Cluster ${GKE_CLUSTER} already exists in ${GCP_PROJECT}: reusing it."
  warn "Whatever is deployed on it stays (DAGs, runs). For an empty Dexaflow: make gke-reset."
  # Clusters from before GKE_SPOT=false run on Spot: move them to regular nodes
  # (a new pool, then the Spot pool goes; Postgres keeps its data volume).
  if [[ "${GKE_SPOT}" != "true" ]] && [[ "$(gcloud container node-pools describe default-pool \
      --cluster "${GKE_CLUSTER}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" \
      --format 'value(config.spot)' 2>/dev/null)" == "True" ]]; then
    log "Moving the cluster from Spot to regular nodes"
    slow "About 5 minutes: a new node pool starts, then the Spot pool drains and goes"
    if ! gcloud container node-pools describe regular-pool --cluster "${GKE_CLUSTER}" \
        --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" >/dev/null 2>&1; then
      run gcloud container node-pools create regular-pool --cluster "${GKE_CLUSTER}" \
        --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" --machine-type "${GKE_MACHINE_TYPE}" \
        --num-nodes 1 --enable-autoscaling --min-nodes 1 --max-nodes "${GKE_MAX_NODES}" \
        --disk-type pd-standard --disk-size 50 --workload-metadata GKE_METADATA
    fi
    run gcloud container node-pools delete default-pool --cluster "${GKE_CLUSTER}" \
      --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" --quiet
  fi
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

# DAG images are built on Cloud Build (make deploy), not by a local Docker.
# Its default service account needs to push to the repository and write logs;
# projects created with automatic grants turned off do not give it that.
BUILD_SA="$(gcloud builds get-default-service-account --project "${GCP_PROJECT}" \
  --format 'value(serviceAccountEmail)' 2>/dev/null | sed 's|.*/||')"
if [[ -n "${BUILD_SA}" ]]; then
  log "Letting Cloud Build push DAG images (${BUILD_SA})"
  run gcloud artifacts repositories add-iam-policy-binding "${AR_REPO}" --location "${GKE_REGION}" \
    --project "${GCP_PROJECT}" --member "serviceAccount:${BUILD_SA}" \
    --role roles/artifactregistry.writer --condition None >/dev/null
  run gcloud projects add-iam-policy-binding "${GCP_PROJECT}" --condition None \
    --member "serviceAccount:${BUILD_SA}" --role roles/logging.logWriter >/dev/null
else
  warn "could not read the Cloud Build service account; image builds use its default permissions"
fi

# Keep the admin password that gke-deploy added, so re-running gke-up is safe.
password_line="$(grep '^DEXAFLOW_PASSWORD=' "${GKE_ENV}" 2>/dev/null || true)"
cat > "${GKE_ENV}" <<ENV
# Written by pro/platform/gke/provision.sh. Read by demo.sh with DEXAFLOW_TARGET=gke.
GCP_PROJECT=${GCP_PROJECT}
DEXAFLOW_REGISTRY=${AR_HOST}/${GCP_PROJECT}/${AR_REPO}
DEXAFLOW_SERVER=http://localhost:${GKE_UI_PORT}
DEXAFLOW_BUILDER=cloudbuild
GKE_REGION=${GKE_REGION}
ENV
[[ -z "${password_line}" ]] || echo "${password_line}" >> "${GKE_ENV}"
ok "GKE environment ready: cluster ${GKE_CLUSTER} in ${GCP_PROJECT}"
next "make gke-deploy"
