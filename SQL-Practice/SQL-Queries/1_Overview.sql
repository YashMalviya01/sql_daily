/*Query 1 - Executice KPI Dashboard 
        CEO wants an overview of company performance
        FIND - Total Revenue
                Total Profit
                Total Quantity Sold
                Average Order Value
                Total Orders*/


SELECT 
    SUM(sales_amount) AS total_revenue,
    SUM(profit) AS total_profit,
    SUM(quantity) AS total_quantity_sold,
    ROUND(AVG(sales_amount),2) AS average_order_value,
    COUNT(sale_id) AS total_orders
FROM fact_sales    


"total_revenue","total_profit","total_quantity_sold","average_order_value","total_orders"
"200674138.95","65216771.08","150280","4013.48","50000"
