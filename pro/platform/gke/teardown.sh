#!/usr/bin/env bash
# Delete every billable resource the GKE demo created.
source "$(dirname "$0")/lib-gke.sh"

echo "This deletes, in project ${GCP_PROJECT}:"
echo "  - GKE cluster ${GKE_CLUSTER} (${GKE_ZONE}) and everything in it"
echo "  - Artifact Registry repository ${AR_REPO} (${GKE_REGION})"
echo "  - BigQuery datasets ${BQ_DATASET} and ${LAB_DATASET}"
echo "  - service account ${TASK_GSA}"
read -r -p "Type the project id to confirm: " answer
[[ "${answer}" == "${GCP_PROJECT}" ]] || die "aborted"

run gcloud container clusters delete "${GKE_CLUSTER}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" --quiet || true
run gcloud artifacts repositories delete "${AR_REPO}" --location "${GKE_REGION}" --project "${GCP_PROJECT}" --quiet || true
for ds in "${BQ_DATASET}" "${LAB_DATASET}"; do
  run bq --project_id "${GCP_PROJECT}" rm -r -f -d "${GCP_PROJECT}:${ds}" 2>/dev/null || true
done
for role in roles/bigquery.jobUser roles/bigquery.dataEditor; do
  run gcloud projects remove-iam-policy-binding "${GCP_PROJECT}" --condition None \
    --member "serviceAccount:${TASK_GSA}" --role "${role}" >/dev/null 2>&1 || true
done
run gcloud iam service-accounts delete "${TASK_GSA}" --project "${GCP_PROJECT}" --quiet || true
rm -f "${GKE_ENV}" "${GKE_SECRETS}"
log "GKE demo environment removed"
