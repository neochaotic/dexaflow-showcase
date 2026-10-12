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

from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
# durable=False: the Dexaflow 0.5.2 runtime does not support the provider's
# resumable-job path yet (its task instance lacks `stats_tags`).
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "{{ var.value.LAB_DATASET }}"
LOCATION = "US"
MAX_BYTES_BILLED = str(1_000_000_000)
T = f"`{PROJECT}.{DATASET}"  # table prefix, closed with the table name and a backtick

STAGE_SQL = f"""
CREATE TABLE IF NOT EXISTS {T}.stg_order_lines` (
  order_date DATE, order_id INT64, category STRING, brand STRING, sale_price FLOAT64
);
DELETE FROM {T}.stg_order_lines` WHERE order_date = DATE('{{{{ ds }}}}');
INSERT INTO {T}.stg_order_lines`
SELECT DATE(oi.created_at), oi.order_id, p.category, p.brand, oi.sale_price
FROM {T}.raw_order_items` AS oi
JOIN {T}.raw_products` AS p ON p.id = oi.product_id
WHERE oi.status = 'Complete' AND DATE(oi.created_at) = DATE('{{{{ ds }}}}');
"""

MART_SQL = f"""
CREATE TABLE IF NOT EXISTS {T}.mart_daily_sales` (
  order_date DATE, category STRING, orders INT64, revenue FLOAT64
);
DELETE FROM {T}.mart_daily_sales` WHERE order_date = DATE('{{{{ ds }}}}');
INSERT INTO {T}.mart_daily_sales`
SELECT order_date, category, COUNT(DISTINCT order_id), ROUND(SUM(sale_price), 2)
FROM {T}.stg_order_lines`
WHERE order_date = DATE('{{{{ ds }}}}')
GROUP BY order_date, category;
"""


def bq(task_id: str, sql: str) -> BigQueryInsertJobOperator:
    return BigQueryInsertJobOperator(
        durable=False,
        task_id=task_id, project_id=PROJECT, location=LOCATION,
        configuration={"query": {"query": sql, "useLegacySql": False,
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
    bq("stage_order_lines", STAGE_SQL) >> bq("build_daily_sales", MART_SQL)
