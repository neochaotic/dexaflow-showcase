{%- set mart = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET ~ '.mart_daily_sales' %}
ASSERT NOT EXISTS (
  SELECT order_date, category FROM `{{ mart }}` GROUP BY 1, 2 HAVING COUNT(*) > 1
) AS 'duplicate rows in mart_daily_sales'
