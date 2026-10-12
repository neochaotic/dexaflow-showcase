# GKE

> To set it up step by step, follow Part 1 of [the lab](../LAB.md#part-1-set-up-gke-and-dexaflow-pro).
> This page is the reference: what gets created, what it costs, and how production differs.

The presentation environment. Same chart, same DAGs, plus the BigQuery use
cases, authenticated with Workload Identity (no service account keys).

## Cost

A zonal GKE Standard cluster on Spot `e2-standard-2` nodes (2 vCPU, 8 GB), autoscaling 1 to 3,
an Artifact Registry repository and a few cheap BigQuery queries (each capped at
1 GB billed). Run `make gke-down` after the talk to stop all cost.

## Commands

```bash
gcloud auth login
gcloud config set project <your-project>

make gke-up       # APIs, Artifact Registry, cluster, Workload Identity
make gke-deploy   # Postgres, Redis and Dexaflow Pro on the cluster
make gke-ui       # UI on http://localhost:8081, in the background (make gke-ui-stop)
make gke-demo     # build, push, register and trigger every use case
make gke-info     # UI address, user, and where the password is
make gke-lab      # deploy both labs, run the BigQuery lab setup and one medallion day
```

`make gke-deploy` generates the admin password into `.out/gke-secrets.yaml`
(gitignored) and keeps a copy in the cluster as the Secret
`showcase-credentials`, so a second clone reuses it instead of resetting the
database. `make gke-info` shows the UI address, the user and where the password is.



## What `make gke-up` creates

| Resource | Name | Why |
|---|---|---|
| GKE Standard cluster, zonal, Spot | `dexaflow-showcase` | runs the control plane and the task pods |
| Artifact Registry repository | `dexaflow-showcase` | DAG images |
| Google service account | `dexaflow-tasks` | identity of task pods, with `bigquery.jobUser` and `bigquery.dataEditor` |
| Workload Identity binding | `dexaflow/dexaflow-task` | lets task pods act as `dexaflow-tasks` without a key |

Every name and region is a default in `versions.env`; override with environment
variables (`GCP_PROJECT`, `ZONE`, `REGION`, `CLUSTER`).

## Easy path versus production shape

`make gke-deploy` runs Postgres and Redis inside the cluster, which is enough
for a demo. For Cloud SQL and Memorystore, follow the upstream recipe
[`deploy/k8s`](https://github.com/dexadata/dexaflow/tree/main/deploy/k8s).

The UI is not exposed to the internet: `make gke-ui` port-forwards it. Before
exposing it, put it behind an Ingress with TLS and SSO.

## Tear down

`make gke-down` asks you to type the project id, then deletes the cluster, the
registry, the BigQuery dataset and the service account.
