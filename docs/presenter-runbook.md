# Presenter runbook

## The day before

- [ ] `make gke-up gke-deploy` and `make gke-demo` once, so every image is built
      and every DAG has a successful run to show.
- [ ] Open the BigQuery console on the `dexaflow_showcase` dataset.
- [ ] `make up && make demo` on the laptop as the offline fallback.

## Before going on stage

- [ ] `make gke-ui` running, <http://localhost:8081> signed in (`make gke-info`).
- [ ] A DAG workspace ready (`make workspace`), with an editor open on it.
- [ ] A terminal with `kubectl -n dexaflow get pods -w`.
- [ ] Font size up in the terminal and the browser.

## Flow (about 20 minutes)

1. **The UI** (1 min). It is the Airflow 3.2 UI, unmodified, served by a Go binary.
2. **01 Hello pipeline** (3 min). Trigger it; one pod per task appears and
   disappears in the terminal. Show the XCom of `load`.
3. **02 Dependency isolation** (3 min). Two DAGs, pandas 1.5 and 2.2, both green.
   In Airflow one of them would have to give in.
4. **03 Fan out** (3 min). Sixteen pods at once; Gantt view.
5. **04 BigQuery report** (4 min). The stock Google provider operators, no key in
   the cluster. Show the new table in the BigQuery console.
6. **Write a DAG live** (4 min). In the workspace: `make new NAME=live_demo`,
   edit `dag.py` (add a task, or a dependency in `dexaflow.yaml`), then
   `make deploy DAG=dags/live_demo TRIGGER=1`. The new version shows in the UI;
   the steps are in [LAB.md, Part 2](../LAB.md#part-2-write-and-deploy-dags).
7. **Medallion** (optional, 3 min). `lab_medallion_daily`: eight DuckDB pods
   generate 4 million events into BigQuery bronze, silver and gold. Show the Gantt.
8. **Wrap up** (1 min). Everything shown is in this repository; anyone can
   reproduce it with [LAB.md](../LAB.md).

## When something fails

| Symptom | Fallback |
|---|---|
| Conference network blocks the cluster | switch to the local k3d environment |
| A run is slow to start | show the previous successful run in the Grid view |
| BigQuery error | show the logs of the last successful run |
