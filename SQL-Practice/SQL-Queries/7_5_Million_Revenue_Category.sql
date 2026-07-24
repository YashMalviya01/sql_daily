/*Query 7 – Categories Generating More Than ₹5 Million Revenue
Business Scenario

The CEO says

Show only categories that generated more than ₹5 million revenue.*/


SELECT 
    p.category,
    SUM(f.sales_amount) AS revenue
FROM fact_sales f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.category
HAVING SUM(f.sales_amount) > 5000000
ORDER BY revenue DESC;   

/*"category","revenue"
"Tablet","25756375.75"
"Camera","23890461.65"
"Audio","23112002.00"
"Wearables","22684902.90"
"Laptop","22504624.45"
"Accessories","22393677.85"
"TV","21020313.75"
"Phone","19827615.35"
"Gaming","19484165.25"
*/