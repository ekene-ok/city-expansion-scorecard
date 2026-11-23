-- 00_load.sql
-- Load the raw Olist CSVs into DuckDB tables.
-- Source: https://github.com/olist/work-at-olist-data (MIT License)
-- Run scripts/get_data.sh first so the CSVs exist in data/raw/.

CREATE OR REPLACE TABLE orders AS
SELECT * FROM read_csv_auto('data/raw/olist_orders_dataset.csv');

CREATE OR REPLACE TABLE customers AS
SELECT * FROM read_csv_auto('data/raw/olist_customers_dataset.csv');

CREATE OR REPLACE TABLE sellers AS
SELECT * FROM read_csv_auto('data/raw/olist_sellers_dataset.csv');

CREATE OR REPLACE TABLE order_items AS
SELECT * FROM read_csv_auto('data/raw/olist_order_items_dataset.csv');

CREATE OR REPLACE TABLE order_reviews AS
SELECT * FROM read_csv_auto('data/raw/olist_order_reviews_dataset.csv');
