use project_1;
 
select * from transaction_new;
select * from prod_cat_info;
select * from customers_new;

# 1. What is the total number of rows in each of the 3 tables in the database?

select count(*) as total_records_cust from customers_new;

select count(*) as total_records_trans from transaction_new;

select count(*) as total_records_prod from prod_cat_info;

# 2. what is the total number of transactions that have return?


select count(*) as total_returns from transaction_new
where Qty < 0;

/* 3. As you would have noticed , the dates provided across the datasets are not
  in a correct format as first step,please convert the data variables into valid 
  date formats before proceeding ahead. */



update customers_new 
set DOB= str_to_date(DOB,'%d-%m-%Y') 
 where DOB is not null;
 
 alter table customers_new
change column DOB DOB date not null;


alter table transaction_new
rename column ï»¿transaction_id to transaction_id;

update transaction_new 
set tran_date= str_to_date(tran_date,'%d-%m-%Y') 
 where tran_date is not null;

alter table transaction_new
change column tran_date trans_date date not null;

/* 4.what is the time range if transaction data available for analysis?
  show the output in number of days,months,years simultaneously in 
  different columns.*/
  
  
  select
    MIN(trans_date) AS start_date,
    MAX(trans_date) AS end_date,
    DATEDIFF(MAX(trans_date), MIN(trans_date)) AS range_tran_days,
    TIMESTAMPDIFF(MONTH, MIN(trans_date), MAX(trans_date)) AS range_tran_months,
    TIMESTAMPDIFF(YEAR, MIN(trans_date), MAX(trans_date)) AS range_tran_years
from transaction_new;

  
  /*5.which product category does the sub-category "DIY" belongs to? */
  
  select prod_cat,prod_subcat from prod_cat_info
  where  prod_subcat="DIY";
  
  
   /** DATA ANALYSIS **/
   
   
   /* 1. Which channel is most frequently used for transaction? */
   
   select store_type,count(transaction_id) as most_freq_used_channel from transaction_new
   group by store_type
   order by most_freq_used_channel desc limit 1;
   
   /* 2. What is the count of male and female customers in database? */
 
	   select Gender,count(customer_id) as count_of_gender from customers_new
       where Gender in ('M','F')
	   group by Gender;
   
       set sql_safe_updates = 0;
   
   
   # 3.From which city do we have maximum number of customers and how many?
   
    select city_code as CityCode_with_Max_Customers, No_of_customers from
    (select city_code  ,count(customer_id) as No_of_customers from customers_new
    group by city_code
	order by No_of_customers desc limit 1) as abc;
   
   
 # 4. How many sub-categories are there under the Books category?
    
   select prod_cat,count(prod_subcat) as count_of_subcat from prod_cat_info
   where prod_cat = 'Books';
 
  # 5.What is the maximum quantity of products ever ordered?
  
    
    select max(Qty) as max_Qty_ordered from transaction_new; 
    
    
 # 6.What is the net total revenue generated in categories Electronics and Books? 
 
 select prod_cat,net_total_revenue from (select prod_cat,round(sum(T.total_amt),2) as net_total_revenue from transaction_new T
 join prod_cat_info P 
 on P.prod_cat_code = T.prod_cat_code and T.prod_subcat_code = P.prod_sub_cat_code
 group by P.prod_cat)  as res
 where prod_cat in ('Electronics' , 'Books');

# 7. How many customers have > 10 transactions with us,excluding returns?

 select count(*) as No_of_customers_with_trans_more_10 from
 (
 select cust_id,count(transaction_id) as Total_transactions from transaction_new
 where Qty > 0
 group by cust_id 
 ) as res 
 where Total_transactions > 10;
 
 /* 8.What is the combined revenue earned from the "Electronics" and "Clothing"
      categories, from "Flagship stores"?  */

 
 select Store_type, round(sum(total_amt),2) as combined_revenue from 
 (select P.prod_cat, T.Store_type,T.total_amt  from transaction_new T
  join prod_cat_info P 
  on P.prod_cat_code = T.prod_cat_code and T.prod_subcat_code = P.prod_sub_cat_code
  where T.Store_type = 'Flagship store' and P.prod_cat in ('Electronics','Clothing') and T.total_amt > 0) as res ;
 


/* 9. What is the total revenue generated  from "MALE" customers in "Electronics" category?
   output should display total revenue by prod_subcat. */
   
   select C.Gender,P.prod_cat,P.prod_subcat,sum(T.total_amt) as total_revenue from transaction_new T
   join prod_cat_info P on P.prod_cat_code = T.prod_cat_code and T.prod_subcat_code = P.prod_sub_cat_code 
   join customers_new C on C.customer_id = T.cust_id
   where C.Gender = "M" and P.prod_cat = "Electronics" and total_amt > 0
   group by P.prod_subcat;
   
/* 10. What is the percentage of sales and returns by product sub category ; 
       Display only top 5 sub categories in terms of sales. */  

 with sales_total_cte as 
 (
 select P.prod_subcat ,sum(T.Qty) as total_sales from transaction_new T
 inner join prod_cat_info P on P.prod_cat_code = T.prod_cat_code and P.prod_sub_cat_code = T.prod_subcat_code
 where T.Qty >  0 
 group by P.prod_subcat order by total_sales desc
 )
 select res_subquery.prod_subcat,
 round(((total_sales)/(total_sales+total_returns) * 100),2)  as sales_percentage,
 round(((total_returns)/(total_sales+total_returns) * 100),2) as returns_percentage 
 from
 (
 select S.prod_subcat, S.total_sales,abs(sum(T.Qty)) as total_returns from sales_total_cte S
 inner join prod_cat_info P on S.prod_subcat = P.prod_subcat
 inner join transaction_new T on P.prod_cat_code = T.prod_cat_code and P.prod_sub_cat_code = T.prod_subcat_code
 where T.Qty < 0 
 group by S.prod_subcat,S.total_sales 
 order by total_returns desc
 ) as res_subquery
 group by res_subquery.prod_subcat
 order by sales_percentage desc limit 5;
 
 # 11.For all customers aged between 25 to 35 years find what is the net total revenue generated by 
# these consumers in last 30 days of transactions from max transaction date available in the data?

with max_tran_date as 
  (select max(trans_date) as max_date from transaction_new),
last_30days_trans as (
    select T.cust_id, T.trans_date, T.total_amt, M.max_date
    from transaction_new T join max_tran_date M
    where T.trans_date between DATE_SUB(M.max_date, interval 30 day) and M.max_date
),
age_25_30 as (
    select C.customer_id, year(M.max_date) - year(C.DOB) as age
    from customers_new C
    cross join max_tran_date M
    where year(M.max_date) - year(C.DOB) between 25 and 35
),
net_rev as (
    select sum(T.total_amt) AS net_total_revenue
    from last_30days_trans T
    join age_25_30 A ON T.cust_id = A.customer_id
)
select net_total_revenue from net_rev;
 
# 12.Which product category has seen the max value of returns in the last 3 months of transactions?

with max_tran_date as 
	(select max(trans_date) as max_date from transaction_new),
	last_90days_returns as (
    select P.prod_cat, sum(case when T.total_amt < 0 then T.total_amt else 0 end) as return_amount 
    from transaction_new T
    join max_tran_date M on T.trans_date between DATE_SUB(M.max_date, interval 90 day) and M.max_date
    left join prod_cat_info P on T.prod_subcat_code = P.prod_sub_cat_code and T.prod_cat_code = P.prod_cat_code 
    group by P.prod_cat
)
select prod_cat, return_amount from last_90days_returns
order by return_amount
limit 1;
 

# 13.Which store-type sells the maximum products; by value of sales amount and by quantity sold?


 
select Store_type, round(sum(total_amt),2) as total_sales, count(Qty) as total_qty_sold from transaction_new 
where total_amt > 0 
group by Store_type 
order by total_sales desc, total_qty_sold desc
limit 1;




# 14.What are the categories for which average revenue is above the overall average?

with overall_avg_rev as
( 
select round(avg(total_amt),2) as overall_avg from transaction_new where total_amt > 0
)
select P.prod_cat,round(avg(T.total_amt),2) as avg_rev_categorical from transaction_new T
join prod_cat_info P on  T.prod_cat_code = P.prod_cat_code and T.prod_subcat_code = P.prod_sub_cat_code
where T.total_amt > 0
group by P.prod_cat
having avg_rev_categorical > (select overall_avg from overall_avg_rev);

# 15. Find the average and total revenue by each subcategory for the categories
# which are among top 5 categories in terms of quantity sold.

with top_5_cat as 
(
   select P.prod_cat,sum(T.Qty) as total_qty from transaction_new T 
   join prod_cat_info P on T.prod_cat_code = P.prod_cat_code and T.prod_subcat_code = P.prod_sub_cat_code
   where T.Qty > 0
   group by P.prod_cat
   order by total_qty desc limit 5 
)
select C.prod_cat ,P.prod_subcat,round(avg(T.total_amt),2) as Avg_rev, round(sum(T.total_amt),2) as Sum_rev from top_5_cat C 
left join prod_cat_info P on P.prod_cat = C.prod_cat
left join transaction_new T on  T.prod_cat_code = P.prod_cat_code and T.prod_subcat_code = P.prod_sub_cat_code
group by P.prod_subcat,C.prod_cat;


   
   
   
  