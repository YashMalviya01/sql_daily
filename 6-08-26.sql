/*Question 1 — Rolling Average
Business Requirement

For every product, calculate:

Monthly Revenue
3-Month Rolling Average
Running Total Revenue*/

WITH monthly_sales AS
(
    SELECT
        product_id,
        DATE_TRUNC('month', order_date) AS order_month,
        SUM(sales_amount) AS monthly_revenue
    FROM fact_sales
    GROUP BY product_id,
             DATE_TRUNC('month', order_date)     

)

SELECT 
    product_id,
    sales_month,
    monthly_revenue,

    AVG(monthly_revenue) OVER(PARTITION BY product_id ORDER BY sales_month ROWS BETWEEN 2 PROCEDDING AND CURRENT ROW) AS rolling_3_month_average,
    SUM(monthly_revenue) OVER(PARTITION BY product_id ORDER BY sales_month) AS running_total
FROM monthly_sales;


/*Question 2 — Gap & Islands
Business Requirement

Find every customer's longest consecutive login streak.*/

WITH customer_logins AS
(
    SELECT

        customer_id,

        login_date,

        LAG(login_date)
        OVER
        (
            PARTITION BY customer_id
            ORDER BY login_date
        ) AS previous_login

    FROM user_logins
),

login_flags AS
(
    SELECT
        *,

        CASE

            WHEN previous_login IS NULL
                 OR login_date - previous_login > 1

            THEN 1

            ELSE 0

        END AS flag

    FROM customer_logins
),

islands AS
(
    SELECT
        *,

        SUM(flag)
        OVER
        (
            PARTITION BY customer_id
            ORDER BY login_date
        ) AS island_id

    FROM login_flags
),

streaks AS
(
    SELECT

        customer_id,

        island_id,

        COUNT(*) AS streak_length

    FROM islands

    GROUP BY
        customer_id,
        island_id
)

SELECT

    customer_id,

    MAX(streak_length) AS longest_streak

FROM streaks

GROUP BY customer_id;


/*Question 3 — LEAD()
Business Requirement

Calculate the number of days until every customer's next order.*/

WITH customers_orders AS
(
    SELECT 
        customer_id,
        order_date,
        LEAD(order_date) OVER(PARTITION BY customer_id ORDER BY order_date) AS next_order
    FROM fact_sales    
)
SELECT 
    customer_id,
    order_date,
    next_order,
    next_order - order_date AS days_until_next_order
FROM customers_orders;



/*Question 4 — FIRST_VALUE / LAST_VALUE
Business Requirement

For every product,

show

First Month Revenue
Last Month Revenue*/

WITH monthly_sales AS
(
    SELECT

        product_id,

        DATE_TRUNC('month',order_date) AS sales_month,

        SUM(sales_revenue) AS revenue

    FROM fact_sales

    GROUP BY
        product_id,
        DATE_TRUNC('month',order_date)
)

SELECT

    product_id,

    sales_month,

    revenue,

    FIRST_VALUE(revenue)
    OVER
    (
        PARTITION BY product_id
        ORDER BY sales_month
    ) AS first_month_revenue,

    LAST_VALUE(revenue)
    OVER
    (
        PARTITION BY product_id
        ORDER BY sales_month
        ROWS BETWEEN
        UNBOUNDED PRECEDING
        AND UNBOUNDED FOLLOWING
    ) AS last_month_revenue

FROM monthly_sales;


/*Question 5 — NTILE()
Business Requirement

Divide customers into

5 spending groups

based on

Lifetime Revenue.*/

WITH customer_revenue AS
(
    SELECT

        customer_id,

        SUM(sales_revenue) AS lifetime_revenue

    FROM fact_sales

    GROUP BY customer_id
)

SELECT

    customer_id,

    lifetime_revenue,

    NTILE(5)
    OVER
    (
        ORDER BY lifetime_revenue DESC
    ) AS spending_bucket

FROM customer_revenue;
