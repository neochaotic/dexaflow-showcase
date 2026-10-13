SELECT COUNT(*) AS row_count, COUNT(DISTINCT decade) AS decades
FROM `{{ var.value.GCP_PROJECT }}.dexaflow_showcase.top_names_by_decade`
