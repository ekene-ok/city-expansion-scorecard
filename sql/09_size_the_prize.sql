-- 09_size_the_prize.sql
-- What is faster, local delivery worth? Order-level evidence, then a scenario for the five launch cities.

-- Reviews by delivery time: when does the experience break?
CREATE OR REPLACE VIEW review_by_delivery_time AS
SELECT CASE WHEN delivery_days <= 7  THEN '1. Up to 7 days'
            WHEN delivery_days <= 14 THEN '2. 8 to 14 days'
            WHEN delivery_days <= 21 THEN '3. 15 to 21 days'
            ELSE                          '4. 22 days or more' END            AS delivery_time,
       COUNT(*)                                                            AS orders,
       ROUND(AVG(r.review_score), 2)                                       AS avg_review_score,
       ROUND(AVG(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END), 4)      AS bad_review_rate
FROM base_orders b
JOIN order_review r USING (order_id)
GROUP BY 1
ORDER BY 1;

-- Late vs on-time within the same city, so city differences cannot explain the gap
CREATE OR REPLACE VIEW late_review_gap_within_city AS
WITH c AS (
    SELECT city, is_late, COUNT(*) AS n,
           AVG(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) AS bad
    FROM base_orders b JOIN order_review r USING (order_id)
    GROUP BY city, is_late
)
SELECT COUNT(*)                         AS cities_compared,
       ROUND(AVG(e.bad), 4)             AS bad_review_rate_on_time,
       ROUND(AVG(l.bad), 4)             AS bad_review_rate_late,
       ROUND(AVG(l.bad - e.bad), 4)     AS gap
FROM c l JOIN c e ON l.city = e.city AND l.is_late AND NOT e.is_late
WHERE l.n >= 20 AND e.n >= 50;

-- Does a late first order stop customers coming back? (first orders before March 2018, 180-day window)
CREATE OR REPLACE VIEW repeat_by_first_order AS
WITH f AS (SELECT customer_unique_id, MIN(purchased_at) AS first_at FROM base_orders GROUP BY 1),
fo AS (SELECT b.* FROM base_orders b JOIN f ON b.customer_unique_id = f.customer_unique_id
                                         AND b.purchased_at = f.first_at
       WHERE f.first_at < '2018-03-01')
SELECT fo.is_late                                     AS first_order_late,
       COUNT(*)                                       AS customers,
       ROUND(AVG(CASE WHEN EXISTS (
            SELECT 1 FROM base_orders b
            WHERE b.customer_unique_id = fo.customer_unique_id
              AND b.purchased_at >  fo.purchased_at + INTERVAL 1 DAY
              AND b.purchased_at <= fo.purchased_at + INTERVAL 180 DAY) THEN 1 ELSE 0 END), 4) AS repeat_rate_180d
FROM fo
GROUP BY 1
ORDER BY 1;

-- Same-state vs out-of-state orders: freight, speed, lateness and reviews
CREATE OR REPLACE VIEW same_state_effect AS
WITH oi AS (
    SELECT oi.order_id,
           BOOL_AND(s.seller_state = c.customer_state) AS same_state,
           SUM(oi.freight_value) AS freight
    FROM order_items oi
    JOIN orders o USING (order_id)
    JOIN customers c USING (customer_id)
    JOIN sellers s USING (seller_id)
    GROUP BY oi.order_id
)
SELECT oi.same_state,
       COUNT(*)                                                         AS orders,
       ROUND(AVG(oi.freight), 2)                                        AS freight_per_order_brl,
       ROUND(AVG(b.delivery_days), 1)                                   AS avg_delivery_days,
       ROUND(AVG(b.is_late::INT), 4)                                    AS late_rate,
       ROUND(AVG(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END), 4)   AS bad_review_rate
FROM base_orders b
JOIN oi USING (order_id)
JOIN order_review r USING (order_id)
GROUP BY oi.same_state
ORDER BY oi.same_state;

-- Scenario: shift 25% of each launch city's orders to same-state sellers (2018 run rate)
CREATE OR REPLACE VIEW launch_city_prize AS
WITH eff AS (
    SELECT MAX(freight_per_order_brl) FILTER (WHERE NOT same_state) - MAX(freight_per_order_brl) FILTER (WHERE same_state) AS freight_saved,
           MAX(avg_delivery_days) FILTER (WHERE NOT same_state) - MAX(avg_delivery_days) FILTER (WHERE same_state)        AS days_saved,
           MAX(bad_review_rate) FILTER (WHERE NOT same_state) - MAX(bad_review_rate) FILTER (WHERE same_state)            AS bad_review_cut
    FROM same_state_effect
),
cities AS (
    SELECT city, orders_jan_aug_2018 * 12.0 / 8 AS run_rate_orders, same_state_seller_share
    FROM city_metrics
    WHERE city IN ('goiania, GO', 'salvador, BA', 'brasilia, DF', 'fortaleza, CE', 'recife, PE')
)
SELECT c.city,
       ROUND(c.run_rate_orders)                                  AS orders_per_year_2018_run_rate,
       ROUND(c.same_state_seller_share, 3)                       AS same_state_share_today,
       ROUND(c.run_rate_orders * 0.25)                           AS orders_shifted,
       ROUND(c.run_rate_orders * 0.25 * e.freight_saved)         AS freight_saved_brl_per_year,
       ROUND(c.run_rate_orders * 0.25 * e.bad_review_cut)        AS bad_reviews_avoided_per_year,
       ROUND(e.days_saved, 1)                                    AS days_saved_per_shifted_order
FROM cities c CROSS JOIN eff e
ORDER BY orders_per_year_2018_run_rate DESC;
