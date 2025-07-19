-- change over time
select
datetrunc(month, order_date),
sum(sales_amount) as tota_sales,
count(distinct customer_key) as total_customers,
sum(quantity) as total_quantity
from gold.fact_sales
where order_date is not null
group by datetrunc(month, order_date)
order by datetrunc(month, order_date);



-- calculate the total sales per month
-- calculate the running total of sales over time
select
order_date,
total_sales,
sum(total_sales) over (order by order_date) as running_total_sales,
avg_price,
avg(avg_price) over (order by order_date) as moving_average_price
from( 
select
datetrunc(month, order_date) as order_date,
sum(sales_amount) as total_sales,
avg(price) as avg_price
from gold.fact_sales
where order_date is not null
group by datetrunc(month, order_date)) t;



-- analye the yearly performance of the products by comparing their sales
-- to both the average sales performance of the product and the previous year's sales
with yearly_product_sales as (
select
year(f.order_date) as order_year,
p.product_name,
sum(f.sales_amount) as current_sales
from gold.fact_sales f
left join gold.dim_products p
on f.product_key = p.product_key
where f.order_date is not null
group by year(f.order_date), p.product_name)

select
order_year,
product_name,
current_sales,
avg(current_sales) over (partition by product_name) as avg_sales,
current_sales - avg(current_sales) over (partition by product_name) as diff_avg_sales,
case 
when current_sales - avg(current_sales) over (partition by product_name) < 0 then 'below avg'
when current_sales - avg(current_sales) over (partition by product_name) > 0 then 'above avg'
else 'avg' end as avg_change,
lag(current_sales) over(partition by product_name order by order_year) as previous_year_sales,
current_sales - lag(current_sales) over(partition by product_name order by order_year) as diff_previous_year,
case
when current_sales - lag(current_sales) over(partition by product_name order by order_year) > 0 then 'incresing'
when current_sales - lag(current_sales) over(partition by product_name order by order_year) < 0 then 'decreasing'
else 'no change' end as previous_year_change
from yearly_product_sales
order by product_name, order_year;



-- which categories contribute the most to overall sales
with category_sales as (
select 
category,
sum(sales_amount) as total_sales
from gold.fact_sales f
left join gold.dim_products p
on f.product_key = p.product_key
group by category)

select
category,
total_sales,
sum(total_sales) over() as overall_sales,
concat(round((cast(total_sales as float) / sum(total_sales) over()) * 100, 2), '%') as percentage_of_total
from category_sales
order by percentage_of_total desc;



-- segment products into cost ranges and
-- count how many products fall into each segment
with product_segments as(
select 
product_key,
product_name,
cost,
case 
when cost < 100 then 'below 100'
when cost between 100 and 500 then '100-500'
when cost between 500 and 1000 then '500-1000'
else 'above 1000' end cost_range
from gold.dim_products)

select
cost_range,
count(product_key) as total_products
from product_segments
group by cost_range
order by total_products desc



/* Group customers into three segments based on their spending behaviour:
      - VIP: customers with at least 12 months of history and spending more than 5000
	  - Regular: Customers with at least 12 months of histroy but spending 5000 or less
	  - New: customers with a lifespan less than 12 months.
	  and the total number of customers per each group */
with customer_spending as(
select 
c.customer_key,
sum(f.sales_amount) as total_spending,
min(order_date) as first_order,
max(order_date) as last_order,
DATEDIFF(month, min(order_date), max(order_date)) as lifespan
from gold.fact_sales f
left join gold.dim_customers c
on f.customer_key = c.customer_key
group by c.customer_key)

select
customer_segment,
count(customer_key) as total_customer
from(
select
customer_key,
case
when lifespan >= 12 and total_spending > 5000 then 'VIP'
when lifespan >= 12 and total_spending <= 5000 then 'Regular'
else 'new' end as customer_segment
from customer_spending) t
group by customer_segment
order by total_customer desc
