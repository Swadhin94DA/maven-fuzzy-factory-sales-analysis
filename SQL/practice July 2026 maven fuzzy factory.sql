-- Create schemas
use Maven_fuzzy_ecom;
SELECT 
    *
FROM
    order_item_refunds;
SELECT 
    *
FROM
    products;
SELECT 
    *
FROM
    orders;
SELECT 
    *
FROM
    order_items;
DESCRIBE orders;
DESC order_items;
DESC products;
DESC order_item_refunds;
-- Total Revenue
SELECT 
    SUM(price_usd)
FROM
    order_items;
    
-- Total Profit    
SELECT 
    SUM(price_usd - cogs_usd)
FROM
    order_items;

-- Gross Margin %
SELECT 
    (SUM(price_usd - cogs_usd) / SUM(price_usd)) * 100
FROM
    order_items;
    
-- Monthly Revenue Trend
SELECT 
    DATE_FORMAT(created_at, '%Y-%m') AS month,
    ROUND(SUM(price_usd), 2) AS monthly_revenue
FROM
    order_items
GROUP BY DATE_FORMAT(created_at, '%Y-%m')
ORDER BY month;

-- Top Selling Products
SELECT 
    p.product_name, ROUND(SUM(oi.price_usd), 2) AS Total_Revenue
FROM
    order_items oi
        JOIN
    products p ON oi.product_id = p.product_id
GROUP BY p.product_name
ORDER BY Total_Revenue DESC;

-- Refund Rate by Product
SELECT 
    p.product_name,
    COUNT(oif.order_item_refund_id) as Refunded_Items_A,
    COUNT(oii.order_item_id) as Ordered_items_B,
    ROUND((COUNT(oif.order_item_refund_id) * 100 / COUNT(oii.order_item_id)),
            2) AS Refund_Rate_AX100byB
FROM
    order_items oii
        JOIN
    products p ON p.product_id = oii.product_id
        LEFT JOIN
    order_item_refunds oif ON oif.order_item_id = oii.order_item_id
GROUP BY p.product_name
ORDER BY Refunded_Items_A DESC;

-- Average Order Value (AOV) Total Revenue ÷ Total Number of Orders
SELECT 
    SUM(price_usd) AS Total_revenue,
    COUNT(order_id) AS Total_NO_of_Order,
    ROUND(( SUM(price_usd) / COUNT( DISTINCT order_id)), 2) AS Avg_Order_Value
FROM
    order_items;

-- Monthly Growth %
SELECT 
    DATE_FORMAT(created_at, '%y-%m') AS Month,
    Round(SUM(price_usd),2) AS Revenue
FROM
    order_items
GROUP BY DATE_FORMAT(created_at, '%y-%m');

WITH 
monthly_revenue AS
(
SELECT 
    DATE_FORMAT(created_at, '%y-%m') AS Month,
    Round(SUM(price_usd),2) AS Revenue
FROM
    order_items
GROUP BY DATE_FORMAT(created_at, '%y-%m')
)
select 
Month, Revenue, 
   round(
   (Revenue-LAG(Revenue) Over (order by Month))/(LAG(Revenue) Over (order by Month)) *100,2)
   as Percent_of_Growth from monthly_revenue
;

-- Running Revenue
with Monthly_revenue as 
(
select 
date_format(created_at, '%y-%m') as Month, 
Round (sum(price_usd),2)as Revenue 
from order_items 
group by date_format(created_at, '%y-%m')
)
Select 
Month, Revenue, 
Round(
(Revenue + Lag(Revenue) over (order by month))
,2)
as Cummulative_Running_revenue
from Monthly_revenue ;

-- Product Ranking
select 
p.product_name, 
round(sum(oi.price_usd),2) as Total_Revenue, 
dense_rank() 
over 
(order by sum(oi.price_usd) desc) as Product_rank
from 
order_items oi 
join products p 
on oi.product_id = p.product_id
group by 
p.product_name
order by 
Total_Revenue 
desc;   

-- Repeat Customer Analysis
SELECT 
    user_id, COUNT(order_id) AS Total_orders
FROM
    orders
GROUP BY user_id
HAVING COUNT(order_id) > 2
ORDER BY Total_orders DESC
;

-- Cohort Analysis
WITH customer_cohort AS
(
SELECT
    user_id,
    DATE_FORMAT(MIN(created_at),'%Y-%m') AS cohort_month
FROM orders
GROUP BY user_id
)

-- Executive KPI Report (single SQL query)
    WITH monthly_revenue AS (
    SELECT
        DATE_FORMAT(created_at, '%Y-%m') AS month,
        Round(SUM(price_usd),2) AS monthly_revenue
    FROM order_items
    GROUP BY DATE_FORMAT(created_at, '%Y-%m')
),
best_product AS (
    SELECT
        p.product_name,
        Round(SUM(oi.price_usd),2) AS revenue,
        Dense_RANK() OVER (ORDER BY SUM(oi.price_usd) DESC) AS rnk
    FROM order_items oi
    JOIN products p
        ON oi.product_id = p.product_id
    GROUP BY p.product_name
)
SELECT
    mr.month,
    mr.monthly_revenue,
    SUM(mr.monthly_revenue)
        OVER(ORDER BY mr.month) AS running_revenue,
    (SELECT ROUND(SUM(price_usd),2)
     FROM order_items) AS total_revenue,
    (SELECT COUNT(DISTINCT order_id)
     FROM orders) AS total_orders,
    (SELECT COUNT(order_item_id)
     FROM order_items) AS total_products_sold,
    (SELECT ROUND(
        SUM(price_usd)/COUNT(DISTINCT order_id),2)
     FROM order_items) AS average_order_value,
    (SELECT COUNT(*)
     FROM order_item_refunds) AS total_refunds,
    (SELECT ROUND(
        COUNT(*)*100.0/
        (SELECT COUNT(*) FROM order_items),2)
     FROM order_item_refunds) AS refund_rate_percent,
    (SELECT product_name
     FROM best_product
     WHERE rnk=1) AS best_selling_product
FROM monthly_revenue mr;
