"""lab_02_quality_checks: fail loudly when the mart looks wrong.

Each task runs one BigQuery `ASSERT` statement. A false assertion fails the
BigQuery job, so the task fails (and retries), exactly like a failed check in
Airflow. Exercise: break a rule on purpose and watch the failure in the UI.
"""
from __future__ import annotations

from datetime import timedelta

from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "{{ var.value.LAB_DATASET }}"
LOCATION = "US"
MART = f"`{PROJECT}.{DATASET}.mart_daily_sales`"

CHECKS = {
    "mart_not_empty": f"ASSERT (SELECT COUNT(*) FROM {MART}) > 0 AS 'mart_daily_sales is empty'",
    "no_negative_revenue": f"ASSERT NOT EXISTS (SELECT 1 FROM {MART} WHERE revenue < 0) AS 'negative revenue found'",
    "one_row_per_day_and_category": (
        f"ASSERT NOT EXISTS (SELECT order_date, category FROM {MART} "
        f"GROUP BY 1, 2 HAVING COUNT(*) > 1) AS 'duplicate rows in mart_daily_sales'"
    ),
}

with DAG(
    "lab_02_quality_checks",
    schedule=None,
    catchup=False,
    default_args={"retries": 1, "retry_delay": timedelta(seconds=30)},
    tags=["lab", "gcp"],
):
    for name, sql in CHECKS.items():
        BigQueryInsertJobOperator(
            task_id=name, project_id=PROJECT, location=LOCATION,
            configuration={"query": {"query": sql, "useLegacySql": False}},
        )
