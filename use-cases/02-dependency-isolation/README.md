# 02: Dependency isolation

**Shows:** two DAGs with conflicting requirements running side by side on the
same control plane.

| DAG | Python | pandas |
|---|---|---|
| `showcase_legacy_pandas` | 3.11 | 1.5.3 |
| `showcase_modern_pandas` | 3.13 | 2.2.3 |

In Airflow both DAGs share one worker image, so one of them has to give in.
Dexaflow builds one image per DAG from its `dexaflow.yaml`, so neither does.

**Run:** `make demo USE_CASE=02-dependency-isolation`

**What to look at:** the XCom of each `report_versions` task, and the two image
tags in your registry (`docker images | grep pandas` locally).
