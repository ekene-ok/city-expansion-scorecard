-- 06_scorecard.sql
-- Combine demand, supply and fulfilment into one ranked scorecard.
--
-- Method: convert each metric to a 0 to 1 percentile rank across eligible cities
-- (PERCENT_RANK), flip the direction where "lower is better for us", then take a
-- weighted average. Percentile ranks keep one extreme city from dominating the score.
--
-- Eligibility: 200+ delivered orders, so every metric rests on a meaningful sample.
--
-- Base-case weights (sum to 1.0):
--   demand scale 0.25 | growth 0.20 | regional supply gap 0.25 | delivery pain 0.20 | order value 0.10
--
-- Supply gap uses the SAME-STATE seller share. Same-city share is near zero almost
-- everywhere (median 0.5%), so it cannot separate cities; same-state share captures
-- whether a region already has nearby supply (e.g. Sao Paulo suburbs at ~80%).

CREATE OR REPLACE VIEW city_metrics AS
SELECT d.*,
       s.items_sold, s.local_seller_share, s.same_state_seller_share, s.sellers_based_in_city,
       f.avg_delivery_days, f.median_delivery_days, f.late_rate, f.avg_review_score, f.freight_share_of_gmv
FROM city_demand d
JOIN city_supply     s USING (city)
JOIN city_fulfilment f USING (city)
WHERE d.delivered_orders >= 200;

CREATE OR REPLACE VIEW city_pillar_scores AS
SELECT city, state, delivered_orders, customers, gmv_brl, avg_order_value_brl, yoy_growth,
       local_seller_share, same_state_seller_share, sellers_based_in_city,
       avg_delivery_days, late_rate, avg_review_score,
       -- Higher is better for a launch:
       PERCENT_RANK() OVER (ORDER BY delivered_orders)          AS s_demand,
       PERCENT_RANK() OVER (ORDER BY yoy_growth)                AS s_growth,
       PERCENT_RANK() OVER (ORDER BY avg_order_value_brl)       AS s_value,
       -- Lower same-state share = bigger supply gap = more launch upside.
       -- 1 - PERCENT_RANK (rather than ORDER BY ... DESC) so tied cities at 0% share
       -- all receive the full score of 1.0 instead of the bottom of the tie group.
       1 - PERCENT_RANK() OVER (ORDER BY same_state_seller_share) AS s_supply_gap,
       -- Delivery pain blends speed and reliability equally:
       (PERCENT_RANK() OVER (ORDER BY avg_delivery_days)
        + PERCENT_RANK() OVER (ORDER BY late_rate)) / 2.0       AS s_delivery_pain
FROM city_metrics;

CREATE OR REPLACE VIEW city_scorecard AS
SELECT *,
       ROUND(100 * (0.25 * s_demand
                  + 0.20 * s_growth
                  + 0.25 * s_supply_gap
                  + 0.20 * s_delivery_pain
                  + 0.10 * s_value), 1)                         AS launch_score
FROM city_pillar_scores;

CREATE OR REPLACE VIEW city_ranking AS
SELECT RANK() OVER (ORDER BY launch_score DESC) AS launch_rank,
       city, launch_score,
       delivered_orders, yoy_growth, avg_order_value_brl,
       same_state_seller_share, local_seller_share, sellers_based_in_city,
       avg_delivery_days, late_rate, avg_review_score,
       ROUND(s_demand, 2) AS s_demand, ROUND(s_growth, 2) AS s_growth,
       ROUND(s_supply_gap, 2) AS s_supply_gap, ROUND(s_delivery_pain, 2) AS s_delivery_pain,
       ROUND(s_value, 2) AS s_value
FROM city_scorecard
ORDER BY launch_rank;
