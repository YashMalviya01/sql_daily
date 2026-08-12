/*A company wants to identify employees whose salary is above the average salary of their own department.
Requirement

Return:

Employee ID
Employee name
Department name
Salary
Department average salary
Difference between employee salary and department average*/

WITH employee_salary AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        d.department_nmae,
        d.department_id,
        e.salary,
        AVG(e.salary)OVER(PARTITION BY d.department_id) AS department_avg_salary
    FROM dim_employees e
    JOIN dom_department d ON e.department_id = d.department_id    
)

SELECT 
    employee_id,
    employee_name,
    department_name,
    salary,
    department_avg_salary,
    salary - department_avg_salary AS salary_diffrence

    FROM employee_salary
    WHERE salary > department_avg_salary
    ORDER BY department_name,
    salary_diffrence DESC;


/*A retail company wants to identify the highest-revenue product in each product category.
Return:

category
product_id
product_name
total_revenue

Only return the highest-revenue product in each category.*/

WITH product_revenue AS
(
    SELECT
        p.category,
        p.product_id,
        p.product_name,
        SUM(f.sales_amount) AS total_revenue
    FROM fact_sales  
    JOIN dim_products p ON f.product_id = p.product_id
    GROUP BY p.category,
             p.product_id,
             p.product_name   
),

ranked_products AS
(
    SELECT
        category,
        product_id,
        product_name,
        total_revenue,
        RANK() OVER (PARTITION BY category ORDER BY total_revenue DESC) AS rank
    FROM product_revenue
)

SELECT
    category,
    product_id,
    product_name,
    total_revenue
FROM ranked_products
WHERE rank = 1      
ORDER BY category,
         total_revenue DESC;


/*An e-commerce company wants to identify customers whose monthly order count is above the average monthly order count of all customers.*/

WITH customer_monthly_rders AS
(
    SELECT
        customer_id,
        DATE_TRUNC('month', order_date ) AS order_month,
        COUNT (DISTINCT order_id) AS monthly_order_count
    FROM fact_sales
    GROUP BY customer_id,
             DATE_TRUNC('month', order_date)    
),

customer_average AS 

(
    SELECT  
        customer_id,
        AVG(monthly_order_count) AS avg_monthly_orders
    FROM customer_monthly_orders
    GROUP BY customer_id
),

overall_avg AS 
(
    SELECT  
        AVG(avg_monthly_orders) AS overall_avg_onthly_orders
    FROM customer_average    
)

SELECT
    c.customer_id,
    c.avg_monthly_orders,
    o.overall_avg_monthly_orders,

    c.avg_monthly_orders
        - o.overall_avg_monthly_orders
        AS difference_from_average

FROM customer_average c

CROSS JOIN overall_average o

WHERE c.avg_monthly_orders > o.overall_avg_monthly_orders

ORDER BY
    difference_from_average DESC;

/*A company wants to identify salespeople whose quarterly revenue is above the average quarterly revenue of their region.*/

WITH quarterly_sales AS
(
    SELECT
        s.salesperson_id,
        s.salesperson_name,
        s.region,
        DATE_TRUNC('quarter', f.order_date) AS sales_quarter,
        SUM(f.sales_amount) AS quarterly_revenue

    FROM fact_sales f

    JOIN dim_salespersons s
        ON f.salesperson_id = s.salesperson_id

    GROUP BY
        s.salesperson_id,
        s.salesperson_name,
        s.region,
        DATE_TRUNC('quarter', f.order_date)
),

regional_average AS
(
    SELECT
        salesperson_id,
        salesperson_name,
        region,
        sales_quarter,
        quarterly_revenue,

        AVG(quarterly_revenue) OVER (PARTITION BY region, sales_quarter) AS regional_avg_revenue

    FROM quarterly_sales
)

SELECT
    salesperson_id,
    salesperson_name,
    region,
    sales_quarter,
    quarterly_revenue,
    regional_avg_revenue,

    quarterly_revenue - regional_avg_revenue AS difference_from_regional_average

FROM regional_average

WHERE quarterly_revenue > regional_avg_revenue

ORDER BY
    sales_quarter,
    region,
    difference_from_regional_average DESC;

/*Customer Churn & Reactivation

A subscription company wants to identify customers who:

Were active for at least 3 consecutive months.
Then became inactive for at least 2 full months.
Then returned.

For every qualifying customer, return:

customer_id
End month of their previous active streak
Return month
Number of inactive months
Length of their previous active streak*/

WITH active_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', activity_date) AS activity_month

    FROM fact_activity
),

previous_month AS
(
    SELECT
        customer_id,
        activity_month,

        LAG(activity_month) OVER ( PARTITION BY customer_id ORDER BY activity_month) AS previous_activity_month

    FROM active_months
),

gap_flags AS
(
    SELECT
        customer_id,
        activity_month,

        CASE
            WHEN previous_activity_month IS NULL
                 OR activity_month <>
                    previous_activity_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS new_island_flag

    FROM previous_month
),

activity_islands AS
(
    SELECT
        customer_id,
        activity_month,

        SUM(new_island_flag) OVER ( PARTITION BY customer_id ORDER BY activity_month) AS island_id

    FROM gap_flags
),

streaks AS
(
    SELECT
        customer_id,
        island_id,

        MIN(activity_month) AS streak_start_month,
        MAX(activity_month) AS streak_end_month,
        COUNT(*) AS streak_length

    FROM activity_islands

    GROUP BY
        customer_id,
        island_id
),

next_streak AS
(
    SELECT
        customer_id,
        island_id,
        streak_start_month,
        streak_end_month,
        streak_length,

        LEAD(streak_start_month) OVER(PARTITION BY customer_id ORDER BY island_id) AS return_month

    FROM streaks
),

reactivation AS
(
    SELECT
        customer_id,
        streak_end_month,
        return_month,
        streak_length,

        (
            EXTRACT(
                YEAR FROM AGE(return_month, streak_end_month)
            ) * 12
            +
            EXTRACT(
                MONTH FROM AGE(return_month, streak_end_month)
            )
            - 1
        ) AS inactive_months

    FROM next_streak

    WHERE streak_length >= 3
      AND return_month IS NOT NULL
),

qualified_customers AS
(
    SELECT
        customer_id,
        streak_end_month,
        return_month,
        inactive_months,
        streak_length,

        ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY return_month DESC) AS rn

    FROM reactivation

    WHERE inactive_months >= 2
)

SELECT
    customer_id,
    streak_end_month,
    return_month,
    inactive_months,
    streak_length AS previous_active_streak

FROM qualified_customers

WHERE rn = 1

ORDER BY
    return_month DESC;


/*Customer Revenue + Retention

An e-commerce company wants to identify its most valuable retained customers.

A customer is considered retained in a month if they made at least one purchase in the previous month as well.

The company wants to find customers who:

Have made purchases in at least 3 consecutive months.
Have a total lifetime revenue above the average lifetime revenue of all customers.
Were retained during their most recent active month.*/

WITH customer_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date) AS activity_month

    FROM fact_sales
),

customer_revenue AS
(
    SELECT
        customer_id,
        SUM(sales_amount) AS lifetime_revenue

    FROM fact_sales

    GROUP BY customer_id
),

revenue_average AS
(
    SELECT
        AVG(lifetime_revenue) AS avg_customer_revenue

    FROM customer_revenue
),

previous_month AS
(
    SELECT
        customer_id,
        activity_month,

        LAG(activity_month) OVER (PARTITION BY customer_id ORDER BY activity_month) AS previous_activity_month

    FROM customer_months
),

streak_flags AS
(
    SELECT
        customer_id,
        activity_month,

        CASE
            WHEN previous_activity_month IS NULL
                 OR activity_month <>
                    previous_activity_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS new_island_flag

    FROM previous_month
),

activity_islands AS
(
    SELECT
        customer_id,
        activity_month,

        SUM(new_island_flag) OVER( PARTITION BY customer_id ORDER BY activity_month) AS island_id

    FROM streak_flags
),

streak_lengths AS
(
    SELECT
        customer_id,
        island_id,
        COUNT(*) AS streak_length

    FROM activity_islands

    GROUP BY
        customer_id,
        island_id
),

longest_streak AS
(
    SELECT
        customer_id,
        MAX(streak_length) AS longest_monthly_streak

    FROM streak_lengths

    GROUP BY customer_id
),

retention_status AS
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

    FROM previous_month
),

latest_activity AS
(
    SELECT
        customer_id,
        activity_month AS most_recent_active_month,
        retained_flag,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY activity_month DESC
        ) AS rn

    FROM retention_status
),

customer_profile AS
(
    SELECT
        c.customer_id,
        c.customer_name,
        r.lifetime_revenue,
        s.longest_monthly_streak,
        l.most_recent_active_month,
        l.retained_flag

    FROM dim_customers c

    JOIN customer_revenue r
        ON c.customer_id = r.customer_id

    JOIN longest_streak s
        ON c.customer_id = s.customer_id

    JOIN latest_activity l
        ON c.customer_id = l.customer_id

    WHERE l.rn = 1
),

final AS
(
    SELECT
        p.*,
        a.avg_customer_revenue

    FROM customer_profile p

    CROSS JOIN revenue_average a
)

SELECT
    customer_id,
    customer_name,
    lifetime_revenue,
    longest_monthly_streak,
    most_recent_active_month,
    retained_flag

FROM final

WHERE longest_monthly_streak >= 3
  AND lifetime_revenue > avg_customer_revenue
  AND retained_flag = 1

ORDER BY
    lifetime_revenue DESC;

    
