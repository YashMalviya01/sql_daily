/*Query 4 — Top Performing Stores
Business Problem

Regional managers want to identify the highest-performing stores.*/


SELECT
    s.store_name,
    s.city,
    SUM(f.sales_amount) AS revenue,
    SUM(f.profit) AS total_profit,
    SUM(f.quantity) AS total_quantity_sold
FROM fact_sales f
JOIN dim_stores s ON f.store_id = s.store_id
GROUP BY 
    s.store_name,
    s.city
ORDER BY revenue DESC;        


/*"store_name","city","revenue","total_profit","total_quantity_sold"
"Dallas Store","Dallas","18800083.40","6100067.44","13931"
"New York Store","New York","18644144.65","6033277.54","13955"
"Vancouver Store","Vancouver","18559054.85","6010373.20","13615"
"Los Angeles Store","Los Angeles","18543370.40","6044766.79","13988"
"Sydney Store","Sydney","18519834.55","6014299.68","13958"
"London Store","London","18342800.20","5973209.89","13507"
"Munich Store","Munich","18182854.85","5931307.84","13639"
"Austin Store","Austin","17927223.75","5853484.74","13454"
"San Diego Store","San Diego","17841259.75","5809431.51","13493"
"Toronto Store","Toronto","17713404.55","5734224.43","13437"
"Manchester Store","Manchester","17600108.00","5712328.02","13303"
*/