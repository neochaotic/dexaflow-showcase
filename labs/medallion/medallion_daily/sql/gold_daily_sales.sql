-- Gold: purchases, buyers and revenue per day, country and category.
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

CREATE TABLE IF NOT EXISTS `{{ lab }}.gold_daily_sales` (
  event_date DATE, country STRING, category STRING, purchases INT64, buyers INT64, revenue FLOAT64
);
DELETE FROM `{{ lab }}.gold_daily_sales` WHERE event_date = DATE('{{ ds }}');
INSERT INTO `{{ lab }}.gold_daily_sales`
SELECT event_date, country, category, COUNT(*), COUNT(DISTINCT user_id), ROUND(SUM(revenue), 2)
FROM `{{ lab }}.silver_events`
WHERE event_date = DATE('{{ ds }}') AND event_type = 'purchase'
GROUP BY event_date, country, category;
