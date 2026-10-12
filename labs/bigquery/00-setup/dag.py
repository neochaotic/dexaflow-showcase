"""lab_00_setup: prepare the BigQuery lab.

Creates the lab dataset and copies four raw tables from the public
`bigquery-public-data.thelook_ecommerce` dataset (a fictional clothing shop) into
it, so every later DAG works on tables you own. Run it once.

The project and dataset come from the GCP_PROJECT and LAB_DATASET Variables:
change them in the UI (Admin > Variables) to point the lab at your own project.
"""
from __future__ import annotations

from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)
# durable=False: the Dexaflow runtime (0.5.2, 0.5.3) does not support the provider's
# resumable-job path yet (its task instance lacks `stats_tags`).
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "{{ var.value.LAB_DATASET }}"
LOCATION = "US"  # thelook_ecommerce lives in the US multi-region
RAW_TABLES = ["orders", "order_items", "products", "users"]
MAX_BYTES_BILLED = str(1_000_000_000)  # BigQuery rejects, at no cost, any job above 1 GB


def copy_sql(table: str) -> str:
    return (
        f"CREATE OR REPLACE TABLE `{PROJECT}.{DATASET}.raw_{table}` AS "
        f"SELECT * FROM `bigquery-public-data.thelook_ecommerce.{table}`"
    )


with DAG("lab_00_setup", schedule=None, catchup=False, tags=["lab", "gcp"]):
    dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="create_dataset", project_id=PROJECT, dataset_id=DATASET,
        location=LOCATION, if_exists="ignore",
    )
    for name in RAW_TABLES:
        dataset >> BigQueryInsertJobOperator(
            durable=False,
            task_id=f"copy_raw_{name}",
            project_id=PROJECT,
            location=LOCATION,
            configuration={"query": {
                "query": copy_sql(name),
                "useLegacySql": False,
                "maximumBytesBilled": MAX_BYTES_BILLED,
            }},
        )
