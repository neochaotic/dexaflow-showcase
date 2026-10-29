# 05: BigQuery from Python

**Shows:** a plain Python task using the `google-cloud-bigquery` client, with its
own pinned dependency and Python version, authenticated by Workload Identity.

**Needs:** the GKE environment (see [docs/gke.md](../../docs/gke.md)).

**Run:** `make gke-ui` in one terminal, then `make gke-demo USE_CASE=05-gcp-bigquery-python`.

**What to look at:** the ranked list in the logs of `summarize`, the job id
and bytes processed in the logs of `top_github_languages`, and the new table
`dexaflow_showcase.top_github_languages` in the BigQuery console.
