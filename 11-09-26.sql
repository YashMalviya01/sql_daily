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


/*Mega Query 2 — Monthly Revenue + MoM + Cohort Retention*/

WITH order_level AS (
    SELECT
        order_id,
        customer_id,
        order_date,

        DATE_TRUNC('month', order_date) AS order_month,

        quantity * unit_price * (1 - discount) AS net_revenue

    FROM orders
),

customer_first_order AS (
    SELECT
        customer_id,
        MIN(order_month) AS cohort_month
    FROM order_level
    GROUP BY customer_id
),

customer_orders AS (
    SELECT
        o.*,
        c.cohort_month,

        CASE
            WHEN o.order_month = c.cohort_month
                THEN 'New'
            ELSE 'Returning'
        END AS customer_type

    FROM order_level o
    JOIN customer_first_order c
        ON o.customer_id = c.customer_id
),

monthly_summary AS (
    SELECT
        order_month AS month,

        SUM(net_revenue) AS revenue,

        COUNT(DISTINCT customer_id) AS unique_customers,

        COUNT(DISTINCT order_id) AS orders,

        SUM(net_revenue)
        / NULLIF(COUNT(DISTINCT order_id), 0) AS aov,

        COUNT(
            DISTINCT CASE
                WHEN customer_type = 'New'
                THEN customer_id
            END
        ) AS new_customers,

        COUNT(
            DISTINCT CASE
                WHEN customer_type = 'Returning'
                THEN customer_id
            END
        ) AS returning_customers,

        SUM(
            CASE
                WHEN customer_type = 'New'
                THEN net_revenue
                ELSE 0
            END
        ) AS new_customer_revenue,

        SUM(
            CASE
                WHEN customer_type = 'Returning'
                THEN net_revenue
                ELSE 0
            END
        ) AS returning_customer_revenue

    FROM customer_orders
    GROUP BY order_month
),

monthly_with_lag AS (
    SELECT
        *,
        
        LAG(revenue) OVER (
            ORDER BY month
        ) AS previous_month_revenue

    FROM monthly_summary
),

cohort_activity AS (
    SELECT
        cohort_month,
        order_month AS activity_month,
        COUNT(DISTINCT customer_id) AS retained_customers

    FROM customer_orders

    GROUP BY
        cohort_month,
        order_month
),

cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size

    FROM customer_orders

    WHERE order_month = cohort_month

    GROUP BY cohort_month
)

SELECT
    m.month,

    ROUND(m.revenue, 2) AS revenue,

    m.unique_customers,

    m.orders,

    ROUND(m.aov, 2) AS aov,

    ROUND(m.previous_month_revenue, 2)
        AS previous_month_revenue,

    ROUND(
        100.0 *
        (m.revenue - m.previous_month_revenue)
        / NULLIF(m.previous_month_revenue, 0),
        2
    ) AS mom_growth_pct,

    m.new_customers,

    m.returning_customers,

    ROUND(m.new_customer_revenue, 2)
        AS new_customer_revenue,

    ROUND(m.returning_customer_revenue, 2)
        AS returning_customer_revenue,

    ca.cohort_month,

    cs.cohort_size,

    ca.retained_customers,

    ROUND(
        100.0 *
        ca.retained_customers
        / NULLIF(cs.cohort_size, 0),
        2
    ) AS retention_pct

FROM monthly_with_lag m

LEFT JOIN cohort_activity ca
    ON m.month = ca.activity_month

LEFT JOIN cohort_size cs
    ON ca.cohort_month = cs.cohort_month

ORDER BY
    m.month,
    ca.cohort_month;


/*Mega Query 3 — Gaps & Islands + Longest Streak*/

WITH distinct_activity AS (
    SELECT DISTINCT
        customer_id,
        activity_date
    FROM customer_activity
),

numbered_activity AS (
    SELECT
        customer_id,
        activity_date,

        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY activity_date
        ) AS rn

    FROM distinct_activity
),

islands AS (
    SELECT
        customer_id,
        activity_date,

        activity_date
        - rn * INTERVAL '1 day' AS island_key

    FROM numbered_activity
),

streaks AS (
    SELECT
        customer_id,

        MIN(activity_date) AS streak_start,

        MAX(activity_date) AS streak_end,

        COUNT(*) AS streak_length

    FROM islands

    GROUP BY
        customer_id,
        island_key
),

customer_activity_summary AS (
    SELECT
        customer_id,

        MAX(streak_length) AS longest_streak,

        SUM(streak_length) AS total_active_days,

        MIN(streak_start) AS first_activity,

        MAX(streak_end) AS last_activity

    FROM streaks

    GROUP BY customer_id
),

classified_customers AS (
    SELECT
        *,

        CURRENT_DATE - last_activity
            AS days_since_last_activity,

        CASE
            WHEN CURRENT_DATE - last_activity <= 7
                THEN 'Active'

            WHEN CURRENT_DATE - last_activity <= 30
                THEN 'At Risk'

            ELSE 'Churned'
        END AS activity_status

    FROM customer_activity_summary
),

ranked_customers AS (
    SELECT
        *,

        RANK() OVER (
            PARTITION BY activity_status
            ORDER BY longest_streak DESC
        ) AS status_rank,

        AVG(longest_streak) OVER ()
            AS overall_avg_longest_streak

    FROM classified_customers
)

SELECT
    customer_id,
    first_activity,
    last_activity,
    total_active_days,
    longest_streak,
    days_since_last_activity,
    activity_status,
    status_rank

FROM ranked_customers

WHERE longest_streak > overall_avg_longest_streak

ORDER BY
    activity_status,
    status_rank;


/**/
