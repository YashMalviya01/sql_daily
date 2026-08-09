/*An e-commerce company wants to identify customers who have made purchases from at least 3 different product categories.*/

SELECT
    customer_id,
    COUNT(DISTINCT p.category) AS category_count,
    SUM(f.sales_amount) AS total_spent
FROM fact_sales f
JOIN dim_products p ON f.product_id = p.product_id
GROUP BY f.customer_id
HAVING COUNT(DISTINCT p.category) >= 3
ORDER BY total_spent DESC
         category_count DESC;     
