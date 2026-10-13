"""lab_01_daily_sales: a daily ELT, the classic Airflow shape.

Each run processes one day, `{{ ds }}`:

    stage_order_lines -> build_daily_sales

1. `stage_order_lines` rebuilds that day's slice of `stg_order_lines`
   (order items joined with products, completed orders only).
2. `build_daily_sales` rebuilds that day's rows of `mart_daily_sales`
   (revenue and orders per product category).

Both steps delete-then-insert one day, so re-running a day is safe (idempotent).

Exercises (see labs/bigquery/README.md): add a column, add a task, re-run a
past day from the UI, change the schedule.
"""
from __future__ import annotations

from datetime import datetime
from pathlib import Path

from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
# durable=False: the Dexaflow runtime (0.5.2, 0.5.3) does not support the provider's
# resumable-job path yet (its task instance lacks `stats_tags`).
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "{{ var.value.LAB_DATASET }}"
LOCATION = "US"
MAX_BYTES_BILLED = str(1_000_000_000)
# The SQL lives in sql/ (shipped with the DAG through include_paths in
# dexaflow.yaml). Airflow renders its {{ ds }} and Variables at run time.
SQL_DIR = Path(__file__).parent / "sql"


def sql(name: str) -> str:
    return (SQL_DIR / f"{name}.sql").read_text()


def bq(task_id: str) -> BigQueryInsertJobOperator:
    return BigQueryInsertJobOperator(
        durable=False,
        task_id=task_id, project_id=PROJECT, location=LOCATION,
        configuration={"query": {"query": sql(task_id), "useLegacySql": False,
                                 "maximumBytesBilled": MAX_BYTES_BILLED}},
    )


with DAG(
    "lab_01_daily_sales",
    schedule="@daily",
    start_date=datetime(2026, 10, 1),
    catchup=False,
    max_active_runs=1,
    tags=["lab", "gcp"],
):
    bq("stage_order_lines") >> bq("build_daily_sales")
