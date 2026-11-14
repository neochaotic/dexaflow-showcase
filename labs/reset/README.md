# Reset the lab

`lab_reset` deletes every table in the lab's BigQuery datasets: the one named
by the `LAB_DATASET` Variable (the BigQuery and medallion labs) and
`dexaflow_showcase` (the use cases). The datasets stay, empty, and the lab DAGs
create their tables again on their next run. The cluster, Dexaflow and its
login are not touched.

```bash
cd ~/dexaflow-showcase
make gke-lab-reset
```

It deploys `lab_reset` and runs it once. Later, start over from the UI with
**Trigger** on `lab_reset`. To also empty the Dexaflow database (DAGs and
runs), add `make gke-reset`.
