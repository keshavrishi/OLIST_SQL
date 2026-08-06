

-- =========================================================
-- OLIST E-COMMERCE ANALYSIS — ALL 10 PROBLEM SOLUTIONS
-- Assumes tables already created & loaded (customers, orders,
-- order_items, order_payments, order_reviews, products,
-- sellers, product_category_name_translation).
-- =========================================================


-- =========================================================
-- PROBLEM 1: Why are customers giving low ratings?
-- =========================================================
-- 1a. Review score distribution
SELECT
    review_score,
    COUNT(*) AS num_reviews,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM order_reviews
GROUP BY review_score
ORDER BY review_score;

-- 1b. Category contribution to low reviews
WITH order_category AS (
    SELECT DISTINCT oi.order_id, p.product_category_name
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
)
SELECT
    COALESCE(t.product_category_name_english, oc.product_category_name, 'unknown') AS category,
    COUNT(*) AS num_reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_low_reviews
FROM order_category oc
JOIN order_reviews r ON r.order_id = oc.order_id
LEFT JOIN product_category_name_translation t ON t.product_category_name = oc.product_category_name
GROUP BY COALESCE(t.product_category_name_english, oc.product_category_name, 'unknown')
HAVING COUNT(*) >= 30
ORDER BY pct_low_reviews DESC
LIMIT 15;


-- =========================================================
-- PROBLEM 2 (HEADLINE): Does first-order delivery experience
-- predict repeat purchase?
-- =========================================================
WITH first_orders AS (
    SELECT DISTINCT ON (c.customer_unique_id)
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 'Late'
            ELSE 'On-time/Early'
        END AS delivery_status
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_delivered_customer_date IS NOT NULL
    ORDER BY c.customer_unique_id, o.order_purchase_timestamp ASC
),
repeat_check AS (
    SELECT
        fo.customer_unique_id,
        fo.delivery_status,
        COUNT(o2.order_id) AS total_orders
    FROM first_orders fo
    JOIN customers c2 ON c2.customer_unique_id = fo.customer_unique_id
    JOIN orders o2 ON o2.customer_id = c2.customer_id AND o2.order_status = 'delivered'
    GROUP BY fo.customer_unique_id, fo.delivery_status
)
SELECT
    delivery_status,
    COUNT(*) AS num_customers,
    ROUND(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_purchase_rate_pct,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer
FROM repeat_check
GROUP BY delivery_status;


-- =========================================================
-- PROBLEM 3: Which product categories generate the most revenue?
-- =========================================================
WITH order_revenue AS (
    SELECT
        oi.order_id,
        p.product_category_name,
        oi.price,
        oi.freight_value
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
)
SELECT
    COALESCE(t.product_category_name_english, orv.product_category_name, 'unknown') AS category,
    COUNT(DISTINCT orv.order_id) AS num_orders,
    ROUND(SUM(orv.price)::numeric, 2) AS total_revenue,
    ROUND(AVG(orv.price)::numeric, 2) AS avg_order_value,
    ROUND(100.0 * SUM(orv.price) / SUM(SUM(orv.price)) OVER (), 2) AS revenue_share_pct
FROM order_revenue orv
LEFT JOIN product_category_name_translation t ON t.product_category_name = orv.product_category_name
GROUP BY COALESCE(t.product_category_name_english, orv.product_category_name, 'unknown')
ORDER BY total_revenue DESC
LIMIT 15;


-- =========================================================
-- PROBLEM 4: Which sellers are hurting customer experience?
-- =========================================================
WITH order_seller AS (
    SELECT DISTINCT oi.order_id, oi.seller_id
    FROM order_items oi
),
seller_orders AS (
    SELECT
        os.seller_id,
        o.order_id,
        o.order_status,
        CASE
            WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
            ELSE 0
        END AS is_late
    FROM order_seller os
    JOIN orders o ON o.order_id = os.order_id
)
SELECT
    so.seller_id,
    COUNT(DISTINCT so.order_id) AS num_orders,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(100.0 * SUM(so.is_late) / COUNT(*), 2) AS late_delivery_pct,
    ROUND(100.0 * SUM(CASE WHEN so.order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_pct
FROM seller_orders so
LEFT JOIN order_reviews r ON r.order_id = so.order_id
GROUP BY so.seller_id
HAVING COUNT(DISTINCT so.order_id) >= 20
ORDER BY avg_review_score ASC, late_delivery_pct DESC
LIMIT 15;


-- =========================================================
-- PROBLEM 5: Which regions/states experience late deliveries
-- most often?
-- =========================================================
SELECT
    c.customer_state,
    COUNT(*) AS num_orders,
    ROUND(100.0 * SUM(
        CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END
    ) / COUNT(*), 2) AS late_delivery_pct,
    ROUND(AVG(
        EXTRACT(DAY FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date))
    ), 2) AS avg_delay_days
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 50
ORDER BY late_delivery_pct DESC
LIMIT 15;


-- =========================================================
-- PROBLEM 6: What does repeat purchase behavior look like overall?
-- =========================================================
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS total_orders,
        SUM(oi.price) AS total_spend
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_customers,
    ROUND(100.0 * SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS repeat_purchase_rate_pct,
    ROUND(AVG(total_orders), 2) AS avg_orders_per_customer,
    ROUND(AVG(total_spend), 2) AS avg_customer_lifetime_value
FROM customer_orders;


-- =========================================================
-- PROBLEM 7: Which payment methods and installments drive
-- higher order value?
-- =========================================================
SELECT
    op.payment_type,
    COUNT(*) AS num_payments,
    ROUND(AVG(op.payment_value), 2) AS avg_order_value,
    ROUND(AVG(op.payment_installments), 1) AS avg_installments,
    ROUND(100.0 * SUM(op.payment_value) / SUM(SUM(op.payment_value)) OVER (), 2) AS revenue_share_pct
FROM order_payments op
JOIN orders o ON o.order_id = op.order_id
WHERE o.order_status = 'delivered'
GROUP BY op.payment_type
ORDER BY avg_order_value DESC;


-- =========================================================
-- PROBLEM 8: Is marketplace revenue dangerously concentrated
-- in a few sellers?
-- =========================================================
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
ranked AS (
    SELECT
        seller_id,
        revenue,
        RANK() OVER (ORDER BY revenue DESC) AS seller_rank,
        SUM(revenue) OVER () AS total_revenue
    FROM seller_revenue
)
SELECT
    CASE WHEN seller_rank <= 20 THEN 'Top 20 sellers' ELSE 'Long tail (rest)' END AS seller_group,
    COUNT(*) AS num_sellers,
    ROUND(SUM(revenue), 2) AS group_revenue,
    ROUND(100.0 * SUM(revenue) / MAX(total_revenue), 2) AS pct_of_total_revenue
FROM ranked
GROUP BY CASE WHEN seller_rank <= 20 THEN 'Top 20 sellers' ELSE 'Long tail (rest)' END;


-- =========================================================
-- PROBLEM 9: Which states/regions are most profitable?
-- =========================================================
SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS num_customers,
    COUNT(DISTINCT o.order_id) AS num_orders,
    ROUND(SUM(oi.price)::numeric, 2) AS total_revenue,
    ROUND(AVG(oi.price)::numeric, 2) AS avg_order_value,
    ROUND(100.0 * SUM(oi.price) / SUM(SUM(oi.price)) OVER (), 2) AS revenue_share_pct
FROM customers c
JOIN orders o ON o.customer_id = c.customer_id
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY total_revenue DESC
LIMIT 15;


-- =========================================================
-- PROBLEM 10: Which categories have the highest shipping-cost-
-- to-price ratio (margin/conversion risk)?
-- =========================================================
WITH order_category AS (
    SELECT
        oi.order_id,
        p.product_category_name,
        oi.price,
        oi.freight_value
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
)
SELECT
    COALESCE(t.product_category_name_english, oc.product_category_name, 'unknown') AS category,
    COUNT(*) AS num_items,
    ROUND(AVG(oc.price)::numeric, 2) AS avg_price,
    ROUND(AVG(oc.freight_value)::numeric, 2) AS avg_freight,
    ROUND(AVG(oc.freight_value / NULLIF(oc.price, 0))::numeric, 3) AS freight_to_price_ratio
FROM order_category oc
LEFT JOIN product_category_name_translation t ON t.product_category_name = oc.product_category_name
GROUP BY COALESCE(t.product_category_name_english, oc.product_category_name, 'unknown')
HAVING COUNT(*) >= 30
ORDER BY freight_to_price_ratio DESC
LIMIT 15;

---Theme	Problems	Connection
Customer Experience    	1, 2	Low ratings → delivery se link
Retention	2, 6	Delivery-segmented + overall repeat rate
Growth	3, 9	Category revenue + state profitability
Marketplace Health	4, 8	Seller quality + seller concentration risk
Ops/Logistics	5, 10	Regional delays + shipping cost margin risk---