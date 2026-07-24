/*Query 10 – Return Rate by Product Category

Business wants

Which categories receive the highest returns?*/


SELECT
    p.category,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN f.returned = TRUE THEN 1 ELSE 0 END) AS returened_orders,
    ROUND(SUM(CASE WHEN f.returned = TRUE THEN 1 ELSE 0 END)* 100.0/COUNT(*),2) AS return_rate
    FROM fact_sales f
    JOIN dim_products p ON f.product_id = p.product_id
    GROUP BY p.category
    ORDER BY return_rate DESC


    /*"category","total_orders","returened_orders","return_rate"
"Wearables","5542","1411","25.46"
"Laptop","5423","1375","25.35"
"TV","5609","1404","25.03"
"Audio","5614","1388","24.72"
"Phone","5571","1372","24.63"
"Camera","5627","1385","24.61"
"Accessories","5553","1349","24.29"
"Tablet","5570","1352","24.27"
"Gaming","5491","1295","23.58"
*/