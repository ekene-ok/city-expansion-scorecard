-- 04_city_supply.sql
-- Supply side: how much of each city's demand is served by sellers in the same city?
-- A low local share means customers rely on far-away sellers. That is the gap a local
-- launch (seller recruitment plus local fulfilment) would close.

CREATE OR REPLACE VIEW city_supply AS
WITH item_locality AS (
    SELECT b.city,
           oi.seller_id,
           (s.seller_city || ', ' || s.seller_state) = b.city AS is_local_seller,
           s.seller_state = b.state                           AS is_same_state_seller
    FROM base_orders b
    JOIN order_items oi USING (order_id)
    JOIN sellers s USING (seller_id)
),
local_sellers AS (
    SELECT seller_city || ', ' || seller_state AS city,
           COUNT(*)                            AS sellers_based_in_city
    FROM sellers
    GROUP BY 1
)
SELECT il.city,
       COUNT(*)                                                     AS items_sold,
       ROUND(AVG(CASE WHEN il.is_local_seller THEN 1.0 ELSE 0.0 END), 4)      AS local_seller_share,
       ROUND(AVG(CASE WHEN il.is_same_state_seller THEN 1.0 ELSE 0.0 END), 4) AS same_state_seller_share,
       COALESCE(ANY_VALUE(ls.sellers_based_in_city), 0)             AS sellers_based_in_city
FROM item_locality il
LEFT JOIN local_sellers ls USING (city)
GROUP BY il.city;
