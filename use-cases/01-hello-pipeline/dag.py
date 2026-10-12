"""showcase_hello_pipeline: the smallest real pipeline.

Three TaskFlow tasks, each in its own pod, passing data through XCom. This is a
plain Airflow 3 DAG: nothing in it is specific to Dexaflow.
"""
from __future__ import annotations

import time

from airflow.sdk import DAG, task


@task
def extract() -> list[dict]:
    rows = [{"city": c, "orders": n} for c, n in [("Lisbon", 12), ("Recife", 30), ("Porto", 7)]]
    print(f"extract: read {len(rows)} rows")
    time.sleep(2)
    return rows


@task
def transform(rows: list[dict]) -> dict:
    total = sum(r["orders"] for r in rows)
    top = max(rows, key=lambda r: r["orders"])["city"]
    print(f"transform: {total} orders, top city {top}")
    time.sleep(2)
    return {"total_orders": total, "top_city": top}


@task
def load(summary: dict) -> dict:
    print(f"load: writing {summary}")
    time.sleep(2)
    return summary


with DAG("showcase_hello_pipeline", schedule=None, catchup=False, tags=["showcase"]):
    load(transform(extract()))
