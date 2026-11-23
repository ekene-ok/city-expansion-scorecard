-- 05_city_fulfilment.sql
-- Experience side: how slow, how often late, and how happy are customers today?
-- Slow, late, unhappy cities with strong demand are where a local launch adds the most.

CREATE OR REPLACE VIEW city_fulfilment AS
SELECT b.city,
       ROUND(AVG(b.delivery_days), 1)                                   AS avg_delivery_days,
       ROUND(MEDIAN(b.delivery_days), 1)                                AS median_delivery_days,
       ROUND(AVG(CASE WHEN b.is_late THEN 1.0 ELSE 0.0 END), 4)         AS late_rate,
       ROUND(AVG(r.review_score), 2)                                    AS avg_review_score,
       ROUND(AVG(v.freight_value / NULLIF(v.gmv, 0)), 4)                AS freight_share_of_gmv
FROM base_orders b
LEFT JOIN order_review r USING (order_id)
LEFT JOIN order_value  v USING (order_id)
GROUP BY b.city;
