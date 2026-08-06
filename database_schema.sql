


-- =========================================================
-- OLIST BRAZILIAN E-COMMERCE DATASET
-- Full CREATE TABLE script (PostgreSQL syntax)
-- Includes: core e-commerce tables + marketing funnel tables
-- =========================================================

-- Drop tables if re-running (safe re-run)
DROP TABLE IF EXISTS order_reviews CASCADE;
DROP TABLE IF EXISTS order_payments CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS sellers CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS geolocation CASCADE;
DROP TABLE IF EXISTS product_category_name_translation CASCADE;
DROP TABLE IF EXISTS marketing_qualified_leads CASCADE;
DROP TABLE IF EXISTS closed_deals CASCADE;

-- =========================================================
-- 1. CUSTOMERS
-- Note: customer_id is unique PER ORDER.
-- customer_unique_id identifies the actual PERSON across orders.
-- Use customer_unique_id for any retention/cohort/repeat-purchase analysis.
-- =========================================================
CREATE TABLE customers (
    customer_id             VARCHAR(32) PRIMARY KEY,
    customer_unique_id      VARCHAR(32) NOT NULL,
    customer_zip_code_prefix VARCHAR(5),
    customer_city           VARCHAR(60),
    customer_state          VARCHAR(2)
);

-- =========================================================
-- 2. SELLERS
-- =========================================================
CREATE TABLE sellers (
    seller_id             VARCHAR(32) PRIMARY KEY,
    seller_zip_code_prefix VARCHAR(5),
    seller_city            VARCHAR(60),
    seller_state           VARCHAR(2)
);

-- =========================================================
-- 3. PRODUCT CATEGORY NAME TRANSLATION (PT -> EN)
-- =========================================================
CREATE TABLE product_category_name_translation (
    product_category_name          VARCHAR(60) PRIMARY KEY,
    product_category_name_english  VARCHAR(60)
);

-- =========================================================
-- 4. PRODUCTS
-- =========================================================
CREATE TABLE olist_products_dataset (
    product_id                  VARCHAR(32) PRIMARY KEY,
    product_category_name       VARCHAR(60),
    product_name_lenght         INT,
    product_description_lenght  INT,
    product_photos_qty          INT,
    product_weight_g            INT,
    product_length_cm           INT,
    product_height_cm           INT,
    product_width_cm            INT,
    CONSTRAINT fk_products_category
        FOREIGN KEY (product_category_name)
        REFERENCES product_category_name_translation(product_category_name)
);
ALTER TABLE products
DROP CONSTRAINT fk_products_category;
-- =========================================================
-- 5. ORDERS
-- =========================================================
CREATE TABLE orders (
    order_id                       VARCHAR(32) PRIMARY KEY,
    customer_id                    VARCHAR(32) NOT NULL,
    order_status                   VARCHAR(20),
    order_purchase_timestamp       TIMESTAMP,
    order_approved_at              TIMESTAMP,
    order_delivered_carrier_date   TIMESTAMP,
    order_delivered_customer_date  TIMESTAMP,
    order_estimated_delivery_date  TIMESTAMP,
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);

-- =========================================================
-- 6. ORDER ITEMS
-- =========================================================
CREATE TABLE order_items (
    order_id            VARCHAR(32) NOT NULL,
    order_item_id        INT NOT NULL,
    product_id           VARCHAR(32),
    seller_id            VARCHAR(32),
    shipping_limit_date  TIMESTAMP,
    price                NUMERIC(10,2),
    freight_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT fk_items_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id),
    CONSTRAINT fk_items_product
        FOREIGN KEY (product_id) REFERENCES products(product_id),
    CONSTRAINT fk_items_seller
        FOREIGN KEY (seller_id) REFERENCES sellers(seller_id)
);

-- =========================================================
-- 7. ORDER PAYMENTS
-- =========================================================
CREATE TABLE order_payments (
    order_id             VARCHAR(32) NOT NULL,
    payment_sequential    INT NOT NULL,
    payment_type          VARCHAR(20),
    payment_installments  INT,
    payment_value         NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential),
    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- =========================================================
-- 8. ORDER REVIEWS
-- Note: review_id is NOT guaranteed unique in raw file (rare dupes exist).
-- Using a surrogate key avoids load failures; order_id is what you'll join on.
-- =========================================================
CREATE TABLE order_reviews (
    review_id               VARCHAR(32),
    order_id                VARCHAR(32) NOT NULL,
    review_score            INT,
    review_comment_title    VARCHAR(100),
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP,
    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- =========================================================
-- 9. GEOLOCATION
-- Note: NOT unique per zip code prefix (many lat/lng rows per prefix) —
-- treat as a lookup table to average/sample from, not a 1:1 join.
-- =========================================================
CREATE TABLE geolocation (
    geolocation_zip_code_prefix VARCHAR(5),
    geolocation_lat              NUMERIC(10,6),
    geolocation_lng               NUMERIC(10,6),
    geolocation_city              VARCHAR(60),
    geolocation_state              VARCHAR(2)
);

-- =========================================================
-- 10. MARKETING QUALIFIED LEADS (marketing funnel)
-- =========================================================
CREATE TABLE marketing_qualified_leads (
    mql_id              VARCHAR(32) PRIMARY KEY,
    first_contact_date   DATE,
    landing_page_id       VARCHAR(32),
    origin                VARCHAR(30)
);

-- =========================================================
-- 11. CLOSED DEALS (marketing funnel)
-- =========================================================
CREATE TABLE closed_deals (
    mql_id VARCHAR(32),
    seller_id VARCHAR(32),
    sdr_id VARCHAR(32),
    sr_id VARCHAR(32),
    won_date TIMESTAMP,
    business_segment VARCHAR(60),
    lead_type VARCHAR(30),
    lead_behaviour_profile VARCHAR(30),
    has_company VARCHAR(10),
    has_gtin VARCHAR(10),
    average_stock VARCHAR(30),
    business_type VARCHAR(30),
    declared_product_catalog_size NUMERIC,
    declared_monthly_revenue NUMERIC,
    CONSTRAINT fk_closed_deals_mql
        FOREIGN KEY (mql_id)
        REFERENCES marketing_qualified_leads(mql_id)
);


-- ==========================================
-- IMPORT ALL OLIST DATASETS
-- ==========================================

SELECT 'customers' AS table_name, COUNT(*) FROM customers
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'product_category_name_translation', COUNT(*) FROM product_category_name_translation
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'marketing_qualified_leads', COUNT(*) FROM marketing_qualified_leads
UNION ALL
SELECT 'closed_deals', COUNT(*) FROM closed_deals;

SELECT * FROM ORDERS
