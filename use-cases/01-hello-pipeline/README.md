# 01: Hello pipeline

**Shows:** the unmodified Airflow 3 UI served by Dexaflow, and pod-per-task
execution: each task is its own short-lived pod, built from this DAG's own image.

**Run:** `make demo USE_CASE=01-hello-pipeline`

**What to look at**

- Grid view: three tasks, each with its own logs.
- XCom tab of `load`: the summary computed upstream.
- `kubectl -n dexaflow get pods -w` while it runs: one pod appears per task and
  disappears when the task ends.
