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
