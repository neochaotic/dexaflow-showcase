# 03: Fan out

**Shows:** parallelism with pod-per-task. Sixteen workers start at once, each in
its own pod, and a reducer combines their results.

**Run:** `make demo USE_CASE=03-fan-out`

**What to look at**

- Gantt view: the sixteen `estimate` tasks overlap.
- `kubectl -n dexaflow get pods -w`: pods come and go, nothing lingers.
- On GKE, raise `WORKERS` in `dag.py` to 64 and watch new nodes join
  (`kubectl get nodes -w`).
