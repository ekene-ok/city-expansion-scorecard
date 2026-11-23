-- 03_city_demand.sql
-- Demand side: how big, how fast-growing and how valuable is each city?

CREATE OR REPLACE VIEW city_demand AS
WITH customer_orders AS (
    -- Orders per customer, used for the repeat-purchase rate.
    SELECT city, customer_unique_id, COUNT(*) AS n_orders
    FROM base_orders
    GROUP BY city, customer_unique_id
),
repeat_rate AS (
    SELECT city,
           AVG(CASE WHEN n_orders >= 2 THEN 1.0 ELSE 0.0 END) AS repeat_customer_rate
    FROM customer_orders
    GROUP BY city
)
SELECT b.city,
       ANY_VALUE(b.state)                                   AS state,
       COUNT(*)                                             AS delivered_orders,
       COUNT(DISTINCT b.customer_unique_id)                 AS customers,
       ROUND(SUM(v.gmv), 0)                                 AS gmv_brl,
       ROUND(AVG(v.gmv), 2)                                 AS avg_order_value_brl,
       -- Like-for-like growth: Jan to Aug 2018 vs Jan to Aug 2017.
       COUNT(*) FILTER (WHERE b.purchased_at >= '2017-01-01' AND b.purchased_at < '2017-09-01') AS orders_jan_aug_2017,
       COUNT(*) FILTER (WHERE b.purchased_at >= '2018-01-01' AND b.purchased_at < '2018-09-01') AS orders_jan_aug_2018,
       ROUND(COUNT(*) FILTER (WHERE b.purchased_at >= '2018-01-01' AND b.purchased_at < '2018-09-01')::DOUBLE
             / NULLIF(COUNT(*) FILTER (WHERE b.purchased_at >= '2017-01-01' AND b.purchased_at < '2017-09-01'), 0)
             - 1, 3)                                        AS yoy_growth,
       ROUND(ANY_VALUE(r.repeat_customer_rate), 4)          AS repeat_customer_rate
FROM base_orders b
LEFT JOIN order_value v USING (order_id)
LEFT JOIN repeat_rate r USING (city)
GROUP BY b.city;
