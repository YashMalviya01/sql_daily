/*Business Scenario

The Growth team wants to answer:

"When customers join us, how many of them come back over time?"
 
This is called Cohort Analysis.
Business Requirement

Write a SQL query to:

Find each customer's first purchase month.
Assign customers to a cohort month.
Calculate the number of months since the first purchase.
Count active customers for each cohort and month number.
Calculate the retention percentage.*/


-- ==========================================================
-- Q1 : Customer Cohort Analysis
-- ==========================================================

-- Step 1 : Find Customer's First Purchase Month

WITH customer_cohort AS
(
    SELECT

        customer_id,

        DATE_TRUNC
        (
            'month',
            MIN(order_date)
        ) AS cohort_month

    FROM fact_sales

    GROUP BY
        customer_id
),

-- ==========================================================
-- Step 2 : Customer Monthly Activity
-- ==========================================================

customer_activity AS
(
    SELECT

        f.customer_id,

        DATE_TRUNC
        (
            'month',
            f.order_date
        ) AS order_month,

        cc.cohort_month,

        (
            EXTRACT(YEAR FROM AGE
            (
                DATE_TRUNC('month',f.order_date),
                cc.cohort_month
            )) * 12

            +

            EXTRACT(MONTH FROM AGE
            (
                DATE_TRUNC('month',f.order_date),
                cc.cohort_month
            ))
        ) AS month_number

    FROM fact_sales f

    JOIN customer_cohort cc
        ON f.customer_id = cc.customer_id

    GROUP BY
        f.customer_id,
        DATE_TRUNC('month',f.order_date),
        cc.cohort_month
),

-- ==========================================================
-- Step 3 : Active Customers
-- ==========================================================

cohort_activity AS
(
    SELECT

        cohort_month,

        month_number,

        COUNT(DISTINCT customer_id) AS active_customers

    FROM customer_activity

    GROUP BY
        cohort_month,
        month_number
),

-- ==========================================================
-- Step 4 : Cohort Size
-- ==========================================================

cohort_size AS
(
    SELECT

        cohort_month,

        COUNT(DISTINCT customer_id) AS cohort_size

    FROM customer_cohort

    GROUP BY
        cohort_month
),

-- ==========================================================
-- Step 5 : Retention %
-- ==========================================================

cohort_retention AS
(
    SELECT

        ca.cohort_month,

        ca.month_number,

        cs.cohort_size,

        ca.active_customers,

        ROUND
        (
            ca.active_customers
            *100.0
            /
            NULLIF(cs.cohort_size,0),
            2
        ) AS retention_percentage

    FROM cohort_activity ca

    JOIN cohort_size cs

        ON ca.cohort_month = cs.cohort_month
)

-- ==========================================================
-- Final Output
-- ==========================================================

SELECT

    cohort_month,

    month_number,

    cohort_size,

    active_customers,

    retention_percentage

FROM cohort_retention

ORDER BY
    cohort_month,
    month_number;
