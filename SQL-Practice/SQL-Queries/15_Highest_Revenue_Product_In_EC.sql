/*Query 15 – Highest Revenue Product in Every Category

Business asks

"Show only the single highest-revenue product from each category."*/


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
WHERE rn <= 1


/*"category","product_name","total_revenue","rn"
"Accessories","Canon Accessories 263","1598188.80","1"
"Audio","Bose Audio 144","1554740.10","1"
"Camera","Canon Camera 178","1602917.25","1"
"Gaming","HP Gaming 204","1505119.20","1"
"Laptop","Asus Laptop 20","1541504.85","1"
"Phone","Dell Phone 53","1504189.05","1"
"TV","Canon TV 108","1408460.20","1"
"Tablet","Sony Tablet 67","1521541.60","1"
"Wearables","Sony Wearables 220","1395209.20","1"
*/