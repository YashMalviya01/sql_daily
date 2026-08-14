
/*Question 1/10 — Customer Spending

An e-commerce company wants to identify customers who have spent more than ₹100,000 in total and determine what percentage of the company's total revenue comes from those customers.*/

WITH customer_revenue AS
(
    SELECT 
        c.customer_id,
        c.customer_name,
        c.segment,
        SUM(f.sales_amount) AS lifetime_revenue
    FROM fact_sales f  
    JOIN dim_customers c ON f.customer_id = c.customer_id  
    GROUP BY   c.customer_id,
               c.customer_name,
               c.segment
),

revenue_percentage AS 
(
    SELECT
        customer_id,
        customer_name,
        segment,
        lifetime_revenue,

        lifetime_revenue * 100 / sum(lifetime_revenue) OVER () AS percentage_of_total_revenue
    FROM customer_revenue    
)

SELECT
    customer_id,
    customer_name,
    segment,
    lifetime_revenue,
    percentage_of_total_revenue

FROM revenue_percentage

WHERE lifetime_revenue > 100000

ORDER BY
    lifetime_revenue DESC;

/*Question 2/10 — Monthly Revenue Growth

A retail company wants to identify products whose revenue increased for at least 3 consecutive months*/

WITH monthly_revenue AS
(
    SELECT
        p.product_id,
        p.product_name,
        p.category,
        DATE_TRUNC('month', f.order_date) AS sales_month,
        SUM(f.sales_amount) AS monthly_revenue

    FROM fact_sales f

    JOIN dim_products p
        ON f.product_id = p.product_id

    GROUP BY
        p.product_id,
        p.product_name,
        p.category,
        DATE_TRUNC('month', f.order_date)
),

month_over_month AS
(
    SELECT
        product_id,
        product_name,
        category,
        sales_month,
        monthly_revenue,

        LAG(monthly_revenue) OVER(PARTITION BY product_id ORDER BY sales_month) AS previous_month_revenue,

        LAG(sales_month) OVER( PARTITION BY product_id ORDER BY sales_month ) AS previous_sales_month

    FROM monthly_revenue
),

growth_flags AS
(
    SELECT
        *,
        
        CASE
            WHEN previous_month_revenue IS NOT NULL
                 AND previous_sales_month =
                     sales_month - INTERVAL '1 month'
                 AND monthly_revenue > previous_month_revenue
            THEN 1
            ELSE 0
        END AS is_increase

    FROM month_over_month
),

streak_groups AS
(
    SELECT
        *,
        
        SUM(
            CASE
                WHEN is_increase = 0 THEN 1
                ELSE 0
            END
        ) OVER
        (
            PARTITION BY product_id
            ORDER BY sales_month
        ) AS streak_group

    FROM growth_flags
),

product_streaks AS
(
    SELECT
        product_id,
        product_name,
        category,
        streak_group,

        MIN(sales_month) AS streak_start,
        MAX(sales_month) AS streak_end,

        COUNT(*) AS streak_len

    FROM streak_groups

    WHERE is_increase = 1

    GROUP BY
        product_id,
        product_name,
        category,
        streak_group
),

best_run_per_product AS
(
    SELECT
        product_id,
        product_name,
        category,
        streak_len AS longest_increasing_streak,
        streak_start,
        streak_end,

        ROW_NUMBER() OVER( PARTITION BY product_id ORDER BY streak_len DESC, streak_end DESC) AS rn

    FROM product_streaks
)

SELECT
    product_id,
    product_name,
    category,
    longest_increasing_streak,
    streak_end AS streak_end_month

FROM best_run_per_product

WHERE rn = 1
  AND longest_increasing_streak >= 3

ORDER BY
    longest_increasing_streak DESC,
    product_id;

/*Q3 — Top Customer per Region per Year*/  

WITH customer_yearly_revenue AS
(
    SELECT
        c.region,
        EXTRACT(YEAR FROM f.order_date) AS sales_year,
        c.customer_id,
        c.customer_name,
        c.segment,
        SUM(f.sales_amount) AS annual_revenue

    FROM fact_sales f

    JOIN dim_customers c
        ON f.customer_id = c.customer_id

    GROUP BY
        c.region,
        EXTRACT(YEAR FROM f.order_date),
        c.customer_id,
        c.customer_name,
        c.segment
),

ranked_customers AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY region, sales_year
            ORDER BY annual_revenue DESC
        ) AS rn

    FROM customer_yearly_revenue
)

SELECT
    region,
    sales_year,
    customer_id,
    customer_name,
    segment,
    annual_revenue

FROM ranked_customers

WHERE rn = 1

ORDER BY
    sales_year,
    region;

 /*Q4 — Customer Reactivation

Find customers who made a purchase, then became inactive for at least 3 months, and subsequently returned.*/

WITH customer_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date) AS purchase_month

    FROM fact_sales
),

previous_purchase AS
(
    SELECT
        customer_id,
        purchase_month,

        LAG(purchase_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY purchase_month
        ) AS previous_purchase_month

    FROM customer_months
),

reactivation AS
(
    SELECT
        customer_id,
        previous_purchase_month,
        purchase_month AS return_month,

        (
            EXTRACT(
                YEAR FROM AGE(
                    purchase_month,
                    previous_purchase_month
                )
            ) * 12
            +
            EXTRACT(
                MONTH FROM AGE(
                    purchase_month,
                    previous_purchase_month
                )
            ) - 1
        ) AS inactive_months

    FROM previous_purchase

    WHERE previous_purchase_month IS NOT NULL
)

SELECT
    customer_id,
    previous_purchase_month,
    return_month,
    inactive_months

FROM reactivation

WHERE inactive_months >= 3

ORDER BY
    customer_id,
    return_month;


/*Q5 — Monthly Customer Retention

A customer is considered retained if they purchased in the current month and the immediately preceding month.*/ 

WITH customer_months AS
(
    SELECT DISTINCT
        customer_id,
        DATE_TRUNC('month', order_date) AS purchase_month

    FROM fact_sales
),

previous_month AS
(
    SELECT
        customer_id,
        purchase_month,

        LAG(purchase_month) OVER
        (
            PARTITION BY customer_id
            ORDER BY purchase_month
        ) AS previous_purchase_month

    FROM customer_months
),

retention_flags AS
(
    SELECT
        customer_id,
        purchase_month,

        CASE
            WHEN previous_purchase_month IS NOT NULL
                 AND purchase_month =
                     previous_purchase_month + INTERVAL '1 month'
            THEN 1
            ELSE 0
        END AS retained_flag

    FROM previous_month
),

monthly_metrics AS
(
    SELECT
        purchase_month,

        COUNT(DISTINCT customer_id) AS active_customers,

        SUM(retained_flag) AS retained_customers

    FROM retention_flags

    GROUP BY
        purchase_month
),

final_metrics AS
(
    SELECT
        purchase_month,
        active_customers,
        retained_customers,

        LAG(active_customers) OVER
        (
            ORDER BY purchase_month
        ) AS previous_month_customers

    FROM monthly_metrics
)

SELECT
    purchase_month,
    active_customers,
    retained_customers,

    ROUND(
        retained_customers * 100.0
        / NULLIF(previous_month_customers, 0),
        2
    ) AS retention_rate

FROM final_metrics

ORDER BY purchase_month;
