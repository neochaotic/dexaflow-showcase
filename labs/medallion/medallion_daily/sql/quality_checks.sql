-- Fails the task when silver is empty, has duplicates or kept bad rows.
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

ASSERT (SELECT COUNT(*) FROM `{{ lab }}.silver_events` WHERE event_date = DATE('{{ ds }}')) > 0
  AS 'silver is empty for {{ ds }}';
ASSERT NOT EXISTS (
  SELECT event_id FROM `{{ lab }}.silver_events` WHERE event_date = DATE('{{ ds }}')
  GROUP BY event_id HAVING COUNT(*) > 1
) AS 'duplicate event_id in silver';
ASSERT (SELECT COUNTIF(quantity <= 0 OR country IS NULL) FROM `{{ lab }}.silver_events`
        WHERE event_date = DATE('{{ ds }}')) = 0
  AS 'bad rows leaked into silver';
