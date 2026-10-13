-- Silver: typed, deduplicated, bad rows dropped, revenue computed.
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

CREATE TABLE IF NOT EXISTS `{{ lab }}.silver_events` (
  event_id STRING, event_ts TIMESTAMP, event_date DATE, user_id INT64, session_id STRING,
  event_type STRING, channel STRING, country STRING, category STRING, product_id INT64,
  quantity INT64, unit_price FLOAT64, revenue FLOAT64
)
PARTITION BY event_date;
DELETE FROM `{{ lab }}.silver_events` WHERE event_date = DATE('{{ ds }}');
INSERT INTO `{{ lab }}.silver_events`
SELECT event_id, event_ts, event_date, user_id, session_id, event_type, channel, country,
       category, product_id, quantity, unit_price,
       IF(event_type = 'purchase', ROUND(quantity * unit_price, 2), 0) AS revenue
FROM `{{ lab }}.bronze_events`
WHERE event_date = DATE('{{ ds }}')
  AND country IS NOT NULL
  AND quantity > 0
QUALIFY ROW_NUMBER() OVER (PARTITION BY event_id ORDER BY event_ts) = 1;
