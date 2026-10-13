-- Orders and revenue per category for one day ({{ ds }}).
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

CREATE TABLE IF NOT EXISTS `{{ lab }}.mart_daily_sales` (
  order_date DATE, category STRING, orders INT64, revenue FLOAT64
);
DELETE FROM `{{ lab }}.mart_daily_sales` WHERE order_date = DATE('{{ ds }}');
INSERT INTO `{{ lab }}.mart_daily_sales`
SELECT order_date, category, COUNT(DISTINCT order_id), ROUND(SUM(sale_price), 2)
FROM `{{ lab }}.stg_order_lines`
WHERE order_date = DATE('{{ ds }}')
GROUP BY order_date, category;
