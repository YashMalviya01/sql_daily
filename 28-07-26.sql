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


/*Question 6 — Hard
Business Requirement

Find the top 3 products by revenue within each product category.*/

WITH product_revenue AS
(
SELECT 
    p.category,
    p.product_name,
    SUM(f.sales_amount) AS total_revenue,
    ROW_NUMBER() OVER (PARTITION BY p.category ORDER BY SUM(f.sales_amount) DESC) AS rn
FROM fact_sales f    
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.category,
         p.product_name

)

SELECT *
FROM product_revenue
WHERE rn <= 3;


/*Question 7 — Hard
Business Requirement

Find customers who have placed orders in three or more consecutive months.*/


WITH monthly_orders AS
(
    SELECT DISTINCT
        f.customer_id,
        DATE_TRUNC('month', f.order_date) AS order_month
    FROM fact_sales f
),

ordered_months AS
(
    SELECT
        customer_id,
        order_month,
        LAG(order_month) OVER(
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS prev_month
    FROM monthly_orders
)

SELECT *
FROM ordered_months;


/*Question 8 — Hard
Business Requirement

Find the average order value for every customer and compare it with the overall company average.*/


WITH customer_orders AS 
(
    SELECT 
        customer_id,
        AVG(sales_amount) AS avg_order_value
    FROM fact_sales
    GROUP BY customer_id
)

SELECT 
    customer_id,
    avg_order_value,
    AVG(avg_order_value) OVER() AS company_avg,
    avg_order_value - AVG(avg_order_value) OVER() AS difference_from_company_avg
FROM customer_orders;


/*Question 9 — Hard
Business Requirement

Find the highest revenue month for every store.*/


WITH monthly_sales AS 
(SELECT
    store_id,
    DATE_TRUNC('month', order_date) AS sales_month,
    SUM(total_amount) AS total_revenue
FROM fact_sales
GROUP BY store_id,
         DATE_TRUNC('month', order_date)
),

 ranked_sales AS
 (SELECT
    store_id,
    sales_month,
    total_revenue,
    ROW_NUMBER() OVER (PARTITION BY store_id ORDER BY total_revenue DESC) AS rn
FROM monthly_sales
 )

 SELECT *
    FROM ranked_sales
    WHERE rn = 1;


/*Question 10 — Hard
Business Requirement

Find the top customer contributing to revenue in each state.*/

WITH customer_revenue AS
(
    SELECT
        c.state,
        c.customer_id,
        c.customer_name,
        SUM(f.sales_amount) AS revenue,
        ROW_NUMBER() OVER(
            PARTITION BY c.state
            ORDER BY SUM(f.sales_amount) DESC
        ) AS rn
    FROM fact_sales f
    JOIN dim_customers c
        ON f.customer_id = c.customer_id
    GROUP BY
        c.state,
        c.customer_id,
        c.customer_name
)

SELECT *
FROM customer_revenue
WHERE rn = 1;
