/*Question 1 — Level 2

Business Requirement

Find the top 5 customers who generated the highest revenue in each country.*/

WITH customer_revenue AS (
    SELECT
        c.customer_id,
        c.customer_name,
        c.country,
        SUM(f.total_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY c.country
            ORDER BY SUM(f.total_amount) DESC
        ) AS rn
    FROM fact_sales f
    JOIN dim_customers c
        ON f.customer_id = c.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name,
        c.country
)

SELECT *
FROM customer_revenue
WHERE rn <= 5;








/*Question 2 — Level 2

Business Requirement

Find the highest-selling product category in every store.*/

WITH top_category AS (
    SELECT
        s.store_id,
        s.store_name,
        p.product_category,
        SUM(f.total_amount) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY s.store_id
            ORDER BY SUM(f.total_amount) DESC
        ) AS rn
    FROM fact_sales f
    JOIN dim_stores s
        ON f.store_id = s.store_id
    JOIN dim_product p
        ON f.product_id = p.product_id
    GROUP BY
        s.store_id,
        s.store_name,
        p.product_category
)

SELECT *
FROM top_category
WHERE rn = 1;




/*Question 3 — Medium
Business Requirement

For each employee, calculate their total sales and determine what percentage of the company's total revenue they contributed.*/

SELECT
    e.employee_id,
    e.employee_name,
    COUNT(f.order_id) AS total_orders,
    SUM(f.total_amount) AS total_revenue,
    ROUND(
        SUM(f.total_amount) * 100.0 /
        SUM(SUM(f.total_amount)) OVER (),
        2
    ) AS contribution_percentage
FROM fact_sales f
JOIN dim_employees e
    ON f.employee_id = e.employee_id
GROUP BY
    e.employee_id,
    e.employee_name;


/*Question 4 — Medium
Business Requirement

For each product, calculate the month-over-month revenue growth percentage.*/

WITH monthly_sales AS
(
    SELECT
        p.product_name,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.total_amount) AS monthly_revenue
    FROM fact_sales f
    JOIN dim_products p
        ON f.product_id = p.product_id
    GROUP BY
        p.product_name,
        DATE_TRUNC('month', f.order_date)
)

SELECT
    product_name,
    sales_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER(
        PARTITION BY product_name
        ORDER BY sales_month
    ) AS previous_month_revenue,
    ROUND(
        (
            monthly_revenue -
            LAG(monthly_revenue) OVER(
                PARTITION BY product_name
                ORDER BY sales_month
            )
        ) * 100.0
        /
        LAG(monthly_revenue) OVER(
            PARTITION BY product_name
            ORDER BY sales_month
        ),
        2
    ) AS growth_percentage
FROM monthly_sales;


/*Question 5 — Medium/Hard
Business Requirement

Calculate the cumulative (running) revenue for each store ordered by sale date.*/


WITH daily_sales AS
(
    SELECT
        s.store_name,
        f.order_date,
        SUM(f.total_amount) AS daily_revenue
    FROM fact_sales f
    JOIN dim_store s
        ON f.store_id = s.store_id
    GROUP BY
        s.store_name,
        f.order_date
)

SELECT
    store_name,
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER(
        PARTITION BY store_name
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_revenue
FROM daily_sales
ORDER BY
    store_name,
    order_date;
