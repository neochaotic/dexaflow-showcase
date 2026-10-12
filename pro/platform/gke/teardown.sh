#!/usr/bin/env bash
# Delete every billable resource the GKE demo created.
source "$(dirname "$0")/lib-gke.sh"

echo "This deletes, in project ${GCP_PROJECT}:"
echo "  - GKE cluster ${GKE_CLUSTER} (${GKE_ZONE}) and everything in it"
echo "  - Artifact Registry repository ${AR_REPO} (${GKE_REGION})"
echo "  - BigQuery datasets ${BQ_DATASET} and ${LAB_DATASET}"
echo "  - service account ${TASK_GSA}"
printf '\033[1mType the project id (%s) and press Enter to confirm: \033[0m' "${GCP_PROJECT}"
read -r answer
[[ "${answer}" == "${GCP_PROJECT}" ]] || die "not confirmed, nothing deleted"

bash "$(dirname "$0")/ui.sh" stop

# Delete the namespace first, so GKE deletes the persistent disk behind the
# chart's log volume; deleting only the cluster leaves that disk billing.
if gcloud container clusters get-credentials "${GKE_CLUSTER}" --zone "${GKE_ZONE}" \
    --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  log "Deleting namespace ${NAMESPACE} and its volumes"
  run kubectl delete namespace "${NAMESPACE}" --ignore-not-found --wait --timeout=5m || true
fi
slow "Deleting the cluster takes about 5 minutes"
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
ok "GKE demo environment removed from ${GCP_PROJECT}"
