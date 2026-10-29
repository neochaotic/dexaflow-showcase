# Local quickstart (k3d)

Runs Dexaflow Pro on a local [k3d](https://k3d.io) cluster. Nothing leaves your
machine except image pulls.

```bash
make up      # cluster, registry, Postgres, Redis, Dexaflow Pro
make demo    # build, register and trigger use cases 01 to 03
make down    # delete it all
```

## What `make up` does

1. Creates the k3d cluster `dexaflow-showcase` with a local image registry
   (`k3d-showcase-registry.localhost:5050`) and maps `localhost:8080` to the UI.
2. Deploys throwaway Postgres and Redis pods (Pro requires external datastores;
   here they are in-cluster, with no persistence).
3. Installs the Dexaflow Pro chart from `oci://ghcr.io/dexadata/charts/dexaflow`
   with `pro/platform/base/values.yaml` and `pro/platform/local/values-local.yaml`.

## What `make demo` does, per use case

```bash
dexaflow compile use-cases/<case> --image <registry>/<dag_id>:<git sha> --build --push
dexaflow push .out/dags/<dag_id>.json --server http://localhost:8080
curl -X POST http://localhost:8080/api/v2/dags/<dag_id>/dagRuns ...
```

It then waits for every run, prints `success` or `failed` per DAG with a link
to the failed run, and exits non-zero if any run failed. `WAIT=0 make demo`
returns right after triggering.

The BigQuery use cases are skipped locally: they need Workload Identity, which
only the GKE environment has.

## Sign in

<http://localhost:8080>, user `admin@dexaflow.local`, password `showcase-admin`.
These credentials are for your laptop only.
