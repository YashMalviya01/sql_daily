/*Query 2 — Top 10 Revenue-Generating Products
Business Problem

Management wants to identify which products generate the highest revenue.*/


SELECT 
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM fact_sales f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_revenue DESC


/*"product_name","total_revenue"
"Canon Camera 178","1602917.25"
"Canon Accessories 263","1598188.80"
"Bose Audio 144","1554740.10"
"Asus Laptop 20","1541504.85"
"Sony Tablet 67","1521541.60"
"HP Gaming 204","1505119.20"
"Dell Phone 53","1504189.05"
"Samsung Gaming 206","1468540.80"
"Asus Laptop 5","1444816.00"
"LG Phone 32","1431316.90"*/
