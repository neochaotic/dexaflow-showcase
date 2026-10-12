# Dexaflow Showcase

Runnable examples of [Dexaflow](https://github.com/dexadata/dexaflow), the
Airflow-compatible orchestrator with a Go control plane, the unmodified Airflow
3.2 UI and one container image per DAG.

Everything here is reproducible: clone it, run a few `make` targets, and you get
the same result as in the talks. The focus is **Dexaflow Pro** (Kubernetes,
installed with Helm). Examples for **Dexaflow Lite** (single host) will follow.

> Dexaflow is pre-1.0. This repository pins the version it was tested with in
> [`versions.env`](versions.env).

> **New here?** Follow the [hands-on lab](LAB.md): copy-and-paste
> steps from an empty Google Cloud project to Dexaflow Pro on GKE, your own
> DAGs and two BigQuery pipelines, in about an hour.

## Pick your path

| Path | You need | You get |
|---|---|---|
| [Dry run](docs/dry-run.md) | `dexaflow` CLI, `helm` | Every DAG compiled and every Kubernetes manifest rendered, no cluster. |
| [Local quickstart](docs/quickstart-local.md) | Docker, `k3d`, `kubectl`, `helm` | Dexaflow Pro on a local cluster, running the use cases. |
| [GKE lab](LAB.md) | A GCP project with billing | Step by step: Dexaflow Pro on GKE, your own DAGs, the BigQuery use cases and labs. |

## Quickstart

```bash
git clone https://github.com/neochaotic/dexaflow-showcase.git
cd dexaflow-showcase
make doctor     # checks the tools you need
make dry-run    # compiles every DAG and renders the chart, no cluster
make up         # local k3d cluster + Dexaflow Pro
make demo       # builds, registers and triggers the use cases
```

Open <http://localhost:8080> and sign in as `admin@leoflow.local` with password
`showcase-admin`. `make down` removes everything.

## Use cases

Every use case is a plain Airflow 3 DAG (`dag.py`) plus its Dexaflow build
config (`dexaflow.yaml`). No Dockerfile: Dexaflow generates one per DAG.

| # | Use case | What it shows | Runs on |
|---|---|---|---|
| 01 | [Hello pipeline](use-cases/01-hello-pipeline/) | Airflow UI, pod-per-task, XCom | local, GKE |
| 02 | [Dependency isolation](use-cases/02-dependency-isolation/) | pandas 1.x and 2.x side by side | local, GKE |
| 03 | [Fan out](use-cases/03-fan-out/) | parallel pods, autoscaling | local, GKE |
| 04 | [BigQuery report](use-cases/04-gcp-bigquery-report/) | stock Airflow BigQuery operators, keyless | GKE |
| 05 | [BigQuery from Python](use-cases/05-gcp-bigquery-python/) | `google-cloud-bigquery` client, keyless | GKE |

Run one with `make demo USE_CASE=03-fan-out`.

## Create and edit DAGs

Dexaflow keeps the Airflow authoring loop. Edit a `dag.py`, then deploy that one DAG:

```bash
make workspace                            # your own DAG folder (and git repo) next to this clone
cd ../dexaflow-workspace
make new NAME=my_first_dag                # scaffolds dags/my_first_dag
make deploy DAG=dags/my_first_dag         # build, push, register (TRIGGER=1 to also run it)
```

The workspace deploys to GKE when this clone has a GKE environment, else to the local cluster; `make deploy TARGET=local ...` or `TARGET=gke` chooses. Inside this repo, `make new-dag` and `make deploy` still work on `my-dags/`.

## Labs

| Lab | What you build | Runs on |
|---|---|---|
| [BigQuery](labs/bigquery/) | a daily ELT and data quality checks on a public e-commerce dataset | GKE (your own GCP project) |
| [Medallion](labs/medallion/) | millions of synthetic events generated with DuckDB in parallel pods, then bronze, silver and gold layers in BigQuery | GKE (your own GCP project) |

## Repository layout

```
versions.env        pinned versions and names, read by every script
pro/platform/       Helm values: base, local (k3d) and gke
pro/scripts/        doctor, dry-run, up, demo, down
use-cases/          the demo DAGs, shared by every environment
labs/               hands-on labs (BigQuery)
my-dags/            your own DAGs, created with make new-dag
lite/               Dexaflow Lite examples (coming later)
docs/               guides, presenter runbook, troubleshooting
```

## Presenting

[docs/presenter-runbook.md](docs/presenter-runbook.md) is the script for a live
demo: what to prepare, the order of the use cases, what to show in the UI and
what to do when the network fails.

## License

[Apache 2.0](LICENSE).
