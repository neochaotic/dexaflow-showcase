"""showcase_modern_pandas: one half of the dependency isolation demo.

This DAG pins pandas==2.2.3 on Python 3.13. Its sibling pins pandas 1.x. In a single
Airflow image only one of them could be installed; here each DAG has its own image.
"""
from __future__ import annotations

import platform

from airflow.sdk import DAG, task


@task
def report_versions() -> dict:
    import pandas as pd

    df = pd.DataFrame({"team": ["a", "a", "b"], "points": [3, 4, 5]})
    by_team = df.groupby("team")["points"].sum().to_dict()
    versions = {"python": platform.python_version(), "pandas": pd.__version__}
    print(f"versions: {versions}  points by team: {by_team}")
    return versions


with DAG("showcase_modern_pandas", schedule=None, catchup=False, tags=["showcase"]):
    report_versions()
