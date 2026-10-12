# My Dexaflow DAGs

A workspace for your own Airflow DAGs, deployed to the Dexaflow Pro environment
created by [dexaflow-showcase](https://github.com/neochaotic/dexaflow-showcase).

```bash
make new NAME=my_dag                     # scaffold dags/my_dag (dag.py + dexaflow.yaml)
make deploy DAG=dags/my_dag TRIGGER=1    # build, push, register and run it
make deploy-all                          # deploy every DAG under dags/
make list
```

Each DAG project is a folder with two files:

- `dag.py`: a plain Airflow 3 DAG.
- `dexaflow.yaml`: its build config (DAG id, Python version, pip dependencies).
  Every DAG gets its own image, so dependencies never clash between DAGs.

Deploys go to GKE by default; `make deploy TARGET=local ...` targets the local
k3d environment instead. The `SHOWCASE` path at the top of the `Makefile` points
at the platform clone.

This folder is a git repository of its own: push it to your Git host to keep
your DAGs.
