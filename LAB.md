# Lab: Airflow DAGs on Dexaflow Pro and GKE

Copy, paste, run. Every task ends with a **Check your progress** command and
the result you should see.

| | |
|---|---|
| Time | about 60 minutes, most of it waiting for the cluster and the first image builds |
| Level | introductory; you know what an Airflow DAG is |
| Cost | one Spot `e2-standard-2` node, a small Artifact Registry repository and a few BigQuery jobs, each capped at 1 GB billed. Task 12 deletes everything. |

## Overview

[Dexaflow](https://github.com/dexadata/dexaflow) runs Airflow 3 DAGs with a Go
control plane, the unmodified Airflow 3.2 UI and one container image per DAG.
In this lab you install Dexaflow Pro on a small GKE cluster in your own
project, then write, deploy and change DAGs the way you would in Airflow,
including BigQuery pipelines that authenticate without any key.

### What you will do

- Create a GKE cluster and install Dexaflow Pro with Helm.
- Deploy a DAG, write your own, add a Python dependency and redeploy it.
- Run BigQuery jobs keylessly through Workload Identity.
- Run a daily ELT lab and a medallion lab that generates 4 million events with DuckDB.

## Setup and requirements

You need a Google Cloud project with billing enabled, and the **Owner** role on
it (or Editor plus Project IAM Admin). The lab creates everything it uses and
deletes it at the end.

### Option A: Cloud Shell

[Open Cloud Shell](https://shell.cloud.google.com/). It already has `gcloud`,
`kubectl`, `helm`, `docker`, `make` and `bq`, and is signed in as you. To open
the UI in Task 5 you will use **Web Preview > Change port > 8081**.

### Option B: your own terminal (macOS or Linux)

Install `gcloud` (with the `gke-gcloud-auth-plugin` and `bq` components),
`kubectl`, `helm` 3.16+, Docker and `make`. Then sign in:

```bash
gcloud auth login
gcloud components install gke-gcloud-auth-plugin bq   # skip if you installed them another way
```

## Task 1. Get the code and the Dexaflow CLI

```bash
git clone https://github.com/neochaotic/dexaflow-showcase.git
cd dexaflow-showcase
make cli
export PATH="$HOME/.dexaflow/bin:$PATH"
```

`make cli` installs the CLI version pinned in [`versions.env`](versions.env),
plus the small Python runtime it uses to read `dag.py` files.

**Check your progress**

```bash
dexaflow version
make doctor
```

`dexaflow version` prints the pinned version (`0.5.2`). `make doctor` shows
`ok` for `dexaflow`, `helm`, `docker`, `kubectl`, `curl`, `gcloud`,
`gke-gcloud-auth-plugin` and `bq`. (`k3d` is only for the local path; ignore it.)

## Task 2. Point the lab at your project

Replace `my-project-id` with your project id. Run these in every new terminal
you open for this lab.

```bash
cd dexaflow-showcase   # skip if you are already there
export GCP_PROJECT=my-project-id
export DEXAFLOW_TARGET=gke
export PATH="$HOME/.dexaflow/bin:$PATH"
gcloud config set project "$GCP_PROJECT"
```

`DEXAFLOW_TARGET=gke` makes `make deploy` send DAGs to the GKE environment
instead of a local cluster.

**Check your progress**

```bash
gcloud config get-value project
```

It prints your project id.

## Task 3. Create the GKE cluster

```bash
make gke-up
```

This enables the APIs, then creates:

| Resource | Name | Why |
|---|---|---|
| GKE Standard cluster, zonal, Spot nodes, 1 to 3 | `dexaflow-showcase` | runs the control plane and one pod per task |
| Artifact Registry repository | `dexaflow-showcase` | one image per DAG |
| Service account | `dexaflow-tasks` | identity of the task pods, with BigQuery job and data access |
| Workload Identity binding | `dexaflow/dexaflow-task` | task pods act as `dexaflow-tasks` with no key file |

Creating the cluster takes about 8 minutes. Every command the script runs is
printed with a `$` in front, so you can see exactly what it does. Running it
again is safe: it skips what already exists.

**Check your progress**

```bash
kubectl get nodes
```

One node with `STATUS` `Ready`.

## Task 4. Install Dexaflow Pro

```bash
make gke-deploy
```

This installs Postgres and Redis inside the cluster (enough for a demo; use
Cloud SQL and Memorystore in production), then the Dexaflow Pro Helm chart.
It generates the admin password into `.out/gke-secrets.yaml`, which git
ignores, and keeps a copy in the cluster so another clone can reuse it.

**Check your progress**

```bash
kubectl -n dexaflow get pods
```

The `dexaflow`, `postgres` and `redis` pods are `Running` and `1/1` ready.

## Task 5. Open the Airflow UI

The UI is not exposed to the internet. Open a **second terminal**, repeat
Task 2 there, then leave this running:

```bash
make gke-ui
```

Back in the first terminal:

```bash
make gke-info
```

It prints the address, the user (`admin@leoflow.local`) and where the password
is. Open `.out/gke-secrets.yaml` and copy the value of `password:` under
`bootstrap:`. Then open <http://localhost:8081> (in Cloud Shell: **Web Preview >
Change port > 8081**) and sign in.

**Check your progress**

```bash
curl -s http://localhost:8081/readyz && echo
```

It prints a ready response, and the browser shows the Airflow 3.2 UI with no
DAGs yet.

## Task 6. Deploy your first DAG

[`use-cases/01-hello-pipeline/dag.py`](use-cases/01-hello-pipeline/dag.py) is a
plain Airflow 3 DAG: three TaskFlow tasks passing data through XCom.

```bash
make deploy DAG=use-cases/01-hello-pipeline TRIGGER=1
```

For each DAG, `make deploy` runs the whole Dexaflow loop, printing each command:

1. `dexaflow compile ... --build --push`: reads `dag.py`, writes `dag.json`,
   builds an image with only this DAG's dependencies and pushes it to Artifact
   Registry. No Dockerfile to write.
2. `dexaflow push`: registers `dag.json` with the control plane. The DAG appears
   in the UI.
3. With `TRIGGER=1`, starts a run and waits for it.

**Check your progress**

The command ends with `success  showcase_hello_pipeline`. In the UI, open the
DAG, then the run: each task ran in its own pod. Click `load` and open **XCom**
to see the summary it returned.

## Task 7. Write your own DAG

Scaffold a new DAG project, then replace its `dag.py`:

```bash
make new-dag NAME=my_first_dag
cat > my-dags/my_first_dag/dag.py <<'EOF'
from airflow.sdk import DAG, task


@task
def greet() -> str:
    message = "hello from my first Dexaflow DAG"
    print(message)
    return message


with DAG("my_first_dag", schedule=None, catchup=False, tags=["lab"]):
    greet()
EOF
make deploy DAG=my-dags/my_first_dag TRIGGER=1
```

`my-dags/my_first_dag/dexaflow.yaml` is the build config: the DAG id, the
Python version and the dependencies, which are none for now.

**Check your progress**

The command ends with `success  my_first_dag`, and `my_first_dag` is in the UI
with one green run.

## Task 8. Add a dependency and a task, then redeploy

Add [Faker](https://faker.readthedocs.io/) as a dependency of this DAG only, and
a task that uses it:

```bash
cat > my-dags/my_first_dag/dexaflow.yaml <<'EOF'
schema_version: "1.0"
dag_id: my_first_dag
description: My first Dexaflow DAG.
python_version: "3.11"
dependencies:
  - faker==33.1.0
EOF
cat > my-dags/my_first_dag/dag.py <<'EOF'
from airflow.sdk import DAG, task


@task
def make_customers(count: int = 5) -> list[str]:
    from faker import Faker

    fake = Faker()
    names = [fake.name() for _ in range(count)]
    print(f"made {len(names)} customers")
    return names


@task
def greet(names: list[str]) -> int:
    for name in names:
        print(f"hello, {name}")
    return len(names)


with DAG("my_first_dag", schedule=None, catchup=False, tags=["lab"]):
    greet(make_customers())
EOF
make deploy DAG=my-dags/my_first_dag TRIGGER=1
```

The new image has Faker; no other DAG does. This is how Dexaflow avoids the
shared-environment dependency conflicts of a classic Airflow deployment. For
two DAGs pinning different pandas versions side by side, run
`make deploy DAG=use-cases/02-dependency-isolation TRIGGER=1`.

**Check your progress**

The command ends with `success  my_first_dag`. In the UI the DAG now has two
tasks, and the log of `greet` shows five generated names.

## Task 9. Query BigQuery without a key

[`use-cases/04-gcp-bigquery-report/dag.py`](use-cases/04-gcp-bigquery-report/dag.py)
uses the stock Airflow BigQuery operators. It never names your project: it
reads the `GCP_PROJECT` Variable.

```bash
make deploy DAG=use-cases/04-gcp-bigquery-report TRIGGER=1
```

Before deploying, `make deploy` creates the `google_cloud_default` connection
(with no key: the task pods use Workload Identity) and the `GCP_PROJECT` and
`LAB_DATASET` Variables. See them in the UI under **Admin > Connections** and
**Admin > Variables**. This first image build takes about 2 minutes because of
the Google provider.

**Check your progress**

```bash
bq query --use_legacy_sql=false --project_id="$GCP_PROJECT" \
  'SELECT COUNT(*) AS row_count FROM dexaflow_showcase.top_names_by_decade'
```

`row_count` is `60`: the top 5 US baby names in each of 12 decades.

## Task 10. Run the daily ELT lab

[`labs/bigquery`](labs/bigquery/README.md) copies four tables of the public
`thelook_ecommerce` dataset into your project, then builds a daily sales mart
from them and checks it.

```bash
make gke-lab
```

This deploys every lab DAG, then runs `lab_00_setup` (the copy) and one day of
the medallion lab (Task 11), and waits for both. Now run one day of the ELT and
its quality checks:

```bash
make deploy DAG=labs/bigquery/01-daily-sales TRIGGER=1
make deploy DAG=labs/bigquery/02-quality-checks TRIGGER=1
```

**Check your progress**

```bash
bq query --use_legacy_sql=false --project_id="$GCP_PROJECT" \
  'SELECT table_id, row_count FROM dexaflow_lab.__TABLES__ ORDER BY table_id'
```

You see `raw_orders`, `raw_order_items`, `raw_products` and `raw_users` with
thousands of rows each, plus `stg_order_lines` and `mart_daily_sales`. Both
runs ended with `success`.

To change where the lab writes, change the Variable, not the code: in the UI
open **Admin > Variables**, edit `LAB_DATASET`, and trigger the DAG again.
Variables are read at run time, so no redeploy is needed.

## Task 11. Generate 4 million events with DuckDB

[`labs/medallion`](labs/medallion/README.md) already ran in Task 10. Eight
`generate_shard` tasks ran as eight pods at once; each generated 500,000
synthetic e-commerce events with DuckDB and loaded them into BigQuery. SQL tasks
then refined them into bronze, silver and gold tables, and `quality_checks`
asserted the result.

In the UI, open `lab_medallion_daily` and look at the **Graph** and the
**Gantt** of its run.

**Check your progress**

```bash
bq query --use_legacy_sql=false --project_id="$GCP_PROJECT" \
  'SELECT table_id, row_count FROM dexaflow_lab.__TABLES__ WHERE table_id LIKE "bronze%" OR table_id LIKE "silver%" OR table_id LIKE "gold%" ORDER BY table_id'
```

`bronze_events` has `4000000` rows, `silver_events` a little fewer (duplicates
and bad rows removed), and the two `gold_*` tables a few rows each.

Want more volume? In the UI, choose **Trigger** on `lab_medallion_daily` and
set `rows_per_shard` to `2500000` for 20 million events. The exercises in each
lab's README go further.

## Task 12. Clean up

```bash
make gke-down
```

It asks you to type the project id, then deletes the cluster, the Artifact
Registry repository, the service account and the `dexaflow_showcase` and
`dexaflow_lab` datasets. Stop `make gke-ui` in the second terminal with Ctrl+C.

**Check your progress**

```bash
gcloud container clusters list --project "$GCP_PROJECT"
```

`dexaflow-showcase` is no longer listed.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `no Dexaflow server at http://localhost:8081` | `make gke-ui` is not running in the second terminal. |
| `run 'make gke-up gke-deploy' first` | Run Task 3 and Task 4 in this clone; both are safe to repeat. |
| A run ends with `failed` | Open the printed link, click the red task and read its log. |
| `dexaflow: command not found` | `export PATH="$HOME/.dexaflow/bin:$PATH"` |

More in [docs/troubleshooting.md](docs/troubleshooting.md).
