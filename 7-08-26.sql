/*Business Scenario

You're working as a Data Analyst at Spotify.

The Product team wants to identify inactive listeners.

Business Requirement

For every customer,

find

Previous stream date
Days since previous stream
Flag customers who returned after 30+ days
Show only those customers*/


WITH previous_streams AS
(
    SELECT
        customer_id,
        stream,ate,
        LAG(stream_date) OVER(PARTITION BY customer_id ORDER BY stream_date) AS previous_stream_date
    FROM fact_streams    
),

inactive_customers AS
(
    SELECT 
        customer_id,
        stream_date,
        previous_month_stream_date,
        stream_date - precious_month_stream_date AS days_since_previous_stream,
        CASE WHEN previous_stream_date IS NULL THEN 0
             WHEN stream_date - previous_stream_date > 30 THEN 1 ELSE 0
        END AS inactive_flag
    FROM previous_streams     
)

SELECT
    customer_id,
    previous_stream_date,
    stream_date,
    days_since_previous_stream
FROM inactive_customers
WHERE inactive_flag = 1  
ORDER BY customer_id, stream_date;


/*Amazon has monthly sales.

The CEO says:

"Monthly revenue fluctuates too much.

Show me the trend instead."
Business Requirement

Show

Monthly Revenue
6-Month Moving Average
Running Total*/

WITH monthly_sales AS
(
    SELECT
        DATE_TRUNC('month', order_date) AS sales_month,
        SUM(total_amount) AS monthly_revenue
    FROM fact_sales
    GROUP BY DATE_TRUNC('month', order_date)
)

SELECT 
    sales_month,
    monthly_revenue,
    AVG(monthly_revenue) OVER(ORDER BY sales_month ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS rolling_6_month_average,
    SUM(monthly_revenue) OVER(ORDER BY sales_month) AS running_total_revenue
FROM monthly_sales
ORDER BY sales_month;





