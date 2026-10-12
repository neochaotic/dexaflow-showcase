"""showcase_fan_out: fan out to parallel workers, fan in to one reducer.

Each worker estimates pi with Monte Carlo sampling in its own pod; the reducer
averages them. Raise WORKERS to watch the cluster autoscaler add nodes on GKE.
"""
from __future__ import annotations

import random

from airflow.sdk import DAG, task

WORKERS = 16
SAMPLES = 2_000_000


@task
def estimate(worker: int) -> float:
    rng = random.Random(worker)
    inside = sum(1 for _ in range(SAMPLES) if rng.random() ** 2 + rng.random() ** 2 <= 1.0)
    value = 4 * inside / SAMPLES
    print(f"worker {worker}: pi ~ {value:.6f}")
    return value


@task
def combine(values: list[float]) -> dict:
    pi = sum(values) / len(values)
    print(f"combined {len(values)} workers: pi ~ {pi:.6f}")
    return {"workers": len(values), "pi": round(pi, 6)}


with DAG("showcase_fan_out", schedule=None, catchup=False, tags=["showcase"]):
    # Calling the same @task several times gives estimate, estimate__1, ... as in Airflow.
    # (`estimate.override(task_id=...)` would read better but the Dexaflow 0.5.3
    # parser does not support it yet.)
    combine([estimate(n) for n in range(WORKERS)])
