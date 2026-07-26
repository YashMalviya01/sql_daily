/*Query 16 – Month-over-Month (MoM) Revenue Growth
Business Scenario

The CFO asks:

"How much did revenue grow or decline compared to the previous month?"*/


WITH monthly_sales AS
(
SELECT
    d.year,
    d.month,
    SUM(f.sales_amount) AS revenue
FROM fact_sales f
JOIN dim_date d ON f.date_id = d.date_id
GROUP BY d.year, d.month
ORDER BY d.year, d.month   
)

SELECT 
    year,
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY year, month) AS previous_month_revenue,
    revenue - LAG(revenue) OVER (ORDER BY year, month) AS growth
    
FROM monthly_sales;