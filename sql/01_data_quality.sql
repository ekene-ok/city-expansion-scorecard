-- 01_data_quality.sql
-- Sanity checks before any analysis. Each query is exported to results/ by the runner.

-- Q1: Order status mix. Only 'delivered' orders are used downstream,
-- because delivery time and lateness only exist for completed deliveries.
CREATE OR REPLACE VIEW dq_status_mix AS
SELECT order_status,
       COUNT(*)                                        AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_orders
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- Q2: Monthly order volume. Shows the usable window is Jan 2017 to Aug 2018
-- (late 2016 and Sep/Oct 2018 are near-empty), which sets the growth comparison periods.
CREATE OR REPLACE VIEW dq_monthly_volume AS
SELECT DATE_TRUNC('month', order_purchase_timestamp) AS month,
       COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1;

-- Q3: Delivered orders missing a delivery date (these are excluded from timing metrics).
CREATE OR REPLACE VIEW dq_missing_delivery_dates AS
SELECT COUNT(*) AS delivered_orders,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS missing_delivered_date
FROM orders
WHERE order_status = 'delivered';
