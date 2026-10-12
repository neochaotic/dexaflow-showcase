# BigQuery lab

A hands-on lab: build a small daily ELT on BigQuery with Dexaflow Pro, then
change it the way you would change any Airflow DAG.

The data is `bigquery-public-data.thelook_ecommerce`, a public, regularly
refreshed dataset of a fictional clothing shop. The lab copies four of its
tables into your own dataset, so you can break things freely.

| DAG | What it does |
|---|---|
| [`lab_00_setup`](00-setup/dag.py) | creates the dataset and copies `orders`, `order_items`, `products`, `users` as `raw_*` tables |
| [`lab_01_daily_sales`](01-daily-sales/dag.py) | `@daily`: one day of raw data into `stg_order_lines`, then into `mart_daily_sales` |
| [`lab_02_quality_checks`](02-quality-checks/dag.py) | `ASSERT` checks on the mart; a failed check fails the task |

## 1. Get your own environment

Follow Part 1 of [LAB.md](../../LAB.md#part-1-set-up-gke-and-dexaflow-pro): it
creates the GKE cluster and Dexaflow Pro in your project, step by step, and
opens the UI on <http://localhost:8081> with `make gke-ui`.

## 2. Set your variables

The DAGs never hardcode a project or dataset. They read two Variables:

| Variable | Default | Meaning |
|---|---|---|
| `GCP_PROJECT` | your gcloud project | where BigQuery jobs run and where the dataset lives |
| `LAB_DATASET` | `dexaflow_lab` | the lab dataset |

`make gke-lab` creates them when they do not exist yet. Change them later in
the UI (**Admin > Variables**); later deploys keep your value. No redeploy is
needed: Variables are read at run time.

## 3. Run it

```bash
make gke-lab
```

This deploys the three DAGs and runs `lab_00_setup`. When it is green, trigger
`lab_01_daily_sales` from the UI, then `lab_02_quality_checks`.

## Exercises

Every change follows the same loop: **edit `dag.py`, then
`make deploy DAG=<folder>`**. Dexaflow builds a new image for that DAG only,
registers it, and the UI shows the new version.

1. **Add a column.** In `01-daily-sales/dag.py`, add `brand_count` (distinct
   brands) to `mart_daily_sales`. Drop the table in BigQuery first, or add the
   column with `ALTER TABLE`. Deploy with
   `make deploy DAG=labs/bigquery/01-daily-sales DEXAFLOW_TARGET=gke`.
2. **Re-run a past day.** In the UI, open `lab_01_daily_sales`, choose
   **Trigger**, and set the logical date to a day last week. The run processes
   only that day, and running it twice gives the same result. (The Backfill
   screen is not wired up yet in Dexaflow 0.5.3.)
3. **Break a check.** In `02-quality-checks/dag.py`, change a rule so it fails
   (for example `revenue < 1000000`). Deploy, trigger, and read the failure and
   the retry in the task logs.
4. **Add a task.** Add a `top_brands` table built from `stg_order_lines` after
   `stage_order_lines`, in parallel with `build_daily_sales`.
5. **Write your own DAG.** `make workspace` creates your own DAG folder next to
   this clone; there, `make new NAME=my_first_dag` scaffolds one and
   `make deploy DAG=dags/my_first_dag TRIGGER=1` deploys and runs it
   ([LAB.md, Part 2](../../LAB.md#part-2-write-and-deploy-dags)).

## Cost

All queries scan small tables (the whole `thelook_ecommerce` dataset is a few
hundred MB), and each job is capped at 1 GB billed. `make gke-down` deletes the
lab dataset with everything else.
