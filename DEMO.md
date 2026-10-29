# Live demo: what to run

> [!IMPORTANT]
> **On stage you run no build and no deploy.** Everything is built, deployed
> and run once the day before. On stage you open the Airflow UI and press
> **Trigger**: a run starts in seconds.

## 1. The day before: build everything

Run these in Cloud Shell or your own terminal, in `~/dexaflow-showcase`.

| Step | Command | Time |
|---|---|---|
| Cluster ([LAB.md Part 0](LAB.md#part-0-create-the-cluster-ahead-of-time)) | `make gke-up` | 10:00 (0:41 if it is already up) |
| Dexaflow Pro | `make gke-deploy` | 2:00 |
| UI in the background | `make gke-ui` | under 0:30 |
| **Build, deploy and run every DAG once** | `make gke-prebuild` | 18:24, unattended |

`make gke-prebuild` builds each DAG image, registers it and runs it once, so
the images are in Artifact Registry and on the node, and every DAG has a green
run to show. Check that `showcase_hello_pipeline` and `showcase_bigquery_python`
have a green run; `showcase_bigquery_report` fails on 0.5.7 (see the known issues
below), so pause it in the UI to keep the DAG list green. A hello run triggered
from the UI after the prebuild takes about 1 minute.

Also:

- [ ] Open the BigQuery console on the `dexaflow_showcase` dataset.
- [ ] `make up && make demo` on the laptop as the offline fallback.

## 2. Before going on stage

- [ ] In a fresh terminal, run Tasks 1 to 4 of
      [LAB.md, Part 1](LAB.md#part-1-set-up-gke-and-dexaflow-pro): with the
      cluster already up they take a few minutes and rebuild nothing.
- [ ] `make gke-ui` running, <http://localhost:8081> signed in as
      `admin@dexaflow.local` (`make gke-info` shows where the password is).
      In Cloud Shell, Web Preview on port **8081**, not 8080.
- [ ] A terminal with `kubectl -n dexaflow get pods -w`.
- [ ] Font size up in the terminal and the browser.

## 3. On stage: only the UI

> [!TIP]
> **What you show live.** Two DAGs, both triggered from the UI, no commands.

| # | What | In the UI | Time |
|---|---|---|---|
| 1 | **The UI** | The Airflow 3 UI, unmodified, served by a Go binary | 1 min |
| 2 | **Simple example: `showcase_hello_pipeline`** | **Trigger**. In the pods terminal, one pod per task appears and disappears. Grid view, then the XCom of `load` | 3 min |
| 3 | **BigQuery example: `showcase_bigquery_python`** | **Trigger**. A Python task with the `google-cloud-bigquery` client, no key in the cluster (Workload Identity). The ranked languages in the logs of `summarize`, the job id and bytes processed in the logs of `top_github_languages`, then the table `dexaflow_showcase.top_github_languages` in the BigQuery console | 4 min |
| 4 | **Wrap up** | Everything shown is in this repository; anyone can reproduce it with [LAB.md](LAB.md) | 1 min |

If there is time, also from the UI: the two pandas DAGs of
`02-dependency-isolation` (pandas 1.5 and 2.2, both green).

> [!WARNING]
> **Known issues on Dexaflow 0.5.7.**
> - The BigQuery operator DAGs (`showcase_bigquery_report` and the BigQuery
>   labs) fail with `NotProvidedError: the DAG run has no attribute
>   'start_date'` ([dexadata/dexaflow#1843](https://github.com/dexadata/dexaflow/issues/1843)):
>   the Google provider reads `dag_run.start_date`, which Dexaflow does not
>   provide yet. Show `showcase_bigquery_python` instead.
> - `showcase_fan_out` starts sixteen pods at once and saturates the single
>   node until the cluster grows, which can drop the UI connection. Keep it
>   out of the live part.

Writing a DAG live is optional: the steps are in
[LAB.md, Part 2](LAB.md#part-2-write-and-deploy-dags), and a redeploy that
changes only `dag.py` takes about 0:40.

## When something fails

| Symptom | Fallback |
|---|---|
| Conference network blocks the cluster | switch to the local k3d environment |
| A run is slow to start | show the green run from the day before in the Grid view |
| BigQuery error | show the logs of the green run from the day before |
| UI stops answering for a few seconds | wait about 15 seconds: the port-forward reconnects on its own; if not, `make gke-ui` |
| Cloud Shell disconnected while idle | reconnect, `cd ~/dexaflow-showcase && make gke-ui`, reload Web Preview; files in `~` are kept |
| `invalid credentials` at sign-in | the user is `admin@dexaflow.local` |
| First `bq` command asks for a project | type the number next to your project |
