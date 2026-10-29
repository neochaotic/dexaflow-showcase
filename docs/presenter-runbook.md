# Presenter runbook

> [!IMPORTANT]
> **On stage you run no build and no deploy.** Everything is built, deployed
> and run once the day before. On stage you open the Airflow UI and press
> **Trigger**: a run starts in seconds.

## 1. The day before: build everything

Run these in Cloud Shell or your own terminal, in `~/dexaflow-showcase`.

| Step | Command | Time |
|---|---|---|
| Cluster ([LAB.md Part 0](../LAB.md#part-0-create-the-cluster-ahead-of-time)) | `make gke-up` | about 10 min |
| Dexaflow Pro | `make gke-deploy` | about 2 min |
| UI in the background | `make gke-ui` | under 30 s |
| **Build, deploy and run every DAG once** | `make gke-prebuild` | 15 to 25 min, unattended |

`make gke-prebuild` builds each DAG image, registers it and runs it once, so
the images are in Artifact Registry and on the node, and every DAG has a green
run to show. Check that every DAG in the UI has a green run.

Also:

- [ ] Open the BigQuery console on the `dexaflow_showcase` dataset.
- [ ] `make up && make demo` on the laptop as the offline fallback.

## 2. Before going on stage

- [ ] In a fresh terminal, run Tasks 1 to 4 of
      [LAB.md, Part 1](../LAB.md#part-1-set-up-gke-and-dexaflow-pro): with the
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
| 3 | **BigQuery example: `showcase_bigquery_report`** | **Trigger**. The stock Google provider operators, no key in the cluster. Then the new table `top_names_by_decade` in the BigQuery console | 4 min |
| 4 | **Wrap up** | Everything shown is in this repository; anyone can reproduce it with [LAB.md](../LAB.md) | 1 min |

If there is time, also from the UI: `showcase_fan_out` (sixteen pods at once,
Gantt view), the two pandas DAGs of `02-dependency-isolation` (pandas 1.5 and
2.2, both green), or `lab_medallion_daily` (4 million events into BigQuery
bronze, silver and gold).

Writing a DAG live is optional: the steps are in
[LAB.md, Part 2](../LAB.md#part-2-write-and-deploy-dags), and a redeploy that
changes only `dag.py` takes seconds.

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
