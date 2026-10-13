-- One day ({{ ds }}) of completed order lines, joined with products.
-- Delete-then-insert one day, so re-running a day is safe.
{%- set lab = var.value.GCP_PROJECT ~ '.' ~ var.value.LAB_DATASET %}

CREATE TABLE IF NOT EXISTS `{{ lab }}.stg_order_lines` (
  order_date DATE, order_id INT64, category STRING, brand STRING, sale_price FLOAT64
);
DELETE FROM `{{ lab }}.stg_order_lines` WHERE order_date = DATE('{{ ds }}');
INSERT INTO `{{ lab }}.stg_order_lines`
SELECT DATE(oi.created_at), oi.order_id, p.category, p.brand, oi.sale_price
FROM `{{ lab }}.raw_order_items` AS oi
JOIN `{{ lab }}.raw_products` AS p ON p.id = oi.product_id
WHERE oi.status = 'Complete' AND DATE(oi.created_at) = DATE('{{ ds }}');
