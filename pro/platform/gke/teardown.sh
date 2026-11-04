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

# Delete the namespace first, so GKE deletes the persistent disks behind the
# chart's volumes; deleting only the cluster leaves those disks billing. GKE can
# still be releasing a disk when the cluster goes, so note their names first and
# delete any that are left once the cluster is gone.
disks=""
if gcloud container clusters get-credentials "${GKE_CLUSTER}" --zone "${GKE_ZONE}" \
    --project "${GCP_PROJECT}" >/dev/null 2>&1; then
  disks="$(kubectl get pv -o jsonpath="{range .items[?(@.spec.claimRef.namespace=='${NAMESPACE}')]}{.spec.csi.volumeHandle}{'\n'}{end}" 2>/dev/null \
    | sed -n 's|.*/disks/||p')"
  log "Deleting namespace ${NAMESPACE} and its volumes"
  run kubectl delete namespace "${NAMESPACE}" --ignore-not-found --wait --timeout=5m || true
fi
slow "Deleting the cluster takes about 5 minutes"
run gcloud container clusters delete "${GKE_CLUSTER}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" --quiet || true
for disk in ${disks}; do
  if gcloud compute disks describe "${disk}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" >/dev/null 2>&1; then
    run gcloud compute disks delete "${disk}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}" --quiet \
      || warn "disk ${disk} is still there and still billing; delete it in the console under Compute Engine > Disks"
  fi
done
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
# gcloud builds submit keeps the uploaded DAG sources in a bucket it shares
# with every other Cloud Build user of the project, so it is only listed here.
if gcloud storage buckets describe "gs://${GCP_PROJECT}_cloudbuild" >/dev/null 2>&1; then
  next "Cloud Build kept the DAG sources (a few KB) in gs://${GCP_PROJECT}_cloudbuild. If nothing else in the project uses Cloud Build: gcloud storage rm -r gs://${GCP_PROJECT}_cloudbuild"
fi
