-- 08_launch_waves.sql
-- Turn the ranking into a launch sequence. Wave 1 = robust top picks,
-- Wave 2 = strong but weight-sensitive, Wave 3 = monitor. Also flag each city's
-- main reason to launch, so the plan reads as a story rather than a score.
--
-- Launch mode: a city that is not the biggest market in its state can usually be
-- served as an extension of that state's anchor city (shared supply, couriers and
-- marketing), which is cheaper and faster than a standalone launch.

CREATE OR REPLACE VIEW launch_waves AS
WITH state_anchor AS (
    -- Biggest market in each state, using ALL cities (not only eligible ones).
    SELECT DISTINCT state,
           FIRST_VALUE(city) OVER (PARTITION BY state ORDER BY delivered_orders DESC) AS anchor_city
    FROM city_demand
),
joined AS (
    SELECT r.*, s.scenarios_in_top5, s.scenarios_in_top10
    FROM city_ranking r
    LEFT JOIN sensitivity_summary s USING (city)
)
SELECT j.launch_rank, j.city, j.launch_score,
       CASE
           WHEN j.launch_rank <= 5  AND j.scenarios_in_top5  >= 3 THEN 'Wave 1: launch next'
           WHEN j.launch_rank <= 10 AND j.scenarios_in_top10 >= 3 THEN 'Wave 2: prepare'
           WHEN j.launch_rank <= 15                             THEN 'Wave 3: monitor'
       END AS launch_wave,
       CASE WHEN a.anchor_city = j.city THEN 'Standalone launch'
            ELSE 'Extend from ' || a.anchor_city END                 AS launch_mode,
       -- The pillar where this city scores highest is its headline reason to launch.
       CASE GREATEST(j.s_demand, j.s_growth, j.s_supply_gap, j.s_delivery_pain, j.s_value)
           WHEN j.s_demand        THEN 'Large existing demand'
           WHEN j.s_growth        THEN 'Fastest-growing demand'
           WHEN j.s_supply_gap    THEN 'Underserved by local sellers'
           WHEN j.s_delivery_pain THEN 'Slow, unreliable delivery today'
           ELSE                      'High order value'
       END AS headline_reason,
       j.delivered_orders, j.yoy_growth, j.same_state_seller_share, j.avg_delivery_days,
       j.late_rate, j.avg_review_score, j.scenarios_in_top5
FROM joined j
JOIN city_metrics m USING (city)
JOIN state_anchor a ON a.state = m.state
WHERE j.launch_rank <= 15
ORDER BY j.launch_rank;
