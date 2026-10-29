"""showcase_bigquery_python: BigQuery from plain Python, no Airflow provider.

The task pod gets Application Default Credentials from Workload Identity, so the
client library needs no key and no connection. The query writes its result to
the dexaflow_showcase.top_github_languages table, and the rows travel to the
next task through XCom.
"""
from __future__ import annotations

import os

from airflow.sdk import DAG, task

MAX_BYTES_BILLED = 1_000_000_000  # 1 GB
DATASET = "dexaflow_showcase"
LOCATION = "US"  # where the public dataset lives
TABLE = "top_github_languages"


@task
def top_github_languages() -> list[dict]:
    from google.cloud import bigquery

    project = os.environ["AIRFLOW_VAR_GCP_PROJECT"]
    client = bigquery.Client(project=project)
    dataset = bigquery.Dataset(f"{project}.{DATASET}")
    dataset.location = LOCATION
    client.create_dataset(dataset, exists_ok=True)
    sql = """
        SELECT repository_language AS language, COUNT(*) AS repos
        FROM `bigquery-public-data.samples.github_timeline`
        WHERE repository_language IS NOT NULL
        GROUP BY language
        ORDER BY repos DESC
        LIMIT 10
    """
    config = bigquery.QueryJobConfig(
        destination=f"{project}.{DATASET}.{TABLE}",
        write_disposition="WRITE_TRUNCATE",
        maximum_bytes_billed=MAX_BYTES_BILLED,
    )
    job = client.query(sql, job_config=config)
    rows = [dict(r) for r in job.result()]
    print(f"job {job.job_id}: {job.total_bytes_processed} bytes processed, {len(rows)} rows in {DATASET}.{TABLE}")
    return rows


@task
def summarize(rows: list[dict]) -> str:
    lines = [f"{i + 1:>2}. {r['language']:<12} {r['repos']:>8}" for i, r in enumerate(rows)]
    print("Top languages in the GitHub timeline sample:\n" + "\n".join(lines))
    return rows[0]["language"]


with DAG("showcase_bigquery_python", schedule=None, catchup=False, tags=["showcase", "gcp"]):
    summarize(top_github_languages())
