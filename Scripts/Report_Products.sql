/*
Product Report

Purpose: This report consolidates key product metrics and behaviors

1- Gather essential fields such as product name, category, subcategory and cost.
2- Segment products by revenue to identify high-performers, mid-range, or low-performers.
3- Aggregate product-level metrics:
   - total orders
   - total sales
   - total quantity sold
   - total customers
   - lifespan (in months)
4- Calculates valuable KPIs:
   - recency (months since last sale)
   - average order revenue
   - average monthly revenue
*/

create view gold.report_products as
-- Retrieving core columns from tables
with base_query as(
select 
f.order_number,
f.order_date,
f.customer_key,
f.sales_amount,
f.quantity,
p.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost
from gold.fact_sales f
left join gold.dim_products p 
on p.product_key = f.product_key
where order_date is not null)

--Aggregate at porduct-level
, product_aggregation as 
(
select 
product_key,
product_name,
category,
subcategory,
cost,
datediff(month, min(order_date), max(order_date)) as lifespan,
max(order_date) as last_sale_date,
count(distinct order_number) as total_orders,
count(distinct customer_key) as tota_customers,
sum(sales_amount) as total_sales,
sum(quantity) as total_quantity,
round(avg(cast(sales_amount as float) / nullif(quantity, 0)), 1) as avg_selling_price
from base_query
group by
product_key,
product_name,
category,
subcategory,
cost
)

select
product_key,
product_name,
category,
subcategory,
cost,
last_sale_date,
datediff(month, last_sale_date, getdate()) as recency_in_months,
case
when total_sales > 50000 then 'High-Performer'
when total_sales  >= 10000 then 'Mid-Range'
else 'Low-Performer' end as 'product_segment',
lifespan,
total_orders,
total_sales,
total_quantity,
tota_customers,
avg_selling_price,
case
when total_orders = 0 then 0
else total_sales/total_orders end as 'avg_order_revenue',  --average order revenue
case
when lifespan = 0 then total_sales
else total_sales/lifespan end as 'avg_monthly_revenue'  -- average monthly revenue
from product_aggregation


--Segment customers into categories (VIP, Regular, New) and age groups.