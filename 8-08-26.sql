/*Business requirement

An e-commerce company wants to identify customers who made a second purchase within 30 days of their first purchase.*/

WITH customer_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        SUM(sales_amount) AS order_amount
    FROM fact_sales
    GROUP BY
        customer_id,
        order_id,
        order_date
),

ranked_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        order_amount,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS order_rank

    FROM customer_orders
),

first_second_purchase AS
(
    SELECT
        customer_id,

        MAX(
            CASE
                WHEN order_rank = 1
                THEN order_date
            END
        ) AS first_order_date,

        MAX(
            CASE
                WHEN order_rank = 1
                THEN order_amount
            END
        ) AS first_order_amount,

        MAX(
            CASE
                WHEN order_rank = 2
                THEN order_date
            END
        ) AS second_order_date,

        MAX(
            CASE
                WHEN order_rank = 2
                THEN order_amount
            END
        ) AS second_order_amount

    FROM ranked_orders

    GROUP BY customer_id
),

retention_flag AS
(
    SELECT
        *,

        CASE
            WHEN second_order_date <= first_order_date + INTERVAL '30 days'
            THEN 'Yes'
            ELSE 'No'
        END AS second_purchase_within_30_days

    FROM first_second_purchase
)

SELECT
    customer_id,
    first_order_date,
    first_order_amount,
    second_order_date,
    second_order_amount,
    second_purchase_within_30_days

FROM retention_flag

WHERE second_order_date IS NOT NULL;


/*Business requirement

An e-commerce company wants to identify customers who stopped purchasing for at least 60 days and then returned to make another purchase.

For every qualifying customer, show:

Customer ID
Date of the purchase before the inactive period
Date they returned
Number of inactive days*/

WITH customer_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,

        LAG(order_date) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS previous_order_date

    FROM fact_sales
),

previous_purchase AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        previous_order_date,

        CASE
            WHEN previous_order_date IS NOT NULL
                 AND order_date - previous_order_date >= 60
            THEN 'Yes'
            ELSE 'No'
        END AS inactive_flag

    FROM customer_orders
),

inactive_customers AS
(
    SELECT
        customer_id,
        previous_order_date,
        order_date,
        order_date - previous_order_date AS inactive_days

    FROM previous_purchase

    WHERE inactive_flag = 'Yes'
)

SELECT
    customer_id,
    previous_order_date,
    order_date AS return_date,
    inactive_days

FROM inactive_customers

ORDER BY
    customer_id,
    return_date;

/*An e-commerce company wants to identify products whose monthly revenue increased for 3 consecutive months.
Requirement

For each product, identify the periods where revenue increased month-over-month for three consecutive months.

Return:

product_id
The month where the 3-month growth streak is completed
Revenue for that month
Previous month revenue
Growth percentage*/


WITH monthly_revenue AS
(
    SELECT
        product_id,
        DATE_TRUNC('month', order_date) AS sales_month,
        SUM(sales_amount) AS monthly_revenue
    FROM fact_sales
    GROUP BY product_id,
             DATE_TRUNC('month', order_date)    
),

previous_revenue AS
(
    SELECT
        product_id,
        sales_month,
        monthly_revenue,

        LAG(monthly_revenue) OVER (PARTITION BY product_id ORDER BY sales_month) AS previous_month_revenue,

        LAG(sales_month) OVER ( PARTITION BY product_id ORDER BY sales_month) AS monthly_revenue
),

growth_calculation AS
(
    SELECT
        product_id,
        sales_month,
        monthly_revenue,
        previous_month_revenue,

        ROUND(( monthly_revenue - previous_month_revenue) * 100.0 / NULLIF(previous_month_revenue,0),2) AS growth_oercentage,

        CASE
            WHEN previous_month_revenue IS NOT NULL
                 AND monthly_revenue > previous_month_revenue
            THEN 1
            ELSE 0
        END AS growth_flag
    FROM previous_revenue
),

growth_streak AS
(
    SELECT
        product_id,
        sales_month,
        monthly_revenue,
        previous_month_revenue,
        growth_oercentage,

        SUM(growth_flag) AS growth_streak_count

    FROM growth_calculation
    GROUP BY product_id,
             sales_month,
             monthly_revenue,
             previous_month_revenue,
             growth_oercentage
),

max_streak AS 
(
    SELECT
        product_id,
        MAX(growth_streak_count) AS max_growth_streak

    FROM growth_streak
    GROUP BY product_id
),

ranked_products AS 
(
    SELECT
        g.product_id,
        g.sales_month,
        g.monthly_revenue,
        g.previous_month_revenue,
        g.growth_oercentage,
        g.growth_streak_count,

        RANK() OVER (PARTITION BY g.product_id ORDER BY g.sales_month DESC) AS rank

    FROM growth_streak g
    JOIN max_streak m ON g.product_id = m.product_id
    WHERE g.growth_streak_count = m.max_growth_streak
)

SELECT
    product_id,
    sales_month,
    monthly_revenue,
    previous_month_revenue,
    growth_oercentage
FROM ranked_products
WHERE rank <= 10
ORDER BY product_id,
         max_growth_streak DESC;


/*A subscription company wants to identify customers who were active for at least 3 consecutive months, then became inactive, and later returned.
Requirement

For every customer who qualifies, return:

customer_id
The month their active streak ended
The month they returned
Number of inactive months between the two*/


WITH active_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', activity_date) AS activity_month

    FROM fact_activity
),

previous_month AS
(
    SELECT
        customer_id,
        activity_month,

        LAG(activity_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY activity_month
        ) AS previous_activity_month

    FROM active_months
),

streak_flags AS
(
    SELECT
        customer_id,
        activity_month,
        previous_activity_month,

        CASE
            WHEN previous_activity_month IS NULL
                 OR activity_month <> previous_activity_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS streak_flag

    FROM previous_month
),

activity_islands AS
(
    SELECT
        customer_id,
        activity_month,

        SUM(streak_flag) OVER
        (
            PARTITION BY customer_id
            ORDER BY activity_month
        ) AS island_id

    FROM streak_flags
),

streaks AS
(
    SELECT
        customer_id,
        island_id,

        MIN(activity_month) AS streak_start_month,
        MAX(activity_month) AS streak_end_month,
        COUNT(*) AS active_months

    FROM activity_islands

    GROUP BY
        customer_id,
        island_id
),

next_streak AS
(
    SELECT
        customer_id,
        island_id,
        streak_start_month,
        streak_end_month,
        active_months,

        LEAD(streak_start_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY island_id
        ) AS return_month

    FROM streaks
),

reactivated_customers AS
(
    SELECT
        customer_id,
        streak_end_month,
        return_month,

        EXTRACT(
            MONTH FROM AGE(return_month, streak_end_month)
        ) - 1 AS inactive_months,

        active_months

    FROM next_streak

    WHERE active_months >= 3
      AND return_month IS NOT NULL
)

SELECT
    customer_id,
    streak_end_month,
    return_month,
    inactive_months,
    active_months AS previous_active_streak

FROM reactivated_customers

WHERE inactive_months > 0

ORDER BY
    customer_id,
    return_month;
         
/*Business requirement

An e-commerce company wants to identify customers whose purchase frequency is increasing over time.

A customer is considered to have improving purchase frequency if their number of orders in a month is higher than the previous month's order count for at least 3 consecutive months.

For each qualifying customer, return:

customer_id
Month when the longest increasing streak ended
Longest increasing streak
Order count in that month*/


WITH monthly_orders AS
(
    SELECT
        customer_id,
        DATE_TRUNC('month', order_date) AS order_month,
        COUNT(DISTINCT order_id) AS order_count

    FROM fact_sales

    GROUP BY
        customer_id,
        DATE_TRUNC('month', order_date)
),

previous_orders AS
(
    SELECT
        customer_id,
        order_month,
        order_count,

        LAG(order_count) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_order_count

    FROM monthly_orders
),

growth_flags AS
(
    SELECT
        customer_id,
        order_month,
        order_count,
        previous_order_count,

        CASE
            WHEN previous_order_count IS NOT NULL
                 AND order_count > previous_order_count
            THEN 1
            ELSE 0
        END AS growth_flag

    FROM previous_orders
),

growth_islands AS
(
    SELECT
        customer_id,
        order_month,
        order_count,
        growth_flag,

        SUM(
            CASE
                WHEN growth_flag = 0 THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS island_id

    FROM growth_flags
),

growth_streaks AS
(
    SELECT
        customer_id,
        island_id,

        COUNT(*) AS streak_length,

        MAX(order_month) AS streak_end_month

    FROM growth_islands

    WHERE growth_flag = 1

    GROUP BY
        customer_id,
        island_id
),

customer_longest_streak AS
(
    SELECT
        customer_id,
        streak_end_month,
        streak_length,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY streak_length DESC,
                     streak_end_month DESC
        ) AS rn

    FROM growth_streaks
)

SELECT
    customer_id,
    streak_end_month,
    streak_length AS longest_increasing_streak

FROM customer_longest_streak

WHERE rn = 1
  AND streak_length >= 3

ORDER BY
    longest_increasing_streak DESC,
    customer_id;
