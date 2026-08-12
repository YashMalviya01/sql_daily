/*You are a Senior Customer Analytics Analyst at a global e-commerce company.

The Chief Revenue Officer wants a Customer Value & Retention Intelligence Report identifying the company's 50 most strategically valuable customers.Business Requirements

For every customer, calculate the following.

1. Lifetime Value

Calculate:

Total lifetime revenue
Total number of orders
Number of distinct products purchased
2. Monthly Purchasing Behavior

For every customer and month calculate:

Monthly revenue
Monthly order count
Previous month's revenue
Previous month's order count
Month-over-month revenue growth %
3. Rolling Performance

Calculate:

3-month rolling average revenue
6-month rolling revenue

for every customer.

4. Customer Activity Streak

Identify the customer's longest consecutive monthly purchasing streak.

A customer is considered active in a month if they made at least one purchase.

For example:

Jan Feb Mar Apr

= 4-month streak.

But:

Jan Feb Mar May Jun

contains:

Jan Feb Mar → 3 months
May Jun     → 2 months

Therefore, longest streak = 3.

5. Customer Inactivity

Calculate the maximum number of consecutive inactive months between two active months for every customer.

6. Customer Cohort

Determine each customer's:

First active month / cohort month
Latest active month
Customer age in months
7. Latest-Month Retention

Determine whether the customer was retained in their latest active month.

A customer is retained if their latest active month immediately follows their previous active month.

For example:

March → April

= retained.

But:

March → June

= not retained.

8. Customer Revenue Percentile

Calculate:

Revenue percentile
Revenue decile
Overall revenue rank
Dense revenue rank

based on lifetime revenue.

9. Customer Segmentation

Assign each customer:

VIP
HIGH_VALUE
MEDIUM_VALUE
LOW_VALUE

using lifetime revenue and order-count thresholds.

Use:

VIP:
Revenue >= 100,000
AND Orders >= 20

HIGH_VALUE:
Revenue >= 50,000

MEDIUM_VALUE:
Revenue >= 10,000

LOW_VALUE:
Everyone else
☠️ 10. Customer Strategic Value Score

Calculate a final customer score using:

40% → Lifetime Revenue
15% → Longest Monthly Streak
20% → Latest Month Revenue
15% → 3-Month Rolling Revenue
10% → Latest Month Revenue Growth

Normalize/scale the components as necessary so they can be combined into one score.

🏆 Final Requirement

Rank all customers by their final strategic value score.

Return the top 50 customers.*/


WITH
-- ============================================================
-- 01. BASE ORDERS
-- ============================================================
base_orders AS
(
    SELECT
        f.customer_id,
        f.order_id,
        f.product_id,
        f.order_date,
        f.sales_amount,
        DATE_TRUNC('month', f.order_date) AS order_month
    FROM fact_sales f
),

-- ============================================================
-- 02. CUSTOMER MONTHLY ACTIVITY
-- ============================================================
customer_months AS
(
    SELECT DISTINCT
        customer_id,
        order_month
    FROM base_orders
),

-- ============================================================
-- 03. CUSTOMER LAG
-- ============================================================
customer_month_lag AS
(
    SELECT
        customer_id,
        order_month,
        LAG(order_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_month
    FROM customer_months
),

-- ============================================================
-- 04. ACTIVITY GAP FLAG
-- ============================================================
activity_flags AS
(
    SELECT
        customer_id,
        order_month,
        previous_month,

        CASE
            WHEN previous_month IS NULL
                 OR order_month <> previous_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS new_island
    FROM customer_month_lag
),

-- ============================================================
-- 05. CUSTOMER ISLANDS
-- ============================================================
customer_islands AS
(
    SELECT
        customer_id,
        order_month,

        SUM(new_island) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS island_id

    FROM activity_flags
),

-- ============================================================
-- 06. STREAK LENGTH
-- ============================================================
customer_streaks AS
(
    SELECT
        customer_id,
        island_id,
        MIN(order_month) AS streak_start,
        MAX(order_month) AS streak_end,
        COUNT(*) AS streak_length
    FROM customer_islands
    GROUP BY
        customer_id,
        island_id
),

-- ============================================================
-- 07. LONGEST STREAK
-- ============================================================
longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_streak
    FROM customer_streaks
    GROUP BY customer_id
),

-- ============================================================
-- 08. CUSTOMER REVENUE
-- ============================================================
customer_revenue AS
(
    SELECT
        customer_id,
        SUM(sales_amount) AS lifetime_revenue,
        COUNT(DISTINCT order_id) AS lifetime_orders,
        COUNT(DISTINCT product_id) AS unique_products
    FROM base_orders
    GROUP BY customer_id
),

-- ============================================================
-- 09. CUSTOMER MONTHLY REVENUE
-- ============================================================
monthly_customer_revenue AS
(
    SELECT
        customer_id,
        order_month,
        SUM(sales_amount) AS monthly_revenue,
        COUNT(DISTINCT order_id) AS monthly_orders
    FROM base_orders
    GROUP BY
        customer_id,
        order_month
),

-- ============================================================
-- 10. PREVIOUS MONTH REVENUE
-- ============================================================
monthly_revenue_lag AS
(
    SELECT
        customer_id,
        order_month,
        monthly_revenue,
        monthly_orders,

        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_month_revenue,

        LAG(monthly_orders) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_month_orders

    FROM monthly_customer_revenue
),

-- ============================================================
-- 11. MONTHLY GROWTH
-- ============================================================
monthly_growth AS
(
    SELECT
        *,
        CASE
            WHEN previous_month_revenue IS NULL
                 OR previous_month_revenue = 0
            THEN NULL
            ELSE
                (
                    monthly_revenue - previous_month_revenue
                ) * 100.0
                / previous_month_revenue
        END AS revenue_growth_pct
    FROM monthly_revenue_lag
),

-- ============================================================
-- 12. ROLLING REVENUE
-- ============================================================
rolling_customer_metrics AS
(
    SELECT
        *,
        AVG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS rolling_3_month_revenue,

        SUM(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
            ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
        ) AS rolling_6_month_revenue

    FROM monthly_growth
),

-- ============================================================
-- 13. CUSTOMER LATEST MONTH
-- ============================================================
latest_customer_month AS
(
    SELECT
        customer_id,
        MAX(order_month) AS latest_month
    FROM monthly_customer_revenue
    GROUP BY customer_id
),

-- ============================================================
-- 14. LATEST CUSTOMER METRICS
-- ============================================================
latest_metrics AS
(
    SELECT
        r.customer_id,
        r.order_month,
        r.monthly_revenue,
        r.monthly_orders,
        r.revenue_growth_pct,
        r.rolling_3_month_revenue,
        r.rolling_6_month_revenue

    FROM rolling_customer_metrics r

    JOIN latest_customer_month l
        ON r.customer_id = l.customer_id
       AND r.order_month = l.latest_month
),

-- ============================================================
-- 15. CUSTOMER REVENUE PERCENTILE
-- ============================================================
customer_percentiles AS
(
    SELECT
        customer_id,
        lifetime_revenue,

        PERCENT_RANK() OVER
        (
            ORDER BY lifetime_revenue
        ) AS revenue_percentile,

        NTILE(10) OVER
        (
            ORDER BY lifetime_revenue DESC
        ) AS revenue_decile

    FROM customer_revenue
),

-- ============================================================
-- 16. CUSTOMER RANK
-- ============================================================
customer_rankings AS
(
    SELECT
        customer_id,
        lifetime_revenue,

        RANK() OVER
        (
            ORDER BY lifetime_revenue DESC
        ) AS revenue_rank,

        DENSE_RANK() OVER
        (
            ORDER BY lifetime_revenue DESC
        ) AS dense_revenue_rank

    FROM customer_revenue
),

-- ============================================================
-- 17. CUSTOMER SEGMENT
-- ============================================================
customer_segments AS
(
    SELECT
        r.customer_id,
        r.lifetime_revenue,
        r.lifetime_orders,
        r.unique_products,

        CASE
            WHEN r.lifetime_revenue >= 100000
                 AND r.lifetime_orders >= 20
            THEN 'VIP'

            WHEN r.lifetime_revenue >= 50000
            THEN 'HIGH_VALUE'

            WHEN r.lifetime_revenue >= 10000
            THEN 'MEDIUM_VALUE'

            ELSE 'LOW_VALUE'
        END AS customer_segment

    FROM customer_revenue r
),

-- ============================================================
-- 18. CUSTOMER RETURN STATUS
-- ============================================================
customer_return_status AS
(
    SELECT
        m.customer_id,
        m.order_month,
        m.previous_month,

        CASE
            WHEN m.previous_month IS NOT NULL
                 AND m.order_month =
                     m.previous_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS retained_flag

    FROM customer_month_lag m
),

-- ============================================================
-- 19. LATEST RETENTION
-- ============================================================
latest_retention AS
(
    SELECT
        customer_id,
        retained_flag,

        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_month DESC) AS rn

    FROM
    (
        SELECT
            customer_id,
            order_month,
            retained_flag
        FROM customer_return_status
    ) x
),

-- ============================================================
-- 20. CUSTOMER CHURN GAP
-- ============================================================
customer_gaps AS
(
    SELECT
        customer_id,
        order_month,
        previous_month,

        CASE
            WHEN previous_month IS NULL
            THEN 0
            ELSE
                EXTRACT(
                    MONTH FROM AGE(order_month, previous_month)
                ) - 1
        END AS inactive_months

    FROM customer_month_lag
),

-- ============================================================
-- 21. MAXIMUM INACTIVITY
-- ============================================================
maximum_inactivity AS
(
    SELECT
        customer_id,
        MAX(inactive_months) AS max_inactive_months
    FROM customer_gaps
    GROUP BY customer_id
),

-- ============================================================
-- 22. CUSTOMER COHORT
-- ============================================================
customer_cohorts AS
(
    SELECT
        customer_id,
        MIN(order_month) AS cohort_month
    FROM customer_months
    GROUP BY customer_id
),

-- ============================================================
-- 23. CUSTOMER AGE
-- ============================================================
customer_age AS
(
    SELECT
        c.customer_id,
        c.cohort_month,
        l.latest_month,

        (
            EXTRACT(
                YEAR FROM AGE(l.latest_month, c.cohort_month)
            ) * 12
            +
            EXTRACT(
                MONTH FROM AGE(l.latest_month, c.cohort_month)
            )
        ) AS customer_age_months

    FROM customer_cohorts c

    JOIN latest_customer_month l
        ON c.customer_id = l.customer_id
),

-- ============================================================
-- 24. FINAL CUSTOMER PROFILE
-- ============================================================
customer_profile AS
(
    SELECT
        s.customer_id,
        s.customer_segment,
        s.lifetime_revenue,
        s.lifetime_orders,
        s.unique_products,

        p.revenue_percentile,
        p.revenue_decile,

        r.revenue_rank,

        ls.longest_streak,

        mi.max_inactive_months,

        ca.cohort_month,
        ca.customer_age_months,

        lm.monthly_revenue AS latest_month_revenue,
        lm.revenue_growth_pct AS latest_growth_pct,
        lm.rolling_3_month_revenue,
        lm.rolling_6_month_revenue,

        lr.retained_flag AS latest_retention_flag

    FROM customer_segments s

    LEFT JOIN customer_percentiles p
        ON s.customer_id = p.customer_id

    LEFT JOIN customer_rankings r
        ON s.customer_id = r.customer_id

    LEFT JOIN longest_streak ls
        ON s.customer_id = ls.customer_id

    LEFT JOIN maximum_inactivity mi
        ON s.customer_id = mi.customer_id

    LEFT JOIN customer_age ca
        ON s.customer_id = ca.customer_id

    LEFT JOIN latest_metrics lm
        ON s.customer_id = lm.customer_id

    LEFT JOIN latest_retention lr
        ON s.customer_id = lr.customer_id
       AND lr.rn = 1
),

-- ============================================================
-- 25. FINAL SCORING
-- ============================================================
scored_customers AS
(
    SELECT
        *,

        (
            COALESCE(lifetime_revenue, 0) * 0.40
            +
            COALESCE(longest_streak, 0) * 1000 * 0.15
            +
            COALESCE(latest_month_revenue, 0) * 0.20
            +
            COALESCE(rolling_3_month_revenue, 0) * 0.15
            +
            COALESCE(latest_growth_pct, 0) * 100 * 0.10
        ) AS customer_score

    FROM customer_profile
),

-- ============================================================
-- 26. FINAL RANKING
-- ============================================================
final_ranking AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            ORDER BY customer_score DESC
        ) AS final_rank

    FROM scored_customers
)

SELECT
    customer_id,
    customer_segment,
    lifetime_revenue,
    lifetime_orders,
    unique_products,
    revenue_percentile,
    revenue_decile,
    revenue_rank,
    longest_streak,
    max_inactive_months,
    cohort_month,
    customer_age_months,
    latest_month_revenue,
    latest_growth_pct,
    rolling_3_month_revenue,
    rolling_6_month_revenue,
    latest_retention_flag,
    customer_score,
    final_rank

FROM final_ranking

WHERE final_rank <= 50

ORDER BY final_rank;
