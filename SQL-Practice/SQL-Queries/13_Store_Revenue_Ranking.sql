/*Query 13 – Store Revenue Ranking
Business Scenario

Management wants every store ranked by revenue.*/


SELECT
    s.store_name,
    SUM(f.sales_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(f.sales_amount)DESC) AS revenue_rank
FROM fact_sales f
JOIN dim_stores s ON f.store_id = s.store_id
GROUP BY s.store_name


/*"store_name","total_revenue","revenue_rank"
"Dallas Store","18800083.40","1"
"New York Store","18644144.65","2"
"Vancouver Store","18559054.85","3"
"Los Angeles Store","18543370.40","4"
"Sydney Store","18519834.55","5"
"London Store","18342800.20","6"
"Munich Store","18182854.85","7"
"Austin Store","17927223.75","8"
"San Diego Store","17841259.75","9"
"Toronto Store","17713404.55","10"
"Manchester Store","17600108.00","11"
*/