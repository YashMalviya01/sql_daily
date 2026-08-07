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

/*4. An HR company wants to know

every employee's

longest consecutive working streak.

Business Requirement

Find the longest streak.*/


WITH employee_attendance AS
(
    SELECT
        employee_id,

        attendance_date,

        LAG(attendance_date)
        OVER
        (
            PARTITION BY employee_id
            ORDER BY attendance_date
        ) AS previous_attendance_date

    FROM attendance
),

attendance_flags AS
(
    SELECT
        *,

        CASE
            WHEN previous_attendance_date IS NULL
                 OR attendance_date - previous_attendance_date > 1
            THEN 1
            ELSE 0
        END AS flag

    FROM employee_attendance
),

attendance_islands AS
(
    SELECT
        *,

        SUM(flag)
        OVER
        (
            PARTITION BY employee_id
            ORDER BY attendance_date
        ) AS island_id

    FROM attendance_flags
),

attendance_streaks AS
(
    SELECT
        employee_id,

        island_id,

        COUNT(*) AS streak_length

    FROM attendance_islands

    GROUP BY
        employee_id,
        island_id
)

SELECT
    employee_id,

    MAX(streak_length) AS longest_streak

FROM attendance_streaks

GROUP BY employee_id

ORDER BY longest_streak DESC;

/*Uber wants to know how many days every driver waits until their next trip.
*/

WITH driver_trips AS
(
    SELECT
        driver_id,

        trip_date,

        LEAD(trip_date)
        OVER
        (
            PARTITION BY driver_id
            ORDER BY trip_date
        ) AS next_trip_date

    FROM fact_trips
)

SELECT

    driver_id,

    trip_date,

    next_trip_date,

    next_trip_date - trip_date
        AS days_until_next_trip

FROM driver_trips

ORDER BY
    driver_id,
    trip_date;






