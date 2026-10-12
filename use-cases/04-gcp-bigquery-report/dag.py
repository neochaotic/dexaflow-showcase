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

from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)
# durable=False: the Dexaflow 0.5.2 runtime does not support the provider's
# resumable-job path yet (its task instance lacks `stats_tags`).
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "dexaflow_showcase"
LOCATION = "US"
# Cost guardrail: BigQuery rejects, at no cost, any job that would bill more.
MAX_BYTES_BILLED = str(1_000_000_000)  # 1 GB

BUILD_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT}.{DATASET}.top_names_by_decade` AS
SELECT decade, name, total
FROM (
  SELECT DIV(year, 10) * 10 AS decade, name, SUM(number) AS total,
         ROW_NUMBER() OVER (PARTITION BY DIV(year, 10) * 10 ORDER BY SUM(number) DESC) AS rank
  FROM `bigquery-public-data.usa_names.usa_1910_current`
  GROUP BY decade, name
)
WHERE rank <= 5
"""

CHECK_SQL = f"""
SELECT COUNT(*) AS row_count, COUNT(DISTINCT decade) AS decades
FROM `{PROJECT}.{DATASET}.top_names_by_decade`
"""


def _job(sql: str) -> dict:
    return {"query": {"query": sql, "useLegacySql": False, "maximumBytesBilled": MAX_BYTES_BILLED}}


with DAG("showcase_bigquery_report", schedule=None, catchup=False, tags=["showcase", "gcp"]):
    create_dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="create_dataset", project_id=PROJECT, dataset_id=DATASET,
        location=LOCATION, if_exists="ignore",
    )
    build = BigQueryInsertJobOperator(
        durable=False,
        task_id="build_report", configuration=_job(BUILD_SQL), project_id=PROJECT, location=LOCATION,
    )
    check = BigQueryInsertJobOperator(
        durable=False,
        task_id="check_report", configuration=_job(CHECK_SQL), project_id=PROJECT, location=LOCATION,
    )
    create_dataset >> build >> check
