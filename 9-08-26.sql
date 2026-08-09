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


/*A retail company wants to find its top 5 stores by yearly revenue growth.*/

WITH yearly_revenue AS
(
    SELECT
        s.store_id,
        s.store_name,
        EXTRACT(YEAR FROM f.order_date) AS order_year,
        SUM(f.sales_amount) AS total_revenue

    FROM fact_sales f

    JOIN dim_stores s
        ON f.store_id = s.store_id

    GROUP BY
        s.store_id,
        s.store_name,
        EXTRACT(YEAR FROM f.order_date)
),

previous_year_revenue AS
(
    SELECT
        store_id,
        store_name,
        order_year,
        total_revenue,

        LAG(total_revenue) OVER (PARTITION BY store_id ORDER BY order_year) AS previous_year_revenue

    FROM yearly_revenue
),

yoy_growth AS
(
    SELECT
        store_id,
        store_name,
        order_year,
        total_revenue,
        previous_year_revenue,

        ROUND((total_revenue - previous_year_revenue)* 100.0 / NULLIF(previous_year_revenue, 0),2) AS yoy_growth_percentage

    FROM previous_year_revenue
),

latest_year AS
(
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY store_id ORDER BY order_year DESC) AS latest_year_rank

    FROM yoy_growth
),

store_rankings AS
(
    SELECT
        store_id,
        store_name,
        order_year,
        total_revenue,
        previous_year_revenue,
        yoy_growth_percentage,

        ROW_NUMBER() OVER (ORDER BY yoy_growth_percentage DESC) AS rn

    FROM latest_year

    WHERE latest_year_rank = 1
)

SELECT
    store_id,
    store_name,
    order_year,
    total_revenue,
    previous_year_revenue,
    yoy_growth_percentage

FROM store_rankings

WHERE rn <= 5

ORDER BY
    yoy_growth_percentage DESC;


/*A company wants to identify employees who have perfect attendance streaks of at least 5 consecutive working days.*/

WITH present_attendance AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        e.department,
        DATE_TRUNC('day', a.attendance_date) AS attendance_date

    FROM dim_employees e

    JOIN fact_attendance a
        ON e.employee_id = a.employee_id

    WHERE a.status = 'Present'

    GROUP BY
        e.employee_id,
        e.employee_name,
        e.department,
        DATE_TRUNC('day', a.attendance_date)
),

previous_attendance AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        attendance_date,

        LAG(attendance_date) OVER(PARTITION BY employee_id ORDER BY attendance_date) AS previous_attendance_date

    FROM present_attendance
),

gap_flag AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        attendance_date,
        previous_attendance_date,

        CASE
            WHEN previous_attendance_date IS NULL
                 OR attendance_date - previous_attendance_date > 1
            THEN 1
            ELSE 0
        END AS new_island_flag

    FROM previous_attendance
),

gap_islands AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        attendance_date,

        SUM(new_island_flag) OVER( PARTITION BY employee_id ORDER BY attendance_date) AS island_id

    FROM gap_flag
),

streak_length AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        island_id,

        MIN(attendance_date) AS streak_start_date,
        MAX(attendance_date) AS streak_end_date,
        COUNT(*) AS streak_length

    FROM gap_islands

    GROUP BY
        employee_id,
        employee_name,
        department,
        island_id
),

max_streak AS
(
    SELECT
        employee_id,
        employee_name,
        department,
        streak_start_date,
        streak_end_date,
        streak_length,

        ROW_NUMBER() OVER(PARTITION BY employee_id ORDER BY streak_length DESC, streak_end_date DESC) AS rn

    FROM streak_length
)

SELECT
    employee_id,
    employee_name,
    department,
    streak_start_date,
    streak_end_date,
    streak_length AS max_streak_length

FROM max_streak

WHERE rn = 1
  AND streak_length >= 5

ORDER BY
    streak_length DESC;


/*An e-commerce company wants to identify its top 10 customers by lifetime revenue within each customer segment.*/

WITH customer_revenue AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        c.segment,
        SUM(f.sales_amount) AS lifetime_revenue

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.customer_id,
        c.customer_name,
        c.segment
),

customer_rankings AS
(
    SELECT
        customer_id,
        customer_name,
        segment,
        lifetime_revenue,

        RANK() OVER( PARTITION BY segment ORDER BY lifetime_revenue DESC) AS segment_rank

    FROM customer_revenue
)

SELECT
    customer_id,
    customer_name,
    segment,
    lifetime_revenue,
    segment_rank

FROM customer_rankings

WHERE segment_rank <= 10

ORDER BY
    segment,
    segment_rank;

/*A subscription company wants to measure monthly customer retention.

A customer is considered retained in a month if they were also active in the previous month.*/

WITH monthly_activity AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', activity_date) AS activity_month

    FROM fact_activity
),

previous_activity AS
(
    SELECT
        customer_id,
        activity_month,

        LAG(activity_month) OVER( PARTITION BY customer_id ORDER BY activity_month) AS previous_activity_month

    FROM monthly_activity
),

retention_flags AS
(
    SELECT
        customer_id,
        activity_month,

        CASE
            WHEN previous_activity_month IS NOT NULL
                 AND activity_month =
                     previous_activity_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS retained_flag

    FROM previous_activity
),

monthly_metrics AS
(
    SELECT
        activity_month,

        COUNT(DISTINCT customer_id) AS active_customers,

        SUM(retained_flag) AS retained_customers

    FROM retention_flags

    GROUP BY activity_month
),

final_metrics AS
(
    SELECT
        activity_month,
        active_customers,
        retained_customers,

        LAG(active_customers) OVER ( ORDER BY activity_month ) AS previous_month_active_customers

    FROM monthly_metrics
)

SELECT
    activity_month,
    active_customers,
    retained_customers,

    ROUND(
        retained_customers * 100.0
        / NULLIF(previous_month_active_customers, 0),
        2
    ) AS retention_rate

FROM final_metrics

ORDER BY activity_month;
