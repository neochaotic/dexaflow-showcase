-- The 5 most popular US baby names per decade, from a public dataset.
-- Rendered by Airflow at run time: {{ var.value.GCP_PROJECT }} is the project Variable.
CREATE OR REPLACE TABLE `{{ var.value.GCP_PROJECT }}.dexaflow_showcase.top_names_by_decade` AS
SELECT decade, name, total
FROM (
  SELECT decade, name, total,
         ROW_NUMBER() OVER (PARTITION BY decade ORDER BY total DESC) AS rank
  FROM (
    SELECT DIV(year, 10) * 10 AS decade, name, SUM(number) AS total
    FROM `bigquery-public-data.usa_names.usa_1910_current`
    GROUP BY decade, name
  )
)
WHERE rank <= 5
