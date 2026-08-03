/*Query 1. Business Requirement

The Sales Director wants to reward the most consistent customers.

Write a SQL query to:

Find customers who have placed at least one order in every month of a given year.
Calculate their total yearly revenue.
Calculate their average monthly revenue.
Rank them by total yearly revenue.
Return the Top 10 customers.*/

WITH monthly_customers AS
(
    SELECT
        c.customer_id,
        c.customer_name,

        EXTRACT(YEAR FROM f.order_date) AS sales_year,

        COUNT(DISTINCT DATE_TRUNC('month', f.order_date)) AS order_months,

        SUM(f.sales_amount) AS total_revenue,

        ROUND
        (
            SUM(f.sales_amount)
            /
            COUNT(DISTINCT DATE_TRUNC('month', f.order_date)),
            2
        ) AS avg_monthly_revenue

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        EXTRACT(YEAR FROM f.order_date)

    HAVING
        COUNT(DISTINCT DATE_TRUNC('month', f.order_date)) = 12
),

ranked_customers AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY sales_year
            ORDER BY total_revenue DESC
        ) AS rn

    FROM monthly_customers
)

SELECT *

FROM ranked_customers

WHERE rn <= 10

ORDER BY
    sales_year,
    rn;


/*Business Requirement

The Customer Success team wants to identify customers who returned after being inactive.

Write a SQL query to:

Find each customer's monthly orders.
Identify the previous order month.
Calculate the gap in months between consecutive orders.
Identify customers who returned after at least 3 months of inactivity.
Calculate each customer's lifetime revenue.
Rank those customers by lifetime revenue.
Return the Top 10 returning customers.*/


WITH monthly_orders AS
(
    SELECT
        c.customer_id,
        c.customer_name,

        DATE_TRUNC('month',f.order_date) AS order_month,

        SUM(f.sales_revenue) AS monthly_revenue

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        DATE_TRUNC('month',f.order_date)
),

customer_history AS
(
    SELECT
        *,

        LAG(order_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_order_month

    FROM monthly_orders
),
inactive_customers AS
(
    SELECT
        *,

        (
            EXTRACT(YEAR FROM AGE(order_month, previous_order_month)) * 12
            +
            EXTRACT(MONTH FROM AGE(order_month, previous_order_month))
        ) AS inactive_months

    FROM customer_history
),

customer_metrics AS
(
    SELECT
        *,

        SUM(monthly_revenue) OVER
        (
            PARTITION BY customer_id
        ) AS lifetime_revenue

    FROM inactive_customers
),
ranked_customers AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            ORDER BY lifetime_revenue DESC
        ) AS rn

    FROM customer_metrics

    WHERE inactive_months >= 3
)

SELECT

    customer_id,
    customer_name,

    previous_order_month,

    order_month,

    inactive_months,

    monthly_revenue,

    lifetime_revenue,

    rn

FROM ranked_customers

WHERE rn <= 10

ORDER BY rn;


/*Business Requirement

The Finance team wants to identify the fastest-growing products.

Write a SQL query to:

Calculate each product's yearly revenue.
Calculate the previous year's revenue.
Calculate the YoY Growth %.
Calculate the company average product revenue for the same year.
Calculate each product's contribution % to company revenue.
Calculate each product's lifetime revenue.
Rank products within each category based on YoY Growth %.
Return the Top 3 fastest-growing products from each category.*/



WITH product_yearly_revenue AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,

        EXTRACT(YEAR FROM f.order_date) AS sales_year,

        SUM(f.sales_revenue) AS yearly_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        EXTRACT(YEAR FROM f.order_date)
),

product_metrics AS
(
    SELECT
        *,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_year
        ) AS previous_year_revenue,

        AVG(yearly_revenue) OVER
        (
            PARTITION BY sales_year
        ) AS company_average_revenue,

        SUM(yearly_revenue) OVER
        (
            PARTITION BY sales_year
        ) AS company_total_revenue,

        SUM(yearly_revenue) OVER
        (
            PARTITION BY product_id
        ) AS lifetime_revenue

    FROM product_yearly_revenue
),

product_performance AS
(
    SELECT
        *,

        ROUND
        (
            (
                yearly_revenue
                -
                previous_year_revenue
            )
            *100.0
            /
            NULLIF(previous_year_revenue,0),
            2
        ) AS yoy_growth_percent,

        ROUND
        (
            yearly_revenue
            *100.0
            /
            NULLIF(company_total_revenue,0),
            2
        ) AS contribution_percent,

        ROUND
        (
            (
                yearly_revenue
                -
                company_average_revenue
            )
            *100.0
            /
            NULLIF(company_average_revenue,0),
            2
        ) AS revenue_vs_company_average

    FROM product_metrics
),

ranked_products AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY category, sales_year
            ORDER BY yoy_growth_percent DESC
        ) AS rn

    FROM product_performance
)


SELECT

    product_id,
    product_name,
    category,

    sales_year,

    yearly_revenue,

    previous_year_revenue,

    yoy_growth_percent,

    company_average_revenue,

    company_total_revenue,

    contribution_percent,

    revenue_vs_company_average,

    lifetime_revenue,

    rn

FROM ranked_products

WHERE rn <= 3

ORDER BY
    category,
    sales_year,
    rn;


/*Business Requirement

The Marketing team wants to identify the company's VIP customers.

For every customer:

Calculate the Recency (days since the customer's last purchase).
Calculate the Frequency (total number of orders).
Calculate the Monetary Value (total revenue generated).
Divide customers into 5 groups based on each metric using NTILE(5).
Calculate an RFM Score by combining the three scores.
Return the Top 20 VIP customers.*/ 

WITH customer_metrics AS
(
    SELECT
        c.customer_id,
        c.customer_name,

        MAX(f.order_date) AS last_purchase_date,

        CURRENT_DATE - MAX(f.order_date) AS recency_days,

        COUNT(DISTINCT f.order_id) AS frequency,

        SUM(f.sales_revenue) AS monetary

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name
),

rfm_scores AS
(
    SELECT
        *,

        NTILE(5) OVER
        (
            ORDER BY recency_days ASC
        ) AS recency_score,

        NTILE(5) OVER
        (
            ORDER BY frequency DESC
        ) AS frequency_score,

        NTILE(5) OVER
        (
            ORDER BY monetary DESC
        ) AS monetary_score

    FROM customer_metrics
),

ranked_customers AS
(
    SELECT
        *,

        (recency_score + frequency_score + monetary_score) AS rfm_score,

        ROW_NUMBER() OVER
        (
            ORDER BY
            (recency_score + frequency_score + monetary_score) DESC
        ) AS rn

    FROM rfm_scores
)

SELECT *

FROM ranked_customers

WHERE rn <= 20;


/* Query 5. Business Requirement

Find products that are frequently purchased together.

For every pair of products:

Find products purchased in the same order.
Count how many orders contain that pair.
Calculate the total revenue generated by those orders.
Rank product pairs by purchase frequency.
Return the Top 10 product combinations.*/

WITH product_pairs AS
(
    SELECT

        p1.product_name AS product_1,

        p2.product_name AS product_2,

        COUNT(DISTINCT f1.order_id) AS orders_together,

        SUM(f1.sales_revenue + f2.sales_revenue) AS total_revenue

    FROM fact_sales f1

    JOIN fact_sales f2

        ON f1.order_id = f2.order_id

       AND f1.product_id < f2.product_id

    JOIN dim_products p1

        ON f1.product_id = p1.product_id

    JOIN dim_products p2

        ON f2.product_id = p2.product_id

    GROUP BY

        p1.product_name,

        p2.product_name
),

ranked_pairs AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            ORDER BY orders_together DESC
        ) AS rn

    FROM product_pairs
)

SELECT *

FROM ranked_pairs

WHERE rn <= 10;
