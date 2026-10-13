-- Gold: views -> carts -> purchases per day and channel.
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

CREATE TABLE IF NOT EXISTS `{{ lab }}.gold_funnel` (
  event_date DATE, channel STRING, views INT64, carts INT64, purchases INT64,
  view_to_purchase_pct FLOAT64
);
DELETE FROM `{{ lab }}.gold_funnel` WHERE event_date = DATE('{{ ds }}');
INSERT INTO `{{ lab }}.gold_funnel`
SELECT event_date, channel,
       COUNTIF(event_type = 'view'), COUNTIF(event_type = 'cart'), COUNTIF(event_type = 'purchase'),
       ROUND(100 * SAFE_DIVIDE(COUNTIF(event_type = 'purchase'), COUNTIF(event_type = 'view')), 2)
FROM `{{ lab }}.silver_events`
WHERE event_date = DATE('{{ ds }}')
GROUP BY event_date, channel;
