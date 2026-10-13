-- Bronze: create the table once, then empty the day before the shards load it.
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

CREATE TABLE IF NOT EXISTS `{{ lab }}.bronze_events` (
  event_id STRING, event_ts TIMESTAMP, event_date DATE, user_id INT64,
  session_id STRING, event_type STRING, channel STRING, country STRING,
  category STRING, product_id INT64, quantity INT64, unit_price FLOAT64, shard INT64
)
PARTITION BY event_date;
DELETE FROM `{{ lab }}.bronze_events` WHERE event_date = DATE('{{ ds }}');
