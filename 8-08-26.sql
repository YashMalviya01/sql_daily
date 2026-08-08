/*Business requirement

An e-commerce company wants to identify customers who made a second purchase within 30 days of their first purchase.*/

WITH customer_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        SUM(sales_amount) AS order_amount
    FROM fact_sales
    GROUP BY
        customer_id,
        order_id,
        order_date
),

ranked_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        order_amount,

        ROW_NUMBER() OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS order_rank

    FROM customer_orders
),

first_second_purchase AS
(
    SELECT
        customer_id,

        MAX(
            CASE
                WHEN order_rank = 1
                THEN order_date
            END
        ) AS first_order_date,

        MAX(
            CASE
                WHEN order_rank = 1
                THEN order_amount
            END
        ) AS first_order_amount,

        MAX(
            CASE
                WHEN order_rank = 2
                THEN order_date
            END
        ) AS second_order_date,

        MAX(
            CASE
                WHEN order_rank = 2
                THEN order_amount
            END
        ) AS second_order_amount

    FROM ranked_orders

    GROUP BY customer_id
),

retention_flag AS
(
    SELECT
        *,

        CASE
            WHEN second_order_date <= first_order_date + INTERVAL '30 days'
            THEN 'Yes'
            ELSE 'No'
        END AS second_purchase_within_30_days

    FROM first_second_purchase
)

SELECT
    customer_id,
    first_order_date,
    first_order_amount,
    second_order_date,
    second_order_amount,
    second_purchase_within_30_days

FROM retention_flag

WHERE second_order_date IS NOT NULL;


/*Business requirement

An e-commerce company wants to identify customers who stopped purchasing for at least 60 days and then returned to make another purchase.

For every qualifying customer, show:

Customer ID
Date of the purchase before the inactive period
Date they returned
Number of inactive days*/

WITH customer_orders AS
(
    SELECT
        customer_id,
        order_id,
        order_date,

        LAG(order_date) OVER
        (
            PARTITION BY customer_id
            ORDER BY order_date, order_id
        ) AS previous_order_date

    FROM fact_sales
),

previous_purchase AS
(
    SELECT
        customer_id,
        order_id,
        order_date,
        previous_order_date,

        CASE
            WHEN previous_order_date IS NOT NULL
                 AND order_date - previous_order_date >= 60
            THEN 'Yes'
            ELSE 'No'
        END AS inactive_flag

    FROM customer_orders
),

inactive_customers AS
(
    SELECT
        customer_id,
        previous_order_date,
        order_date,
        order_date - previous_order_date AS inactive_days

    FROM previous_purchase

    WHERE inactive_flag = 'Yes'
)

SELECT
    customer_id,
    previous_order_date,
    order_date AS return_date,
    inactive_days

FROM inactive_customers

ORDER BY
    customer_id,
    return_date;
