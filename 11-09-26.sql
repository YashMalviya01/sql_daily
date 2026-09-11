/*Mega Query 1 — Customer Revenue + Ranking + Growth*/

WITH order_level AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        region,
        product_id,
        quantity,
        unit_price,
        discount,

        quantity * unit_price * (1 - discount) AS net_revenue
    FROM orders
),

customer_summary AS (
    SELECT
        customer_id,
        region,

        MIN(order_date) AS first_order_date,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(net_revenue) AS total_revenue,
        AVG(net_revenue) AS avg_order_value

    FROM order_level
    GROUP BY customer_id, region
),

customer_classified AS (
    SELECT
        *,
        CASE
            WHEN total_revenue >= 100000 THEN 'High Value'
            WHEN total_orders = 1 THEN 'New'
            ELSE 'Returning'
        END AS customer_type
    FROM customer_summary
),

ranked_customers AS (
    SELECT
        *,
        
        RANK() OVER (
            PARTITION BY region
            ORDER BY total_revenue DESC
        ) AS region_revenue_rank,

        SUM(total_revenue) OVER (
            PARTITION BY region
        ) AS regional_total_revenue

    FROM customer_classified
),

with_previous_order AS (
    SELECT
        rc.*,

        LAG(total_revenue) OVER (
            PARTITION BY customer_id
            ORDER BY first_order_date
        ) AS previous_order_revenue

    FROM ranked_customers rc
),

region_average AS (
    SELECT
        *,
        AVG(total_revenue) OVER (
            PARTITION BY region
        ) AS regional_avg_customer_revenue

    FROM with_previous_order
)

SELECT
    region,
    customer_id,
    first_order_date,
    total_orders,
    ROUND(total_revenue, 2) AS total_revenue,
    ROUND(avg_order_value, 2) AS avg_order_value,
    customer_type,
    region_revenue_rank,

    ROUND(
        100.0 * total_revenue
        / NULLIF(regional_total_revenue, 0),
        2
    ) AS regional_revenue_pct,

    ROUND(previous_order_revenue, 2) AS previous_order_revenue,

    ROUND(
        100.0 *
        (total_revenue - previous_order_revenue)
        / NULLIF(previous_order_revenue, 0),
        2
    ) AS revenue_growth_pct

FROM region_average

WHERE total_revenue > regional_avg_customer_revenue

ORDER BY
    region,
    region_revenue_rank;
