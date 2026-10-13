{%- set mart = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET ~ '.mart_daily_sales' %}
ASSERT NOT EXISTS (SELECT 1 FROM `{{ mart }}` WHERE revenue < 0) AS 'negative revenue found'
