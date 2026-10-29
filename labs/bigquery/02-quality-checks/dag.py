"""lab_02_quality_checks: fail loudly when the mart looks wrong.

Each task runs one BigQuery `ASSERT` statement. A false assertion fails the
BigQuery job, so the task fails (and retries), exactly like a failed check in
Airflow. Exercise: break a rule on purpose and watch the failure in the UI.
"""
from __future__ import annotations

from datetime import timedelta
from pathlib import Path

from airflow.providers.google.cloud.operators.bigquery import BigQueryInsertJobOperator
from airflow.sdk import DAG

PROJECT = "{{ var.value.GCP_PROJECT }}"
LOCATION = "US"
# One check per file in sql/ (shipped through include_paths in dexaflow.yaml):
# add a file, get a task.
SQL_DIR = Path(__file__).parent / "sql"
CHECKS = {path.stem: path.read_text() for path in sorted(SQL_DIR.glob("*.sql"))}

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
