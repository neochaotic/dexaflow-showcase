# Lab: Dexaflow Pro on GKE

Copy, paste, run. You build a Dexaflow Pro environment in your own Google Cloud
project, then write, deploy and change Airflow DAGs on it, including BigQuery
pipelines that run without any key file.

Every task ends with a **Check your progress** command and the result you
should see. If what you see differs, see [Troubleshooting](#troubleshooting).

## The path

| Part | You will | Time |
|---|---|---|
| [1. Set up GKE and Dexaflow Pro](#part-1-set-up-gke-and-dexaflow-pro) | install the CLI, create the cluster, install Dexaflow Pro, open the Airflow UI | 20 min |
| [2. Write and deploy DAGs](#part-2-write-and-deploy-dags) | deploy a DAG, create your own workspace, write a DAG, add a dependency and redeploy | 15 min |
| [3. BigQuery pipelines](#part-3-bigquery-pipelines) | query BigQuery keylessly, run a daily ELT and a 4 million event medallion pipeline | 20 min |
| [4. Clean up](#part-4-clean-up) | delete everything the lab created | 5 min |

Do the parts in order: each one starts where the previous one ended. Part 1 is
the only long wait (about 8 minutes for the cluster).

## How to follow this lab

- **Copy each grey block whole** (the copy icon at its top right) and paste it
  into the terminal. It runs line by line; you do not need to press anything
  else.
- **Blocks start with a `cd`**, so they work from any folder. The lab keeps
  everything in your home folder: `~/dexaflow-showcase` (the platform) and
  `~/dexaflow-workspace` (your DAGs).
- **A step is done when your prompt comes back** (the line ending in `$`).
- **Yellow ⏳ lines announce a long, quiet step.** Until the next line appears
  the terminal is busy, not stuck. Do not press Ctrl+C.
- **Green ✔ lines mark a finished step**, and the bold **Next:** line under it
  says what comes next.
- **Only one command asks you something**: `make gke-down` in Task 14 asks you
  to type your project id.
- If the terminal shows `>` and waits, part of a pasted block is missing: press
  **Ctrl+C** and paste the whole block again.

## Before you start

- A Google Cloud project with billing enabled, where you have the **Owner**
  role (or Editor plus Project IAM Admin).
- A terminal: [Cloud Shell](https://shell.cloud.google.com/) has every tool
  already, or use your own macOS or Linux machine ([Part 1](#part-1-set-up-gke-and-dexaflow-pro) lists what to install).
- Basic Airflow knowledge: what a DAG and a task are.

## What it costs

One `e2-standard-2` node (the cluster can grow to 3 under load), the GKE
cluster fee, a small Artifact Registry repository, a few Cloud Build image
builds (within its free monthly minutes) and a few BigQuery jobs, each capped at
1 GB billed. Running the whole lab in one sitting costs a few US
dollars at most. [Part 4](#part-4-clean-up) stops all cost; do it even if you stop
halfway.

## What you will build

```
your terminal                     GKE cluster "dexaflow-showcase"
-------------                     -------------------------------
make deploy DAG=...  ── source ─▶ Cloud Build ── image ──▶ Artifact Registry
                     ── dag.json ▶ Dexaflow control plane (Airflow 3.2 UI, API, scheduler)
make gke-ui ◀── port-forward ────   │  Postgres, Redis (in the cluster)
                                    ▼
                                  one pod per task ── Workload Identity ──▶ BigQuery
```

For how the environment is built and how production differs, see [docs/gke.md](docs/gke.md).

## Part 1. Set up GKE and Dexaflow Pro

About 20 minutes, 8 of them waiting for the cluster. At the end you have
Dexaflow Pro running on GKE and the Airflow UI open in your browser.

### Choose where to run the commands

**Option A: Cloud Shell.** [Open Cloud Shell](https://shell.cloud.google.com/).
It already has `gcloud`, `kubectl`, `helm`, `docker`, `make` and `bq`, and is
signed in as you. The first time a command uses your account, Cloud Shell opens
an **Authorize Cloud Shell** window: click **Authorize**, or the terminal waits
for it. Go to [Task 1](#task-1-get-the-code-and-the-dexaflow-cli).

**Option B: your own terminal (macOS or Linux).** Install
[`gcloud`](https://cloud.google.com/sdk/docs/install),
[`kubectl`](https://kubernetes.io/docs/tasks/tools/),
[`helm`](https://helm.sh/docs/intro/install/) 3.16+ and `make`
(no Docker needed: DAG images are built on Cloud Build), then:

```bash
gcloud auth login
gcloud components install gke-gcloud-auth-plugin bq
```

(If you installed `gcloud` with a package manager, install those two
components with it instead.)

### Task 1. Get the code and the Dexaflow CLI

```bash
cd ~
git clone https://github.com/neochaotic/dexaflow-showcase.git || git -C ~/dexaflow-showcase pull --ff-only
cd ~/dexaflow-showcase
make cli
export PATH="$HOME/.dexaflow/bin:$PATH"
```

If you ran the lab before, `git clone` says the folder already exists and the
next line updates it instead.

⏳ On a machine without Python 3.11 (Cloud Shell, for example), `make cli`
downloads one: up to 2 minutes with no output after the yellow line.

**You should see** at the end:

```
✔ Dexaflow CLI 0.5.3 is ready
==> New terminals find dexaflow on their own. In this one, run:
   Next: export PATH="$HOME/.dexaflow/bin:$PATH"
```

The block above already ran that `export` line for you.

`make cli` installs the Dexaflow CLI version pinned in
[`versions.env`](versions.env), plus the small Python runtime it uses to
read `dag.py` files.

**Check your progress**

```bash
dexaflow version
make doctor
```

`dexaflow version` prints **`0.5.3`**. `make doctor` prints **`ok`** for every
tool and the account you are signed in with; `k3d` and `kubeconform` show
`skip`, they are not needed for this lab.

### Task 2. Point the lab at your project

Replace `my-project-id` with your project id:

```bash
gcloud config set project my-project-id
```

That is the only setting. Every `make` target reads the project from gcloud,
and once Task 3 has run, `make deploy` sends DAGs to GKE on its own. In a new
terminal you only need `cd ~/dexaflow-showcase`: `make cli` added the CLI to your
shell profile.

`gcloud config set project` changes your default project for every gcloud
command, not only this lab. It may also print a warning about the quota project
of your application default credentials, or about a missing `environment` tag
on the project; both are safe to ignore here.

If it asks *Do you want to continue (Y/n)?*, gcloud cannot find that project
under your account: the id is probably mistyped. Type `n`, check the id in the
[console](https://console.cloud.google.com/) (the **ID** column of the project
picker, not the name) and run the command again.

**Check your progress**

```bash
gcloud config get-value project
```

It prints **your project id**.

### Task 3. Create the GKE cluster

```bash
cd ~/dexaflow-showcase
make gke-up
```

The script prints every command it runs with a `$` in front, so you can see
exactly what it does. It enables the APIs, then creates:

| Resource | Name | Why |
|---|---|---|
| GKE Standard cluster, zonal, 1 to 3 nodes | `dexaflow-showcase` | runs the control plane and one pod per task |
| Artifact Registry repository | `dexaflow-showcase` | one image per DAG |
| Service account | `dexaflow-tasks` | identity of the task pods, with BigQuery job and data access |
| Workload Identity binding | `dexaflow/dexaflow-task` | task pods act as `dexaflow-tasks` with no key file |
| Cloud Build API and push permission | Cloud Build's default service account | builds each DAG image and pushes it to the repository, so your machine needs no Docker |

⏳ **This is the long step: about 10 minutes in all.** Enabling the APIs can take
2 minutes, then creating the cluster about 8, while gcloud shows only a
spinner. Running `make gke-up` again is safe: it skips what already exists.

**You should see** at the end:

```
✔ GKE environment ready: cluster dexaflow-showcase in my-project-id
   Next: make gke-deploy
```

If a yellow `WARN Cluster dexaflow-showcase already exists` line showed up
instead of the cluster creation, this project already had the lab's cluster
with whatever was deployed on it; see [Troubleshooting](#troubleshooting).

**Check your progress**

```bash
kubectl get nodes
```

```
NAME                                         STATUS   ROLES    AGE   VERSION
gke-dexaflow-showcase-default-pool-...       Ready    <none>   2m    v1.3x...
```

**One node, `Ready`.**

### Task 4. Install Dexaflow Pro

```bash
cd ~/dexaflow-showcase
make gke-deploy
```

This runs Postgres and Redis inside the cluster (enough for a lab; production
uses Cloud SQL and Memorystore, see [docs/gke.md](docs/gke.md)), then installs the
Dexaflow Pro Helm chart. It generates an admin password into
`.out/gke-secrets.yaml`, which git ignores, and keeps a copy in the cluster so
another clone of the repo reuses it.

⏳ After the `Installing Dexaflow Pro` line, Helm waits until every Dexaflow pod
runs: 2 to 5 minutes with no output.

**You should see** at the end:

```
✔ Dexaflow Pro 0.5.3 is running on dexaflow-showcase
==> The UI is not reachable yet: the next command opens it.
   Next: make gke-ui    (opens the UI in the background)
   Next: make gke-info  (shows how to sign in)
```

**Check your progress**

```bash
kubectl -n dexaflow get pods
```

The `dexaflow-...`, `postgres-...` and `redis-...` pods show **`1/1`** and
**`Running`**. If DAGs already ran on this cluster, you also see `Completed` task
pods (named `leoflow-...`, the project's former name).

### Task 5. Open the Airflow UI

The UI is not exposed to the internet; you reach it through a port-forward,
which runs in the background and reconnects on its own:

```bash
cd ~/dexaflow-showcase
make gke-ui
make gke-info
```

Your prompt comes back right away: the port-forward keeps running in the
background. **You should see:**

```
✔ UI on http://localhost:8081
==> It runs in the background, so this terminal stays free (stop it with: make gke-ui-stop)
   Next: make gke-info  (shows how to sign in)
  UI        http://localhost:8081   (start it with: make gke-ui)
  user      admin@leoflow.local
  password  run: grep -A1 '^bootstrap:' .out/gke-secrets.yaml
  ...
```

Show your password with the command `make gke-info` prints (it stays on your
screen only; do not paste it anywhere public):

```bash
grep -A1 '^bootstrap:' .out/gke-secrets.yaml
```

The password is the text after **`password:`**.

Then open the UI and sign in as **`admin@leoflow.local`** with that password:

- **Your own machine:** open <http://localhost:8081>.
- **Cloud Shell:** open the address that `make gke-ui` prints after
  **Cloud Shell: open**. If it printed none, click **Web Preview** (a button
  at the top right of the terminal panel) > **Change port**, type **`8081`**, then **Change and Preview**.
  The default *Preview on port 8080* shows *Unable to forward your request to a
  backend*. If you landed there, change the start of the address from `8080-`
  to **`8081-`** and reload.

**Check your progress**

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8081/readyz
```

It prints **`200`**, and the browser shows the Airflow 3.2 UI, with no DAGs yet.

## Part 2. Write and deploy DAGs

About 15 minutes. You deploy an existing DAG, write your own, then change it the
way you would change any Airflow DAG.


### Task 6. Deploy your first DAG

[`use-cases/01-hello-pipeline/dag.py`](use-cases/01-hello-pipeline/dag.py)
is a plain Airflow 3 DAG: three TaskFlow tasks passing data through XCom.
Nothing in it is specific to Dexaflow.

```bash
cd ~/dexaflow-showcase
make deploy DAG=use-cases/01-hello-pipeline TRIGGER=1
```

`make deploy` runs the whole Dexaflow loop and prints each command:

1. `dexaflow compile ... --build --push` reads `dag.py`, writes `dag.json`,
   and has [Cloud Build](https://cloud.google.com/build/docs) build an image
   with only this DAG's dependencies and push it to Artifact Registry. You never
   write a Dockerfile, and your machine needs no Docker.
2. `dexaflow push` registers `dag.json` with the control plane. The DAG appears
   in the UI.
3. `TRIGGER=1` starts a run, unpauses the DAG and waits for the run to
   finish. Without it, the DAG is only registered, paused. A scheduled DAG
   (`@daily` in Part 3) also gets a run of its latest day as soon as it is
   unpaused: the UI shows it as `scheduled__<date>`, next to your
   `manual__<time>` run.

⏳ Each image build on Cloud Build takes a minute or two, quietly: its output
goes to `.out/build-<dag_id>.log`, and every build is listed in the console
under **Cloud Build > History**. While the run goes, a
`... is running (1m30s)` line appears every 30 seconds; the run itself takes
about a minute.

**Check your progress**

The command ends with:

```
✔ showcase_hello_pipeline deployed: http://localhost:8081/dags/showcase_hello_pipeline
...
  success  showcase_hello_pipeline
```

**`success`** in green means the run finished.
In the UI, open `showcase_hello_pipeline` and its run. Each task ran in its own
pod. Click `load`, then **XCom**, to see the summary it returned.

### Task 7. Create your workspace and write your own DAG

Your DAGs do not belong in the platform repository. Create a **workspace**: a
folder of your own, next to the clone, with its own git repository and a
`Makefile` that deploys through the platform you just built.

```bash
cd ~/dexaflow-showcase
make workspace
cd ~/dexaflow-workspace
make help
```

Now scaffold a DAG project in it, replace its `dag.py`, and deploy it.
(`make new` uses `dexaflow init`, which suggests `dexaflow lite` as a next
step; that is the single-host edition, so skip it here.)

```bash
cd ~/dexaflow-workspace
make new NAME=my_first_dag
cat > dags/my_first_dag/dag.py <<'EOF'
from airflow.sdk import DAG, task


@task
def greet() -> str:
    message = "hello from my first Dexaflow DAG"
    print(message)
    return message


with DAG("my_first_dag", schedule=None, catchup=False, tags=["lab"]):
    greet()
EOF
make deploy DAG=dags/my_first_dag TRIGGER=1
```

A DAG project is two files. `dag.py` is the DAG. `dexaflow.yaml` is its build
config: the DAG id, the Python version and the dependencies (none yet).

**Check your progress**

The command ends with **`success  my_first_dag`**, and `my_first_dag` shows in
the UI with one green run. `make list` prints `dags/my_first_dag`.

This is the loop for any DAG from now on: edit files under `dags/`, then
`make deploy DAG=dags/<name>`. To keep your DAGs, commit them and push the
workspace to your own Git host.

### Task 8. Add a dependency and a task, then redeploy

Still in the workspace, add [Faker](https://faker.readthedocs.io/) to this DAG
only, and a task that uses it:

```bash
cd ~/dexaflow-workspace
cat > dags/my_first_dag/dexaflow.yaml <<'EOF'
schema_version: "1.0"
dag_id: my_first_dag
description: My first Dexaflow DAG.
python_version: "3.11"
dependencies:
  - faker==33.1.0
EOF
cat > dags/my_first_dag/dag.py <<'EOF'
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
make deploy DAG=dags/my_first_dag TRIGGER=1
```

Only this DAG's image has Faker. In a classic Airflow deployment every DAG
shares one Python environment, so one DAG's dependency can break another.

**Check your progress**

The command ends with **`success  my_first_dag`**. In the UI the DAG now has two
tasks, and the log of `greet` shows five generated names.

### Task 9 (optional). Two pandas versions side by side

[`use-cases/02-dependency-isolation`](use-cases/02-dependency-isolation/)
has two DAGs, one pinned to pandas 1.5 on Python 3.11 and one to pandas 2.2 on
Python 3.13. One shared Airflow environment cannot hold both. These DAGs live
in the platform clone, so go back there first:

```bash
cd ~/dexaflow-showcase
make deploy DAG=use-cases/02-dependency-isolation TRIGGER=1
```

**Check your progress**

```
  success  showcase_legacy_pandas
  success  showcase_modern_pandas
```

Each task log prints the pandas version it ran with.

## Part 3. BigQuery pipelines

About 20 minutes. Your DAGs query BigQuery with no key file: task pods use the
`dexaflow-tasks` service account through Workload Identity. No DAG names your
project; they read it from Airflow Variables.

These commands run in the platform clone; each block starts with
`cd ~/dexaflow-showcase`.

### Task 10. Query BigQuery without a key

[`use-cases/04-gcp-bigquery-report/dag.py`](use-cases/04-gcp-bigquery-report/dag.py)
uses the stock Airflow BigQuery operators to build the top 5 US baby names per
decade.

```bash
cd ~/dexaflow-showcase
make deploy DAG=use-cases/04-gcp-bigquery-report TRIGGER=1
```

Before deploying, `make deploy` creates the `google_cloud_default` connection
(no key in it) and the `GCP_PROJECT` and `LAB_DATASET` Variables. See them in the
UI under **Admin > Connections** and **Admin > Variables**. ⏳ This first build
takes about 2 minutes because of the Google provider packages.

The first `bq` command in a new Cloud Shell may print *Welcome to BigQuery!*
and set itself up; if it asks you to pick a default project, type the number
next to your project id and press Enter.

**Check your progress**

```bash
bq query --use_legacy_sql=false \
  'SELECT COUNT(*) AS row_count FROM dexaflow_showcase.top_names_by_decade'
```

**`row_count` is `60`**: 5 names for each of 12 decades.

### Task 11. Deploy the labs

```bash
cd ~/dexaflow-showcase
make gke-lab
```

This deploys four DAGs and runs two of them, then waits. ⏳ About 5 minutes:
the medallion run starts eight pods, and the cluster may add a node for them.

| DAG | What it does | Runs now |
|---|---|---|
| [`lab_00_setup`](labs/bigquery/00-setup/dag.py) | copies four tables of the public `thelook_ecommerce` shop into `dexaflow_lab.raw_*` | yes |
| [`lab_medallion_daily`](labs/medallion/medallion_daily/dag.py) | generates 4 million events with DuckDB, bronze to silver to gold (Task 13) | yes |
| [`lab_01_daily_sales`](labs/bigquery/01-daily-sales/dag.py) | one day of orders into `stg_order_lines`, then `mart_daily_sales` | Task 12 |
| [`lab_02_quality_checks`](labs/bigquery/02-quality-checks/dag.py) | `ASSERT` checks on the mart | Task 12 |

**Check your progress**

```
  success  lab_00_setup
  success  lab_medallion_daily
```

### Task 12. Run a daily ELT and its quality checks

```bash
cd ~/dexaflow-showcase
make deploy DAG=labs/bigquery/01-daily-sales TRIGGER=1
make deploy DAG=labs/bigquery/02-quality-checks TRIGGER=1
```

`lab_01_daily_sales` is `@daily` and processes only its own day (`{{ ds }}`), so
running a day twice gives the same result.

**Check your progress**

Both commands end with `success`, then:

```bash
bq query --use_legacy_sql=false \
  'SELECT table_id, row_count FROM dexaflow_lab.__TABLES__ WHERE table_id NOT LIKE "%events" AND table_id NOT LIKE "gold%" ORDER BY table_id'
```

You see **`mart_daily_sales`**, the four `raw_*` tables with thousands of rows each,
and `stg_order_lines`.

**Change a Variable, not the code.** In the UI, open **Admin > Variables**, set
`LAB_DATASET` to `my_lab`, and trigger `lab_00_setup` again from the UI. It
writes to the new dataset with no redeploy, because Variables are read at run
time. Later deploys keep the value you set. Set it back to `dexaflow_lab`
afterwards, and delete the extra dataset with
`bq rm -r -f -d my_lab`.

### Task 13. Look at 4 million events

`lab_medallion_daily` ran in Task 11. Its eight `generate_shard` tasks ran as
eight pods at once; each generated 500,000 synthetic e-commerce events with
DuckDB, wrote Parquet and loaded it into BigQuery. SQL tasks then refined them:

| Layer | Table | Content |
|---|---|---|
| Bronze | `bronze_events` | events as generated, with about 2.5% duplicates and bad rows |
| Silver | `silver_events` | deduplicated and cleaned, with `revenue` |
| Gold | `gold_daily_sales`, `gold_funnel` | sales per country and category, conversion per channel |

In the UI, open `lab_medallion_daily` and its run: the **Graph** shows the
fan-out, the **Gantt** shows the eight shards running in parallel.

**Check your progress**

```bash
bq query --use_legacy_sql=false \
  'SELECT table_id, row_count FROM dexaflow_lab.__TABLES__ WHERE table_id LIKE "%events" OR table_id LIKE "gold%" ORDER BY table_id'
```

**`bronze_events` has `4000000` rows**, `silver_events` about 3.9 million, and the
two `gold_*` tables a few rows each.

**Want more?** Choose **Trigger** on `lab_medallion_daily` in the UI and set
`rows_per_shard` to `2500000` for 20 million events. Each lab's README has
exercises: [BigQuery lab](labs/bigquery/README.md#exercises),
[medallion lab](labs/medallion/README.md#exercises).

## Part 4. Clean up

About 5 minutes. Do this even if you stopped halfway: the cluster costs money
while it runs.

### Task 14. Delete everything the lab created

```bash
cd ~/dexaflow-showcase
make gke-down
```

It lists what it will delete and asks you to type the project id (type it,
then press Enter):

- the GKE cluster `dexaflow-showcase`
- the Artifact Registry repository `dexaflow-showcase`
- the BigQuery datasets `dexaflow_showcase` and `dexaflow_lab`
- the service account `dexaflow-tasks` and its role bindings

It leaves the Cloud Build API enabled, and the `<project>_cloudbuild` bucket
that `gcloud builds submit` created for DAG sources (a few kilobytes per
build). Delete that bucket in the console if you want nothing left.

⏳ Deleting the cluster takes about 5 minutes. **You should see** at the end:

```
✔ GKE demo environment removed from my-project-id
```

If you changed `LAB_DATASET` in Part 3, delete that dataset too:
`bq rm -r -f -d my_lab`.

**Check your progress**

```bash
gcloud container clusters list
```

**`dexaflow-showcase` is not listed** (the list may be empty).

## What next

- Run the same DAGs on a local cluster: [docs/quickstart-local.md](docs/quickstart-local.md).
- How the GKE environment is built, and how production differs: [docs/gke.md](docs/gke.md).
- Dexaflow itself: <https://github.com/dexadata/dexaflow>.

## Troubleshooting

| Symptom | Fix |
|---|---|
| The terminal shows `>` and waits | Part of a pasted block is missing. Press **Ctrl+C**, then copy the whole block again with its copy icon. |
| Nothing new on screen for minutes | Check for a yellow ⏳ line above: that step is long and quiet. With none, press **Enter** once; if a question shows up, answer it. |
| Cloud Shell waits after the first `gcloud` command | Click **Authorize** in the *Authorize Cloud Shell* window. |
| `dexaflow: command not found` | `export PATH="$HOME/.dexaflow/bin:$PATH"`, or open a new terminal. |
| `no GCP project` | Run Task 2: `gcloud config set project my-project-id`. |
| `make gke-up` fails on an API or IAM step | You need Owner (or Editor plus Project IAM Admin) on the project. |
| `run 'make gke-up' first` | Run Task 3 in this clone; it is safe to repeat. |
| Cloud Shell shows *Unable to forward your request to a backend ... port 8080* | Web Preview opened 8080; use **Change port** and `8081`, or replace the leading `8080-` in the preview URL with `8081-`. |
| The UI already lists DAGs you did not deploy | `make gke-up` reused an existing cluster in your project (it says so in yellow). `make gke-reset` empties its database. |
| `curl` prints `000` | The UI port-forward is not running: `make gke-ui`. |
| The UI worked, then stops answering; `kubectl -n dexaflow get pods` shows new pods or `CrashLoopBackOff` | The pods restarted on another node (for example after a node upgrade, or a Spot node reclaimed with `GKE_SPOT=true`). Wait a minute, then `make gke-ui`. If `dexaflow-...` keeps crashing, run `make gke-deploy`, then `make gke-ui`. |
| `bq` asks for a default project | Type the number next to your project id, then Enter. |
| `invalid credentials` | The user is `admin@leoflow.local`, not `admin`. |
| `no Dexaflow server at http://localhost:8081` | The UI port-forward is not running: `make gke-ui` (its log is `.out/gke-ui.log`). |
| `failed  <dag_id>` and a link | Open the link, click the red task, read its log. |
| An error from `dexaflow compile` | It shows the Python error from `dag.py`; fix it and deploy again. |
| `dags/my_first_dag/...: No such file or directory` | You are inside the DAG folder; go back to the workspace with `cd ~/dexaflow-workspace` (or wherever `make workspace` put it). |
| `dags/my_first_dag already exists` | You already ran `make new`; continue with the `cat` commands. |
| `No rule to make target 'new'` or `'workspace'` | You are in the wrong folder: `make workspace` runs in `dexaflow-showcase`, `make new` in `dexaflow-workspace`. |
| `PERMISSION_DENIED` in `.out/build-<dag_id>.log` right after Task 3 | New permissions take a minute to apply; run the same `make deploy` again. |
| `this GKE environment predates Cloud Build image builds` | Run `make gke-up` again: it adds what is missing and keeps everything else. |
| `Access Denied` in a task log | `make gke-up` grants BigQuery roles to `dexaflow-tasks`; run it again, it is safe to repeat. |
| `Not found: Dataset` in the `bq` check | The run that creates it has not finished; wait for the `success` line. |
| `mart_daily_sales is empty` in `lab_02_quality_checks` | The public shop had no completed orders for that day; trigger `lab_01_daily_sales` for another day from the UI. |

More in [docs/troubleshooting.md](docs/troubleshooting.md).
