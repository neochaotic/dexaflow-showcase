"""lab_medallion_daily: synthetic data, three layers, one day per run.

    reset_bronze_day -> generate_shard x8 (parallel pods) -> silver_events -> gold_* -> checks

Bronze  `bronze_events`   raw events as generated, including ~1% bad rows
Silver  `silver_events`   typed, deduplicated, bad rows dropped, revenue computed
Gold    `gold_daily_sales` revenue and orders per day, country and category
        `gold_funnel`      views -> carts -> purchases per day and channel

Each `generate_shard` task is its own pod: DuckDB generates its slice of the
day in memory, writes Parquet, and loads it into the day's bronze partition.
Volume per run = SHARDS x rows_per_shard (default 8 x 500,000 = 4M events);
set `rows_per_shard` in the trigger dialog to go bigger.

Every step rewrites one day only, so re-running a day is safe.
"""
from __future__ import annotations

from datetime import datetime

from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)
# durable=False: the Dexaflow 0.5.2 runtime does not support the provider's
# resumable-job path yet (its task instance lacks `stats_tags`).
from airflow.sdk import DAG, Param, task

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "{{ var.value.LAB_DATASET }}"
LOCATION = "US"
SHARDS = 8
DEFAULT_ROWS_PER_SHARD = 500_000
MAX_BYTES_BILLED = str(5_000_000_000)  # 5 GB cap per BigQuery job
T = f"`{PROJECT}.{DATASET}"  # table prefix, closed with the table name and a backtick

BRONZE_DDL = f"""
CREATE TABLE IF NOT EXISTS {T}.bronze_events` (
  event_id STRING, event_ts TIMESTAMP, event_date DATE, user_id INT64,
  session_id STRING, event_type STRING, channel STRING, country STRING,
  category STRING, product_id INT64, quantity INT64, unit_price FLOAT64, shard INT64
)
PARTITION BY event_date;
DELETE FROM {T}.bronze_events` WHERE event_date = DATE('{{{{ ds }}}}');
"""

# DuckDB SQL that generates one shard of one day. Placeholders are filled in
# Python. About 2.5% of rows are deliberately broken (1% negative quantity,
# 1% missing country, 0.5% duplicated event_id) so the silver layer has real work to do.
GENERATE_SQL = """
WITH base AS (
  SELECT
    i,
    (hash(i, {shard}, '{ds}') >> 1)::BIGINT AS h
  FROM range({rows}) t(i)
)
SELECT
  CASE WHEN h % 200 = 0 AND i > 0 THEN '{ds}-{shard}-' || (i - 1)    -- duplicate of the previous event
       ELSE '{ds}-{shard}-' || i END                                       AS event_id,
  TIMESTAMP '{ds}' + to_microseconds((h % 86400000000)::BIGINT)           AS event_ts,
  DATE '{ds}'                                                              AS event_date,
  (h % 200000)::BIGINT                                                     AS user_id,
  '{ds}-' || (h % 900000)                                                  AS session_id,
  ['view','view','view','view','view','cart','cart','purchase'][1 + (h // 7) % 8] AS event_type,
  ['web','app','email','ads'][1 + (h // 11) % 4]                           AS channel,
  CASE WHEN h % 100 = 1 THEN NULL
       ELSE ['BR','US','PT','MX','DE','IN','JP','AR'][1 + (h // 13) % 8] END AS country,
  ['shoes','jeans','tops','dresses','outerwear','accessories'][1 + (h // 17) % 6] AS category,
  (h // 19 % 5000)::BIGINT                                                 AS product_id,
  CASE WHEN h % 100 = 2 THEN -1 ELSE 1 + (h // 23) % 4 END::BIGINT         AS quantity,
  round(5 + ((h // 29) % 19500) / 100.0, 2)                               AS unit_price,
  {shard}::BIGINT                                                          AS shard
FROM base
"""

SILVER_SQL = f"""
CREATE TABLE IF NOT EXISTS {T}.silver_events` (
  event_id STRING, event_ts TIMESTAMP, event_date DATE, user_id INT64, session_id STRING,
  event_type STRING, channel STRING, country STRING, category STRING, product_id INT64,
  quantity INT64, unit_price FLOAT64, revenue FLOAT64
)
PARTITION BY event_date;
DELETE FROM {T}.silver_events` WHERE event_date = DATE('{{{{ ds }}}}');
INSERT INTO {T}.silver_events`
SELECT event_id, event_ts, event_date, user_id, session_id, event_type, channel, country,
       category, product_id, quantity, unit_price,
       IF(event_type = 'purchase', ROUND(quantity * unit_price, 2), 0) AS revenue
FROM {T}.bronze_events`
WHERE event_date = DATE('{{{{ ds }}}}')
  AND country IS NOT NULL
  AND quantity > 0
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_ts) = 1;
"""

GOLD_SALES_SQL = f"""
CREATE TABLE IF NOT EXISTS {T}.gold_daily_sales` (
  event_date DATE, country STRING, category STRING, purchases INT64, buyers INT64, revenue FLOAT64
);
DELETE FROM {T}.gold_daily_sales` WHERE event_date = DATE('{{{{ ds }}}}');
INSERT INTO {T}.gold_daily_sales`
SELECT event_date, country, category, COUNT(*), COUNT(DISTINCT user_id), ROUND(SUM(revenue), 2)
FROM {T}.silver_events`
WHERE event_date = DATE('{{{{ ds }}}}') AND event_type = 'purchase'
GROUP BY event_date, country, category;
"""

GOLD_FUNNEL_SQL = f"""
CREATE TABLE IF NOT EXISTS {T}.gold_funnel` (
  event_date DATE, channel STRING, views INT64, carts INT64, purchases INT64,
  view_to_purchase_pct FLOAT64
);
DELETE FROM {T}.gold_funnel` WHERE event_date = DATE('{{{{ ds }}}}');
INSERT INTO {T}.gold_funnel`
SELECT event_date, channel,
       COUNTIF(event_type = 'view'), COUNTIF(event_type = 'cart'), COUNTIF(event_type = 'purchase'),
       ROUND(100 * SAFE_DIVIDE(COUNTIF(event_type = 'purchase'), COUNTIF(event_type = 'view')), 2)
FROM {T}.silver_events`
WHERE event_date = DATE('{{{{ ds }}}}')
GROUP BY event_date, channel;
"""

CHECKS_SQL = f"""
ASSERT (SELECT COUNT(*) FROM {T}.silver_events` WHERE event_date = DATE('{{{{ ds }}}}')) > 0
  AS 'silver is empty for {{{{ ds }}}}';
ASSERT NOT EXISTS (
  SELECT event_id FROM {T}.silver_events` WHERE event_date = DATE('{{{{ ds }}}}')
  GROUP BY event_id HAVING COUNT(*) > 1
) AS 'duplicate event_id in silver';
ASSERT (SELECT COUNTIF(quantity <= 0 OR country IS NULL) FROM {T}.silver_events`
        WHERE event_date = DATE('{{{{ ds }}}}')) = 0
  AS 'bad rows leaked into silver';
"""


def bq(task_id: str, sql: str) -> BigQueryInsertJobOperator:
    return BigQueryInsertJobOperator(
        durable=False,
        task_id=task_id, project_id=PROJECT, location=LOCATION,
        configuration={"query": {"query": sql, "useLegacySql": False,
                                 "maximumBytesBilled": MAX_BYTES_BILLED}},
    )


@task
def generate_shard(shard: int, ds=None, params=None, var=None) -> dict:
    """Generate one shard of the day with DuckDB and append it to bronze."""
    import os
    import time

    import duckdb
    from google.cloud import bigquery

    rows = int((params or {}).get("rows_per_shard", DEFAULT_ROWS_PER_SHARD))
    project = os.environ["AIRFLOW_VAR_GCP_PROJECT"]
    dataset = os.environ["AIRFLOW_VAR_LAB_DATASET"]
    path = f"/tmp/bronze_{ds}_{shard}.parquet"

    started = time.monotonic()
    con = duckdb.connect()
    con.execute(f"COPY ({GENERATE_SQL.format(rows=rows, shard=shard, ds=ds)}) "
                f"TO '{path}' (FORMAT parquet, COMPRESSION zstd)")
    size_mb = os.path.getsize(path) / 1e6
    print(f"shard {shard}: generated {rows:,} rows for {ds} in "
          f"{time.monotonic() - started:.1f}s ({size_mb:.1f} MB parquet)")

    client = bigquery.Client(project=project)
    job_config = bigquery.LoadJobConfig(
        source_format=bigquery.SourceFormat.PARQUET,
        write_disposition=bigquery.WriteDisposition.WRITE_APPEND,
    )
    table = f"{project}.{dataset}.bronze_events"
    with open(path, "rb") as fh:
        job = client.load_table_from_file(fh, table, job_config=job_config)
    job.result()
    print(f"shard {shard}: loaded into {table} (job {job.job_id})")
    return {"shard": shard, "rows": rows, "parquet_mb": round(size_mb, 1)}


with DAG(
    "lab_medallion_daily",
    schedule="@daily",
    start_date=datetime(2026, 10, 1),
    catchup=False,
    max_active_runs=1,
    params={"rows_per_shard": Param(DEFAULT_ROWS_PER_SHARD, type="integer", minimum=1000,
                                    title="Rows per shard")},
    tags=["lab", "gcp"],
):
    dataset = BigQueryCreateEmptyDatasetOperator(
        task_id="create_dataset", project_id=PROJECT, dataset_id=DATASET,
        location=LOCATION, if_exists="ignore",
    )
    reset = bq("reset_bronze_day", BRONZE_DDL)
    shards = [generate_shard(n) for n in range(SHARDS)]
    silver = bq("silver_events", SILVER_SQL)
    gold = [bq("gold_daily_sales", GOLD_SALES_SQL), bq("gold_funnel", GOLD_FUNNEL_SQL)]
    checks = bq("quality_checks", CHECKS_SQL)

    dataset >> reset >> shards
    for s in shards:
        s >> silver
    silver >> gold
    for g in gold:
        g >> checks
