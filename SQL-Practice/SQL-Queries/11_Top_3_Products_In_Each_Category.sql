/*Query 11 – Top 3 Products in Each Category
Business Scenario

The Product Manager asks:

"Show me the top 3 products in every category based on revenue."*/


WITH product_revenue AS 
(
    SELECT
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS total_revenue
    FROM fact_sales AS f
    JOIN dim_products p ON f.product_id = p.product_id
    GROUP BY p.category, p.product_name
)
SELECT *
FROM
(
    SELECT*,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rn
    FROM product_revenue    
) ranked_products
WHERE rn <= 3


/*"category","product_name","total_revenue","rn"
"Accessories","Canon Accessories 263","1598188.80","1"
"Accessories","Sony Accessories 249","1363032.90","2"
"Accessories","LG Accessories 257","1293763.45","3"
"Audio","Bose Audio 144","1554740.10","1"
"Audio","Lenovo Audio 126","1332250.05","2"
"Audio","Dell Audio 145","1322454.15","3"
"Camera","Canon Camera 178","1602917.25","1"
"Camera","HP Camera 155","1375130.75","2"
"Camera","Apple Camera 163","1253370.30","3"
"Gaming","HP Gaming 204","1505119.20","1"
"Gaming","Samsung Gaming 206","1468540.80","2"
"Gaming","Apple Gaming 183","1418645.75","3"
"Laptop","Asus Laptop 20","1541504.85","1"
"Laptop","Asus Laptop 5","1444816.00","2"
"Laptop","Bose Laptop 4","1405608.75","3"
"Phone","Dell Phone 53","1504189.05","1"
"Phone","LG Phone 32","1431316.90","2"
"Phone","Asus Phone 49","1409458.50","3"
"TV","Canon TV 108","1408460.20","1"
"TV","Apple TV 112","1400812.20","2"
"TV","Samsung TV 94","1321963.20","3"
"Tablet","Sony Tablet 67","1521541.60","1"
"Tablet","Asus Tablet 88","1337194.80","2"
"Tablet","Bose Tablet 72","1314503.75","3"
"Wearables","Sony Wearables 220","1395209.20","1"
"Wearables","Sony Wearables 234","1337573.60","2"
"Wearables","Samsung Wearables 211","1331234.60","3"
*/