/*Business Requirement

Management wants to identify high-value customers whose purchasing behavior is improving and who have demonstrated consistent engagement.

For every customer, calculate:

1. Lifetime metrics
Lifetime revenue
Total orders
Number of distinct products purchased
Number of distinct categories purchased
2. Monthly metrics

Create a customer-month grain and calculate:

Monthly revenue
Monthly order count
Previous month's revenue
MoM revenue growth %
3. Rolling performance

Calculate:

3-month rolling average revenue
Running lifetime revenue by month
4. Engagement

Identify the customer's:

Longest consecutive monthly purchasing streak

A month counts as active if the customer made at least one purchase.

5. Retention

Determine whether the customer's latest active month was retained.

A customer is retained if their latest active month immediately follows their previous active month.

6. Customer ranking

Rank customers within their region based on lifetime revenue.

7. Final selection

Return customers who satisfy all of these conditions:

Lifetime revenue > overall average customer revenue
AND
Longest monthly streak >= 3
AND
Latest month was retained

Then return the top 5 customers in each region based on lifetime revenue.*/

WITH customer_monthly AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        DATE_TRUNC('month', f.order_date) AS sales_month,

        SUM(f.sales_amount) AS monthly_revenue,
        COUNT(DISTINCT f.order_id) AS monthly_orders

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,
        DATE_TRUNC('month', f.order_date)
),

monthly_lag AS
(
    SELECT
        *,
        
        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_month_revenue,

        LAG(sales_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS previous_sales_month

    FROM customer_monthly
),

monthly_metrics AS
(
    SELECT
        *,
        
        ROUND(
            (monthly_revenue - previous_month_revenue) * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        AVG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_revenue,

        SUM(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS running_revenue

    FROM monthly_lag
),

streak_flags AS
(
    SELECT
        *,
        
        CASE
            WHEN previous_sales_month IS NULL
                 OR sales_month <>
                    previous_sales_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS new_island_flag

    FROM monthly_metrics
),

activity_islands AS
(
    SELECT
        *,
        
        SUM(new_island_flag) OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month
        ) AS island_id

    FROM streak_flags
),

streak_lengths AS
(
    SELECT
        customer_id,
        island_id,
        COUNT(*) AS streak_length

    FROM activity_islands

    GROUP BY
        customer_id,
        island_id
),

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_monthly_streak

    FROM streak_lengths

    GROUP BY customer_id
),

retention_check AS
(
    SELECT
        customer_id,
        sales_month,

        CASE
            WHEN previous_sales_month IS NOT NULL
                 AND sales_month =
                     previous_sales_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS retained_flag,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM monthly_lag
),

latest_retention AS
(
    SELECT
        customer_id,
        sales_month AS latest_month,
        retained_flag AS latest_retention_flag

    FROM retention_check

    WHERE rn = 1
),

customer_lifetime AS
(
    SELECT
        f.customer_id,

        SUM(f.sales_amount) AS lifetime_revenue,
        COUNT(DISTINCT f.order_id) AS total_orders,
        COUNT(DISTINCT f.product_id) AS unique_products,
        COUNT(DISTINCT p.category) AS unique_categories

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        f.customer_id
),

overall_average AS
(
    SELECT
        AVG(lifetime_revenue) AS overall_avg_customer_revenue

    FROM customer_lifetime
),

latest_month_metrics AS
(
    SELECT
        customer_id,
        sales_month AS latest_month,
        monthly_revenue AS latest_month_revenue,
        mom_growth AS latest_mom_growth,
        rolling_3_month_revenue

    FROM
    (
        SELECT
            *,
            
            ROW_NUMBER() OVER
            (
                PARTITION BY customer_id
                ORDER BY sales_month DESC
            ) AS rn

        FROM monthly_metrics
    ) x

    WHERE rn = 1
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        c.region,

        l.lifetime_revenue,
        l.total_orders,
        l.unique_products,
        l.unique_categories,

        m.latest_month,
        m.latest_month_revenue,
        m.latest_mom_growth,
        m.rolling_3_month_revenue,

        s.longest_monthly_streak,

        r.latest_retention_flag,

        a.overall_avg_customer_revenue

    FROM dim_customers c

    JOIN customer_lifetime l
        ON c.customer_id = l.customer_id

    JOIN latest_month_metrics m
        ON c.customer_id = m.customer_id

    JOIN longest_streak s
        ON c.customer_id = s.customer_id

    JOIN latest_retention r
        ON c.customer_id = r.customer_id

    CROSS JOIN overall_average a
),

regional_ranking AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY lifetime_revenue DESC
        ) AS rn

    FROM customer_profile

    WHERE lifetime_revenue > overall_avg_customer_revenue
      AND longest_monthly_streak >= 3
      AND latest_retention_flag = 1
)

SELECT
    customer_id,
    customer_name,
    segment,
    region,
    lifetime_revenue,
    total_orders,
    unique_products,
    unique_categories,
    latest_month,
    latest_month_revenue,
    latest_mom_growth,
    rolling_3_month_revenue,
    longest_monthly_streak,
    latest_retention_flag,
    rn AS regional_revenue_rank

FROM regional_ranking

WHERE rn <= 5

ORDER BY
    region,
    regional_revenue_rank;



/*Business requirement

For each product, calculate its monthly revenue and identify whether revenue increased compared with the previous month.

Then determine:

Monthly revenue
Previous month's revenue
MoM growth %
Number of months where revenue increased
Longest consecutive increasing-revenue streak
Latest month's revenue
Latest month's MoM growth

Return only products where:

The product has at least 3 months of increasing revenue
The latest month's revenue is greater than the previous month
Return the top 10 products by latest-month revenue*/


WITH monthly_revenue AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        DATE_TRUNC('month', f.order_date)
),

monthly_lag AS
(
    SELECT
        *,
        LAG(monthly_revenue) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS previous_month_revenue

    FROM monthly_revenue
),

monthly_growth AS
(
    SELECT
        *,
        ROUND(
            (monthly_revenue - previous_month_revenue) * 100.0
            / NULLIF(previous_month_revenue, 0),
            2
        ) AS mom_growth,

        CASE
            WHEN previous_month_revenue IS NOT NULL
                 AND monthly_revenue > previous_month_revenue
            THEN 1
            ELSE 0
        END AS increase_flag

    FROM monthly_lag
),

streak_groups AS
(
    SELECT
        *,
        SUM(
            CASE
                WHEN increase_flag = 0 THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS streak_id

    FROM monthly_growth
),

streak_lengths AS
(
    SELECT
        product_id,
        streak_id,
        COUNT(*) AS streak_length

    FROM streak_groups

    WHERE increase_flag = 1

    GROUP BY
        product_id,
        streak_id
),

product_performance AS
(
    SELECT
        product_id,
        MAX(streak_length) AS longest_growth_streak,
        SUM(increase_flag) AS increase_month_count

    FROM streak_groups sg

    LEFT JOIN streak_lengths sl
        ON sg.product_id = sl.product_id
       AND sg.streak_id = sl.streak_id

    GROUP BY
        product_id
),

latest_month AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month DESC
        ) AS rn

    FROM monthly_growth
),

qualifying_products AS
(
    SELECT
        l.product_id,
        l.product_name,
        l.category,
        l.sales_month AS latest_month,
        l.monthly_revenue AS latest_month_revenue,
        l.mom_growth AS latest_mom_growth,
        p.increase_month_count,
        p.longest_growth_streak

    FROM latest_month l

    JOIN product_performance p
        ON l.product_id = p.product_id

    WHERE l.rn = 1
      AND p.increase_month_count >= 3
      AND l.monthly_revenue > l.previous_month_revenue
),

ranked_products AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            ORDER BY latest_month_revenue DESC
        ) AS rn

    FROM qualifying_products
)

SELECT
    product_id,
    product_name,
    category,
    latest_month,
    latest_month_revenue,
    latest_mom_growth,
    increase_month_count,
    longest_growth_streak

FROM ranked_products

WHERE rn <= 10

ORDER BY
    latest_month_revenue DESC;

