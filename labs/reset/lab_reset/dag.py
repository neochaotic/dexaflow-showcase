"""lab_reset: empty the lab's BigQuery datasets, to start the lab from zero.

Deletes every table in the LAB_DATASET Variable's dataset (the BigQuery and
medallion labs) and in dexaflow_showcase (the use cases). The datasets stay,
empty: the lab DAGs create their tables again on their next run. Trigger it
from the UI; it never runs on a schedule.
"""
from __future__ import annotations

import os

from airflow.sdk import DAG, task

SHOWCASE_DATASET = "dexaflow_showcase"


@task
def empty_datasets() -> dict:
    from google.cloud import bigquery

    project = os.environ["AIRFLOW_VAR_GCP_PROJECT"]
    client = bigquery.Client(project=project)
    deleted = {}
    for name in (os.environ["AIRFLOW_VAR_LAB_DATASET"], SHOWCASE_DATASET):
        tables = list(client.list_tables(f"{project}.{name}")) if _exists(client, project, name) else []
        for table in tables:
            client.delete_table(table, not_found_ok=True)
        deleted[name] = len(tables)
        print(f"{name}: deleted {len(tables)} tables")
    return deleted


def _exists(client, project: str, name: str) -> bool:
    from google.api_core.exceptions import NotFound

    try:
        client.get_dataset(f"{project}.{name}")
        return True
    except NotFound:
        print(f"{name}: no such dataset, nothing to delete")
        return False


with DAG("lab_reset", schedule=None, catchup=False, tags=["lab", "gcp"]):
    empty_datasets()
