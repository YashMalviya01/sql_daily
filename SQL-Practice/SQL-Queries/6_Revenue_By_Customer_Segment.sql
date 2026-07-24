/*Query 6 – Revenue by Customer Segment
Business Scenario

The Marketing Director asks:

"Which customer segment generates the most revenue and profit?"

Customer segments are:

Regular
Premium
Corporate

This helps decide where the company should invest its marketing budget.*/

SELECT 
    c.customer_segment,
    SUM(f.sales_amount) AS total_revenue,
    SUM(f.profit) AS total_profit,
    COUNT(f.sale_id) AS total_orders
FROM fact_sales f
JOIN dim_customers c ON f.customer_id = c.customer_id
GROUP BY c.customer_segment
ORDER BY total_revenue DESC;    

/*"customer_segment","total_revenue","total_profit","total_orders"
"Premium","68779484.20","22356812.54","17024"
"Regular","66443513.35","21615947.18","16725"
"Corporate","65451141.40","21244011.36","16251"
*/