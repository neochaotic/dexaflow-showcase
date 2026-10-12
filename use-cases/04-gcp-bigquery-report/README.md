# 04: BigQuery report (Airflow operators)

**Shows:** an existing Airflow DAG that uses the Google provider's BigQuery
operators runs on Dexaflow unchanged, keyless, through Workload Identity.

**Needs:** the GKE environment (`make gke-up gke-deploy`, see [docs/gke.md](../../docs/gke.md)).

**Run:** `make gke-ui` in one terminal, then `make gke-demo USE_CASE=04-gcp-bigquery-report`.

**What to look at**

- The new table `dexaflow_showcase.top_names_by_decade` in the BigQuery console.
- Logs of `build_report`: the BigQuery job id (open it in the BigQuery console for bytes processed).
- No key anywhere: `kubectl -n dexaflow get secrets` has no service account key.

**Cost:** the query scans the `name`, `number` and `year` columns of a public
table (well under 1 GB). `maximumBytesBilled` rejects any job above 1 GB before
it runs.
