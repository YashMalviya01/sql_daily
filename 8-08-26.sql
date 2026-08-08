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
         
