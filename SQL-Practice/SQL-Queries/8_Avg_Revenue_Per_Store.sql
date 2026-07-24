/*Query 8 – Average Revenue Per Store Type

Business wants

Mall stores

Standalone stores

Airport stores

Outlet stores

Which performs best?*/

SELECT 
    s.store_type,
    ROUND(AVG(f.sales_amount),2) AS average_order_value,
    SUM(f.sales_amount) AS total_revenue
FROM fact_sales f
JOIN dim_stores s ON f.store_id = s.store_id
GROUP BY s.store_type
ORDER BY total_revenue DESC;


/*"store_type","average_order_value","total_revenue"
"Outlet","4028.11","92449259.30"
"Mall","4029.85","72670215.35"
"Standalone","3943.51","35554664.30"
*/




