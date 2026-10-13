#!/usr/bin/env bash
# Empty the Dexaflow database on the GKE demo cluster: every registered DAG,
# run, Variable and connection goes; the cluster, the admin login, the images
# and the BigQuery data stay. Use it for a clean start of the lab.
source "$(dirname "$0")/lib-gke.sh"
need kubectl; need helm

echo "This empties the Dexaflow database of cluster ${GKE_CLUSTER} in ${GCP_PROJECT}:"
echo "  every DAG, run, Variable and connection. The cluster, login and BigQuery data stay."
printf '\033[1mType the project id (%s) and press Enter to confirm: \033[0m' "${GCP_PROJECT}"
read -r answer
[[ "${answer}" == "${GCP_PROJECT}" ]] || die "not confirmed, nothing changed"

run gcloud container clusters get-credentials "${GKE_CLUSTER}" --zone "${GKE_ZONE}" --project "${GCP_PROJECT}"
# Postgres keeps its data on the postgres-data volume: delete it for an empty
# database. deploy.sh below recreates it.
log "Deleting the Postgres data volume and restarting Redis"
run kubectl -n "${NAMESPACE}" scale deploy/postgres --replicas 0
run kubectl -n "${NAMESPACE}" wait --for=delete pod -l app=postgres --timeout=180s || true
run kubectl -n "${NAMESPACE}" delete pvc postgres-data --ignore-not-found --wait
run kubectl -n "${NAMESPACE}" rollout restart deploy/redis

log "Recreating the schema and the admin login"
bash "$(dirname "$0")/deploy.sh"   # helm upgrade runs the migration job again
cp="$(kubectl -n "${NAMESPACE}" get deploy -l "app.kubernetes.io/instance=${RELEASE}" -o name)"
[[ -n "${cp}" ]] || die "no Dexaflow deployment found for release ${RELEASE}"
for d in ${cp}; do
  run kubectl -n "${NAMESPACE}" rollout restart "${d}"
  run kubectl -n "${NAMESPACE}" rollout status "${d}" --timeout=300s
done

log "Removing finished task pods"
run kubectl -n "${NAMESPACE}" delete pod --field-selector=status.phase==Succeeded --ignore-not-found >/dev/null
run kubectl -n "${NAMESPACE}" delete pod --field-selector=status.phase==Failed --ignore-not-found >/dev/null
ok "Dexaflow is empty. If 'make gke-ui' was running it reconnects by itself."
