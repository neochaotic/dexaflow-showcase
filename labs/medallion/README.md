# Medallion lab: DuckDB to BigQuery

Generate a realistic volume of synthetic e-commerce events with DuckDB, load
them into BigQuery, and refine them through bronze, silver and gold layers. One
run processes one day.

```
create_dataset -> reset_bronze_day -> generate_shard x8 -> silver_events -> gold_daily_sales -> quality_checks
                                       (parallel pods)                     -> gold_funnel      ->
```

| Layer | Table | Content |
|---|---|---|
| Bronze | `bronze_events` | events exactly as generated, partitioned by day, with about 2.5% bad rows |
| Silver | `silver_events` | deduplicated, rows with a missing country or a negative quantity dropped, `revenue` computed |
| Gold | `gold_daily_sales` | purchases, buyers and revenue per day, country and category |
| Gold | `gold_funnel` | views, carts, purchases and conversion per day and channel |

## What it shows

- **Two kinds of tasks in one DAG**: Python tasks with their own dependencies
  (DuckDB, the BigQuery client) next to the stock Airflow BigQuery operators.
- **Fan-out on Kubernetes**: the eight `generate_shard` tasks run as eight pods
  at once. Each generates its slice in memory with DuckDB (about 500,000 rows
  in under a second), writes Parquet and loads it into BigQuery.
- **Idempotent days**: every step rewrites one day only, so re-running a day
  gives the same tables.
- **Data quality as code**: `quality_checks` fails the run if duplicates or bad
  rows reach silver.

## Run it

Set up the GKE environment first ([LAB.md, Part 1](../../LAB.md#part-1-set-up-gke-and-dexaflow-pro)), then:

```bash
make gke-lab
```

It deploys the lab and runs one day with the default volume, 8 x 500,000 = 4
million events. To go bigger, trigger the DAG from the UI with
**Trigger > rows_per_shard** (for example 2,500,000 for 20 million events).

The project and dataset come from the `GCP_PROJECT` and `LAB_DATASET`
Variables, like the BigQuery lab.

## Exercises

1. **Scale out.** Change `SHARDS` from 8 to 16 in `dag.py`, deploy with
   `make deploy DAG=labs/medallion DEXAFLOW_TARGET=gke`, and watch the cluster
   add nodes (`kubectl get nodes -w`).
2. **Add a bad-data rule.** Make the generator emit prices of 0 for some rows,
   then filter them in silver and add an `ASSERT` for it.
3. **New gold table.** Add `gold_top_products` (top 10 products by revenue per
   day) after `silver_events`.
4. **Break silver on purpose.** Remove the `QUALIFY` deduplication and watch
   `quality_checks` fail.

## Cost

At the default volume a day is about 80 MB of Parquet. Every BigQuery job is
capped at 5 GB billed. `make gke-down` deletes the dataset.
