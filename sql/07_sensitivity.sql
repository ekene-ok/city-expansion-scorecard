-- 07_sensitivity.sql
-- Is the top 5 a real signal or an artefact of my chosen weights?
-- Re-score every city under four alternative weightings and count how often each
-- city lands in the top 5. A city that stays in the top 5 under most scenarios is a
-- robust pick; one that only appears under the base case needs a closer look.

CREATE OR REPLACE VIEW weight_scenarios AS
SELECT * FROM (VALUES
    ('base_case',        0.25, 0.20, 0.25, 0.20, 0.10),
    ('demand_first',     0.40, 0.20, 0.15, 0.15, 0.10),
    ('growth_first',     0.20, 0.40, 0.15, 0.15, 0.10),
    ('experience_first', 0.20, 0.10, 0.25, 0.35, 0.10),
    ('equal_weights',    0.20, 0.20, 0.20, 0.20, 0.20)
) AS t(scenario, w_demand, w_growth, w_supply_gap, w_delivery_pain, w_value);

CREATE OR REPLACE VIEW scenario_ranks AS
SELECT w.scenario, c.city,
       RANK() OVER (
           PARTITION BY w.scenario
           ORDER BY w.w_demand * c.s_demand
                  + w.w_growth * c.s_growth
                  + w.w_supply_gap * c.s_supply_gap
                  + w.w_delivery_pain * c.s_delivery_pain
                  + w.w_value * c.s_value DESC
       ) AS scenario_rank
FROM city_scorecard c
CROSS JOIN weight_scenarios w;

CREATE OR REPLACE VIEW sensitivity_summary AS
SELECT r.city,
       MAX(CASE WHEN scenario = 'base_case' THEN scenario_rank END)  AS base_rank,
       MIN(scenario_rank)                                            AS best_rank,
       MAX(scenario_rank)                                            AS worst_rank,
       COUNT(*) FILTER (WHERE scenario_rank <= 5)                    AS scenarios_in_top5,
       COUNT(*) FILTER (WHERE scenario_rank <= 10)                   AS scenarios_in_top10
FROM scenario_ranks r
GROUP BY r.city
HAVING MIN(scenario_rank) <= 10
ORDER BY scenarios_in_top5 DESC, base_rank;
