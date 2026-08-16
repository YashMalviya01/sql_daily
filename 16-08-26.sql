/*Business Requirement

Management wants to identify high-value customers whose purchasing behavior is improving and who have demonstrated consistent engagement.

For every customer, calculate:

1. Lifetime metrics
Lifetime revenue
Total orders
Number of distinct products purchased
Number of distinct categories purchased
2. Monthly metrics

Create a customer-month grain and calculate:

Monthly revenue
Monthly order count
Previous month's revenue
MoM revenue growth %
3. Rolling performance

Calculate:

3-month rolling average revenue
Running lifetime revenue by month
4. Engagement

Identify the customer's:

Longest consecutive monthly purchasing streak

A month counts as active if the customer made at least one purchase.

5. Retention

Determine whether the customer's latest active month was retained.

A customer is retained if their latest active month immediately follows their previous active month.

6. Customer ranking

Rank customers within their region based on lifetime revenue.

7. Final selection

Return customers who satisfy all of these conditions:

Lifetime revenue > overall average customer revenue
AND
Longest monthly streak >= 3
AND
Latest month was retained

Then return the top 5 customers in each region based on lifetime revenue.*/

