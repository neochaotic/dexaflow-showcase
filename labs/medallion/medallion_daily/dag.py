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
from pathlib import Path

from airflow.providers.google.cloud.operators.bigquery import (
    BigQueryCreateEmptyDatasetOperator,
    BigQueryInsertJobOperator,
)
from airflow.sdk import DAG, Param, task

PROJECT = "{{ var.value.GCP_PROJECT }}"
DATASET = "{{ var.value.LAB_DATASET }}"
LOCATION = "US"
SHARDS = 8
DEFAULT_ROWS_PER_SHARD = 500_000
MAX_BYTES_BILLED = str(5_000_000_000)  # 5 GB cap per BigQuery job
# The SQL lives in sql/ (shipped with the DAG through include_paths in
# dexaflow.yaml): BigQuery files are rendered by Airflow at run time, the DuckDB
# file is filled in by generate_shard.
SQL_DIR = Path(__file__).parent / "sql"


def sql(name: str) -> str:
    return (SQL_DIR / f"{name}.sql").read_text()


GENERATE_SQL = sql("generate_shard.duckdb")


def bq(task_id: str) -> BigQueryInsertJobOperator:
    return BigQueryInsertJobOperator(
        task_id=task_id, project_id=PROJECT, location=LOCATION,
        configuration={"query": {"query": sql(task_id), "useLegacySql": False,
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
    reset = bq("reset_bronze_day")
    shards = [generate_shard(n) for n in range(SHARDS)]
    silver = bq("silver_events")
    gold = [bq("gold_daily_sales"), bq("gold_funnel")]
    checks = bq("quality_checks")

    dataset >> reset >> shards
    for s in shards:
        s >> silver
    silver >> gold
    for g in gold:
        g >> checks
