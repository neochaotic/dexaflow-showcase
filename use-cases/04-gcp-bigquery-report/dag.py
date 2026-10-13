"""showcase_bigquery_report: a BigQuery ELT with the stock Airflow operators.

1. create the dataset (no-op when it exists)
2. build a table of the most popular US baby names per decade, from the public
   `bigquery-public-data.usa_names` dataset, into your project
3. run a check query over the new table

Credentials: none in this file and none in the cluster. Task pods run as a
Kubernetes ServiceAccount bound to a Google service account (Workload Identity).
The project comes from the GCP_PROJECT Variable at run time.
"""
from __future__ import annotations

from pathlib import Path

from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)
# durable=False: the Dexaflow runtime (0.5.2, 0.5.3) does not support the provider's
# resumable-job path yet (its task instance lacks `stats_tags`).
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "dexaflow_showcase"  # also named in sql/*.sql
LOCATION = "US"
# Cost guardrail: BigQuery rejects, at no cost, any job that would bill more.
MAX_BYTES_BILLED = str(1_000_000_000)  # 1 GB

# The SQL lives in sql/ (shipped with the DAG through include_paths in
# dexaflow.yaml), so it reads, highlights and lints as plain SQL.
SQL_DIR = Path(__file__).parent / "sql"


def sql(name: str) -> str:
    return (SQL_DIR / f"{name}.sql").read_text()


def _job(sql: str) -> dict:
    return {"query": {"query": sql, "useLegacySql": False, "maximumBytesBilled": MAX_BYTES_BILLED}}


with DAG("showcase_bigquery_report", schedule=None, catchup=False, tags=["showcase", "gcp"]):
    create_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="create_dataset", project_id=PROJECT, dataset_id=DATASET,
        location=LOCATION, if_exists="ignore",
    )
    build = BigQueryInsertJobOperator(
        durable=False,
        task_id="build_report", configuration=_job(sql("build_report")), project_id=PROJECT, location=LOCATION,
    )
    check = BigQueryInsertJobOperator(
        durable=False,
        task_id="check_report", configuration=_job(sql("check_report")), project_id=PROJECT, location=LOCATION,
    )
    create_dataset >> build >> check
