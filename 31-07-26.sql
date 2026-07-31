/*Query 1 Business Scenario

The management team wants to analyze the performance of stores across different countries.

Write a SQL query to generate a report that satisfies the following requirements:

Find the top 3 stores in each country based on current year's total sales revenue.
Calculate the total sales revenue for each store.
Calculate the average sales revenue for each store.
Calculate the company's average revenue for the same year and determine the percentage difference between each store's revenue and the company average.
Calculate each store's previous year's revenue.
Calculate the Year-over-Year (YoY) growth percentage for each store by comparing the current year's revenue with the previous year's revenue.
Rank stores within each country based on current year's total sales revenue.
Return only the top 3 ranked stores from each country.*/

WITH yearly_sales AS
(
    SELECT 
        s.store_id,
        s.store_name,
        s.country,
        EXTRACT(YEAR FROM f.date_id) AS sales_year,
        SUM(f.sales_amount) AS yearly_revenue,
        AVG(f.sales_amount) AS avg_revenue
    FROM fact_sales f
    JOIN dim_stores s ON f.store_id = s.store_id
    GROUP BY s.store_id,
        s.store_name,
        s.country,
        EXTRACT(YEAR FROM f.date_id)  
 ),

 revenue_comparision AS 
 (
    SELECT *,
    LAG(yearly_revenue) OVER(PARTITION BY store_id ORDER BY sales_amount) AS previous_year_revenue
    FROM yearly_sales 
 ),

 growth_metrics AS 
 (
    SELECT *,
    AVG(yearly_revenue) OVER() AS company_avg_revenue,
    ROUND((yearly_revenue - AVG(yearly_revenue)OVER())*100.0 / AVG(yearly_revenue)OVER(),2) AS company_growth_pct,
    ROUND((yearly_revenue - previous_year_revenue)*100.0 / NULLIF(previous_year_revenue,0),2) AS yoy_growth_pct
    FROM revenue_comparision
 ),

 ranked_stores AS
    (
        SELECT *,
        ROW_NUMBER() OVER(PARTITION BY country ORDER BY yearly_revenue DESC) AS rn
        FROM growth_metrics
    )

SELECT 
    store_id,
    store_name,
    country,
    yearly_revenue,
    avg_revenue,
    company_avg_revenue,
    company_growth_pct,
    yoy_growth_pct
FROM ranked_stores
WHERE rn <= 3
ORDER BY country, 
         sales_amount,
         rn;



/*Query 2 Business Scenario

The Sales Director wants to identify the best-performing product categories in each country.

Task

Write a SQL query to:

Calculate the total sales revenue for every product category in each country.
Calculate the average sales amount for each category.
Rank product categories within each country based on total revenue.
Return only the top 2 categories from each country.*/


WITH top_category AS
(
    SELECT
        f.country,
        p.category,
        SUM(f.sales_revenue) AS total_revenue,
        AVG(f.sales_revenue) AS average_revenue
    FROM fact_sales f
    JOIN dim_products p
        ON f.product_id = p.product_id
    GROUP BY
        f.country,
        p.category
),

ranked_category AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY country
            ORDER BY total_revenue DESC
        ) AS rn
    FROM top_category
)

SELECT *
FROM ranked_category
WHERE rn <= 2;


/*Query 3 Business Scenario

Management wants to identify valuable customers across different countries.

Task

Write a SQL query to:

Calculate each customer's total revenue.
Calculate the customer's total number of orders.
Calculate the average order value for each customer.
Calculate the company-wide average customer revenue.
Show only customers whose revenue is above the company average.
Rank customers within each country by total revenue.*/


-- Step 1: Calculate customer-level metrics

WITH customer_metrics AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.country,

        SUM(f.sales_revenue) AS total_revenue,

        COUNT(DISTINCT f.order_id) AS total_orders,

        ROUND(
            SUM(f.sales_revenue) * 1.0
            /
            COUNT(DISTINCT f.order_id),
            2
        ) AS average_order_value

    FROM fact_sales f
    JOIN dim_customer c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        c.country
),

-- Step 2: Calculate company average revenue and
-- keep only customers above company average

above_average_customer AS
(
    SELECT
        *,
        AVG(total_revenue) OVER() AS company_average_revenue

    FROM customer_metrics
),

-- Step 3: Rank customers within each country

ranked_customer AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY country
            ORDER BY total_revenue DESC
        ) AS rn

    FROM above_average_customer
    WHERE total_revenue > company_average_revenue
)

SELECT
    customer_id,
    customer_name,
    country,
    total_orders,
    total_revenue,
    average_order_value,
    company_average_revenue,
    rn

FROM ranked_customer
ORDER BY
    country,
    rn;



/* Question 4 Business Scenario

The Finance team wants to analyze yearly product performance.

Task

Write a SQL query to:

Calculate yearly revenue for every product category.
Calculate the previous year's revenue for each category.
Calculate the YoY growth percentage.
Calculate the company's average yearly revenue for the same year.
Compare every category's revenue with the company average.
Rank categories by YoY growth for each year.
Return only the top 5 categories for every year.*/

-- Step 1: Calculate yearly revenue for each product category

WITH yearly_category_sales AS
(
    SELECT
        p.category,
        EXTRACT(YEAR FROM f.order_date) AS sales_year,

        SUM(f.sales_revenue) AS yearly_revenue

    FROM fact_sales f
    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.category,
        EXTRACT(YEAR FROM f.order_date)
),

-- Step 2: Get previous year's revenue

previous_year_sales AS
(
    SELECT
        *,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY category
            ORDER BY sales_year
        ) AS previous_year_revenue

    FROM yearly_category_sales
),

-- Step 3: Calculate YoY Growth and Company Average

category_metrics AS
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
        ) AS yoy_growth,

        AVG(yearly_revenue) OVER
        (
            PARTITION BY sales_year
        ) AS company_average_revenue

    FROM previous_year_sales
),

-- Step 4: Rank categories for each year

ranked_categories AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY sales_year
            ORDER BY yoy_growth DESC
        ) AS rn

    FROM category_metrics
)

SELECT
    category,
    sales_year,
    yearly_revenue,
    previous_year_revenue,
    yoy_growth,
    company_average_revenue,
    rn

FROM ranked_categories

WHERE rn <= 5

ORDER BY
    sales_year,
    rn;


/*Business Scenario

The Operations team wants to evaluate seller performance across all countries.

Task

Write a SQL query to:

Calculate each seller's yearly revenue.
Calculate each seller's average order value.
Calculate the previous year's revenue using LAG().
Calculate YoY growth percentage.
Calculate the company's average seller revenue for the same year.
Compare each seller's revenue against the company average.
Find each seller's highest-selling product category.
Rank sellers within each country based on current year's revenue.
Return only the top 3 sellers from each country.
Concepts Tested*/


-- Step 1: Calculate yearly seller metrics

WITH seller_metrics AS
(
    SELECT
        s.seller_id,
        s.seller_name,
        st.country,

        EXTRACT(YEAR FROM f.order_date) AS sales_year,

        SUM(f.sales_revenue) AS yearly_revenue,

        COUNT(DISTINCT f.order_id) AS total_orders,

        ROUND(
            SUM(f.sales_revenue) * 1.0 /
            COUNT(DISTINCT f.order_id),
            2
        ) AS average_order_value

    FROM fact_sales f
    JOIN dim_seller s
        ON f.seller_id = s.seller_id
    JOIN dim_store st
        ON f.store_id = st.store_id

    GROUP BY
        s.seller_id,
        s.seller_name,
        st.country,
        EXTRACT(YEAR FROM f.order_date)
),

-- Step 2: Previous year revenue, YoY Growth and Company Average

seller_growth AS
(
    SELECT
        *,

        LAG(yearly_revenue) OVER
        (
            PARTITION BY seller_id
            ORDER BY sales_year
        ) AS previous_year_revenue,

        AVG(yearly_revenue) OVER
        (
            PARTITION BY sales_year
        ) AS company_average_revenue

    FROM seller_metrics
),

-- Step 3: Revenue by Seller and Category

seller_category AS
(
    SELECT
        f.seller_id,
        p.category,

        SUM(f.sales_revenue) AS category_revenue

    FROM fact_sales f
    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        f.seller_id,
        p.category
),

-- Step 4: Highest-selling category for each seller

top_category AS
(
    SELECT
        *,

        ROW_NUMBER() OVER
        (
            PARTITION BY seller_id
            ORDER BY category_revenue DESC
        ) AS category_rank

    FROM seller_category
),

-- Step 5: Final Seller Ranking

ranked_seller AS
(
    SELECT
        sg.*,

        ROUND(
            (
                yearly_revenue
                -
                previous_year_revenue
            ) * 100.0 /
            NULLIF(previous_year_revenue,0),
            2
        ) AS yoy_growth,

        tc.category,

        ROW_NUMBER() OVER
        (
            PARTITION BY country
            ORDER BY yearly_revenue DESC
        ) AS rn

    FROM seller_growth sg
    LEFT JOIN top_category tc
        ON sg.seller_id = tc.seller_id
       AND tc.category_rank = 1
)

SELECT
    seller_id,
    seller_name,
    country,
    sales_year,
    yearly_revenue,
    total_orders,
    average_order_value,
    company_average_revenue,
    previous_year_revenue,
    yoy_growth,
    category AS highest_selling_category,
    rn

FROM ranked_seller

WHERE rn <= 3

ORDER BY
    country,
    rn;

