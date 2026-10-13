-- DuckDB SQL that generates one shard of one day. The rows, shard and ds placeholders are
-- filled in by Python (str.format), not by Airflow. About 2.5% of rows are
-- deliberately broken (1% negative quantity, 1% missing country, 0.5%
-- duplicated event_id) so the silver layer has real work to do.

WITH base AS (
  SELECT
    i,
    (hash(i, {shard}, '{ds}') >> 1)::BIGINT AS h
  FROM range({rows}) t(i)
)
SELECT
  CASE WHEN h % 200 = 0 AND i > 0 THEN '{ds}-{shard}-' || (i - 1)    -- duplicate of the previous event
       ELSE '{ds}-{shard}-' || i END                                       AS event_id,
  TIMESTAMP '{ds}' + to_microseconds((h % 86400000000)::BIGINT)           AS event_ts,
  DATE '{ds}'                                                              AS event_date,
  (h % 200000)::BIGINT                                                     AS user_id,
  '{ds}-' || (h % 900000)                                                  AS session_id,
  ['view','view','view','view','view','cart','cart','purchase'][1 + (h // 7) % 8] AS event_type,
  ['web','app','email','ads'][1 + (h // 11) % 4]                           AS channel,
  CASE WHEN h % 100 = 1 THEN NULL
       ELSE ['BR','US','PT','MX','DE','IN','JP','AR'][1 + (h // 13) % 8] END AS country,
  ['shoes','jeans','tops','dresses','outerwear','accessories'][1 + (h // 17) % 6] AS category,
  (h // 19 % 5000)::BIGINT                                                 AS product_id,
  CASE WHEN h % 100 = 2 THEN -1 ELSE 1 + (h // 23) % 4 END::BIGINT         AS quantity,
  round(5 + ((h // 29) % 19500) / 100.0, 2)                               AS unit_price,
  {shard}::BIGINT                                                          AS shard
FROM base
