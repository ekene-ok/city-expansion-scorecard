-- 02_base_orders.sql
-- One clean row per delivered order, with the customer's city attached.
-- City key = city + state, because some city names repeat across states.

CREATE OR REPLACE VIEW base_orders AS
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_city || ', ' || c.customer_state          AS city,
       c.customer_state                                     AS state,
       o.order_purchase_timestamp                           AS purchased_at,
       o.order_delivered_customer_date                      AS delivered_at,
       o.order_estimated_delivery_date                      AS estimated_at,
       DATE_DIFF('day', o.order_purchase_timestamp,
                        o.order_delivered_customer_date)    AS delivery_days,
       (o.order_delivered_customer_date
            > o.order_estimated_delivery_date)              AS is_late
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01';

-- Order value = item price + freight, summed per order.
CREATE OR REPLACE VIEW order_value AS
SELECT order_id,
       SUM(price)         AS item_value,
       SUM(freight_value) AS freight_value,
       SUM(price + freight_value) AS gmv
FROM order_items
GROUP BY order_id;

-- Average review per order (a few orders have more than one review).
CREATE OR REPLACE VIEW order_review AS
SELECT order_id, AVG(review_score) AS review_score
FROM order_reviews
GROUP BY order_id;
