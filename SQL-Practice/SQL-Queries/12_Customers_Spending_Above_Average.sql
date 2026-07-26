/*Query 12 – Customers Spending Above the Average Customer
Business Scenario

The CEO asks:

"Which customers spend more than the average customer?"*/


SELECT 
    customer_id,
    total_spent
FROM 
(
    SELECT
        customer_id,
        SUM(sales_amount) AS total_spent
    FROM fact_sales
    GROUP BY customer_id
)customer_sales
WHERE total_spent >
(
    SELECT AVG(total_spent)
    FROM
    (
        SELECT
            customer_id,
            SUM(sales_amount) AS total_spent
        FROM fact_sales
        GROUP BY customer_id
        
    )avg_table

)    