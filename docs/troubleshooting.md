# Troubleshooting

**`invalid credentials` when signing in.** The bootstrap admin signs in with
the email `admin@dexaflow.local`, not `admin`. Installs made before Dexaflow
0.5.7 keep `admin@leoflow.local`.

**`docker push` to `k3d-showcase-registry.localhost:5050` fails to resolve.**
Some systems do not resolve `*.localhost`. Add
`127.0.0.1 k3d-showcase-registry.localhost` to `/etc/hosts`.

**Task pod stuck in `ImagePullBackOff` on GKE.** The node service account needs
`roles/artifactregistry.reader` on the repository; `make gke-up` grants it.
Check with `kubectl -n dexaflow describe pod <pod>`.

**BigQuery `403 Access Denied`.** Check the Workload Identity chain:
`kubectl -n dexaflow get sa dexaflow-task -o yaml` must carry the
`iam.gke.io/gcp-service-account` annotation, and the Google service account must
have `roles/iam.workloadIdentityUser` for `<project>.svc.id.goog[dexaflow/dexaflow-task]`.

**A DAG shows up as an import error.** Run `make dry-run`: it compiles every
DAG with the real parser and prints the Python error.
