/*Query 3 — Revenue by Product Category
Business Problem

The Sales Director wants to know which categories contribute the most revenue.*/


SELECT 
    p.category,
    SUM(f.sales_amount) AS revenue,
    SUM(f.quantity) AS units_sold,
    SUM(f.profit) AS profit
FROM fact_sales F
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY revenue DESC;    


/*"category","revenue","units_sold","profit"
"Tablet","25756375.75","16668","8375469.23"
"Camera","23890461.65","16868","7783883.87"
"Audio","23112002.00","16885","7508223.75"
"Wearables","22684902.90","16575","7327758.35"
"Laptop","22504624.45","16213","7343357.05"
"Accessories","22393677.85","16584","7325997.12"
"TV","21020313.75","16979","6825743.36"
"Phone","19827615.35","16930","6399427.80"
"Gaming","19484165.25","16578","6326910.55"*/
