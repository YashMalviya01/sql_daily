/*Query 17 – Top Customer in Every Country
Business Scenario

The CEO asks

"Show the highest spending customer from every country."*/

WITH customer_sales AS
(
    SELECT
        c.country,
        c.customer_name,
        SUM(f.sales_amount) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY c.country ORDER BY SUM(f.sales_amount) DESC) AS rn
    FROM fact_sales f
    JOIN dim_customers c ON f.customer_id = c.customer_id
    GROUP BY c.country, c.customer_name
)
 SELECT *
 FROM customer_sales
 WHERE rn = 1   


 /*"country","customer_name","revenue","rn"
"Australia","Customer_366","180152.40","1"
"Canada","Customer_160","188728.20","1"
"Germany","Customer_1167","189728.45","1"
"UK","Customer_1897","170082.50","1"
"USA","Customer_1904","199093.60","1"
*/