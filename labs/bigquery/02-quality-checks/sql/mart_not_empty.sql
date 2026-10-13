{%- set mart = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET ~ '.mart_daily_sales' %}
ASSERT (SELECT COUNT(*) FROM `{{ mart }}`) > 0 AS 'mart_daily_sales is empty'
