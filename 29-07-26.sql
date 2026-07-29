/*Question 11 (Single CTE)
Business Requirement

Find the top 5 customers in each state based on total revenue generated.*/

WITH top_customers AS
(
SELECT
    c.customer_id,
    c.first_name,
    c.country,
    SUM(f.sales_amount) AS total_revenue,
    ROW_NUMBER() OVER
    (
        PARTITION BY c.country
        ORDER BY SUM(f.sales_amount) DESC
    ) AS rn
FROM fact_sales f
JOIN dim_customer c
ON f.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.country
)

SELECT *
FROM top_customers
WHERE rn <= 5;





/*Question 12 (Single Query)
Business Requirement

Find all products whose average selling price is greater than the overall company average selling price.*/

WITH avg_price AS
(
    SELECT
        p.product_id,
        p.product_name,
        AVG(f.sales_amount) AS avg_selling_price
    FROM fact_sales f
    JOIN dim_products p
        ON f.product_id = p.product_id
    GROUP BY
        p.product_id,
        p.product_name
),

company_avg AS
(
    SELECT
        product_id,
        product_name,
        avg_selling_price,
        AVG(avg_selling_price) OVER () AS company_average
    FROM avg_price
)

SELECT
    product_id,
    product_name,
    avg_selling_price,
    company_average
FROM company_avg
WHERE avg_selling_price > company_average;



/*Question 13 (Two CTEs)
Business Requirement

For each category, find the customer who spent the most money.*/
WITH customer_category_sales AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        p.category,
        SUM(f.sales_amount) AS total_spent
    FROM fact_sales f
    JOIN dim_customers c
        ON f.customer_id = c.customer_id
    JOIN dim_products p
        ON f.product_id = p.product_id
    GROUP BY
        c.customer_id,
        c.customer_name,
        p.category
),

ranked_customers AS
(
    SELECT
        customer_id,
        customer_name,
        category,
        total_spent,
        ROW_NUMBER() OVER
        (
            PARTITION BY category
            ORDER BY total_spent DESC
        ) AS rn
    FROM customer_category_sales
)

SELECT
    customer_id,
    customer_name,
    category,
    total_spent
FROM ranked_customers
WHERE rn = 1;






/*Question 14 (Three CTEs)
Business Requirement

Find customers whose revenue increased every month for the last 4 consecutive months.*/

WITH monthly_revenue AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        DATE_TRUNC('month', f.order_date) AS order_month,
        SUM(f.sales_amount) AS monthly_revenue
    FROM fact_sales f
    JOIN dim_customers c
        ON f.customer_id = c.customer_id
    GROUP BY
        c.customer_id,
        c.customer_name,
        DATE_TRUNC('month', f.order_date)
),

revenue_comparison AS
(
    SELECT
        customer_id,
        customer_name,
        order_month,
        monthly_revenue,
        LAG(order_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_month,

        LAG(monthly_revenue) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_month
        ) AS previous_revenue
    FROM monthly_revenue
),

qualified_months AS
(
    SELECT
        *,
        CASE
            WHEN previous_month = order_month - INTERVAL '1 month'
             AND monthly_revenue > previous_revenue
            THEN 1
            ELSE 0
        END AS is_increasing
    FROM revenue_comparison
)

SELECT
    customer_id,
    customer_name
FROM qualified_months
GROUP BY
    customer_id,
    customer_name
HAVING COUNT(*) FILTER (WHERE is_increasing = 1) >= 3;




/*Question 15 (Advanced – 4 to 5 CTEs)
Business Requirement

Find the top-performing store in every region based on year-over-year revenue growth percentage. Return only stores with at least 24 months of sales history.*/

WITH yearly_sales AS
(
    SELECT
        s.store_id,
        s.store_name,
        s.region,
        EXTRACT(YEAR FROM f.order_date) AS sales_year,
        SUM(f.sales_amount) AS yearly_revenue
    FROM fact_sales f
    JOIN dim_store s
        ON f.store_id = s.store_id
    WHERE f.order_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY
        s.store_id,
        s.store_name,
        s.region,
        EXTRACT(YEAR FROM f.order_date)
),

yoy_growth AS
(
    SELECT
        store_id,
        store_name,
        region,
        sales_year,
        yearly_revenue,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY store_id
            ORDER BY sales_year
        ) AS previous_year_revenue
    FROM yearly_sales
),

growth_calculation AS
(
    SELECT
        store_id,
        store_name,
        region,
        sales_year,
        yearly_revenue,
        previous_year_revenue,

        ROUND(
            (
                (yearly_revenue - previous_year_revenue)
                * 100.0
            ) / NULLIF(previous_year_revenue,0),
            2
        ) AS yoy_growth
    FROM yoy_growth
),

ranked_store AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY region
            ORDER BY yoy_growth DESC
        ) AS rn
    FROM growth_calculation
    WHERE previous_year_revenue IS NOT NULL
)

SELECT
    region,
    store_id,
    store_name,
    sales_year,
    yearly_revenue,
    previous_year_revenue,
    yoy_growth
FROM ranked_store
WHERE rn = 1;
