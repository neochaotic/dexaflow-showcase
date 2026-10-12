# Dry run

`make dry-run` checks everything that can be checked without a cluster:

1. **Compiles every DAG** with `dexaflow compile` (no `--build`). This imports
   `dag.py` with the real Dexaflow parser, so it catches DAG errors, not just
   YAML errors. The compiled `dag.json` files land in `.out/dry-run/dags/`.
2. **Renders the Dexaflow Pro chart** with `helm template`, once with the local
   values and once with the GKE values, into `.out/dry-run/manifests/`.
3. **Schema-checks the manifests** with `kubeconform`, when it is installed.

It takes seconds and runs in CI on every pull request. Read the rendered
manifests to see exactly what `make up` or `make gke-deploy` would install.

> `dexaflow validate` alone only checks `dexaflow.yaml`. A DAG that fails to
> import still passes it, so the dry run always compiles.
