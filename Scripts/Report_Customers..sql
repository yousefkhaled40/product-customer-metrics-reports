/*
Customer Report

Purpose: This report consolidates key customer metrics and behaviors

1- Gather essential fields such as names, ages, and transaction details.
2- Segment customers into categories (VIP, Regular, New) and age groups.
3- Aggregate customer-level metrics:
   - total orders
   - total sales
   - total quantity purchased
   - total products
   - lifespan (in months)
4- Calculates valuable KPIs:
   - recency (months since last order)
   - average order value
   - average monthly spend
*/

create view gold.report_customers as

-- Retrieving core columns from tables
with base_query as(
select 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ',c.last_name) as customer_name,
DATEDIFF(YEAR, c.birthdate, getdate()) as customer_age
from gold.fact_sales f
left join gold.dim_customers c
on c.customer_key = f.customer_key
where order_date is not null)

--Aggregate at customer-level
, customer_aggregation as 
(
select 
customer_key,
customer_name,
customer_number,
customer_age,
count(distinct order_number) as total_orders,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity,
count(distinct product_key) as total_products,
max(order_date) as last_order_date,
datediff(month, min(order_date), max(order_date)) as lifespan
from base_query
group by
customer_key,
customer_name,
customer_number,
customer_age)


--Segment customers into categories (VIP, Regular, New) and age groups.
select
customer_key,
customer_number,
customer_name,
customer_age,
case
when customer_age < 20 then 'under 20'
when customer_age between 20 and 29 then '20-29'
when customer_age between 30 and 39 then '30-39'
when customer_age between 40 and 49 then '40-49'
else '50 and above' end as age_group,
case
when lifespan >= 12 and total_sales > 5000 then 'VIP'
when lifespan >= 12 and total_sales <= 5000 then 'Regular'
else 'new' end as customer_segment,
last_order_date,
datediff(month, last_order_date, getdate()) as recency,
total_orders,
total_sales,
total_quantity,
total_products,
lifespan,
case
when total_orders = 0 then 0
else total_sales/total_orders end as avg_order_value,  --compute average order value
case
when lifespan = 0 then total_sales
else total_sales/lifespan end as avg_monthly_spend     --comute average monthly spend
from customer_aggregation