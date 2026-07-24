/*Query 9 – Revenue by Payment Method

Business asks

Which payment method is most preferred?

No join required

Payment method already exists

inside

fact_sales*/

SELECT
    payment_method,
    COUNT(*) AS total_orders,
    SUM(sales_amount) AS revenue,
    ROUND(AVG(sales_amount),2) AS average_order_value
FROM fact_sales
GROUP BY payment_method
ORDER BY revenue DESC;


/*"payment_method","total_orders","revenue","average_order_value"
"Online","12550","50881242.20","4054.28"
"Card","12668","50593708.80","3993.82"
"Cash","12383","49718617.30","4015.07"
"UPI","12399","49480570.65","3990.69"
*/

