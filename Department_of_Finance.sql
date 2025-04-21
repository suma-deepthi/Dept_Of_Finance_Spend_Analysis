#total_spend_per_month
select Month, total_spent from
(SELECT 1 as month_order, 'September_2024' as Month, sum(Invoice_amount) as total_spent  FROM finance_data.departmental_spend_sep_2024
union all
SELECT 2 as month_order, 'October_2024' as Month, sum(Invoice_amount) as total_spent  FROM finance_data.departmental_spend_oct_2024
union all
SELECT 3 as month_order, 'November_2024' as Month, sum(Invoice_amount) as total_spent  FROM finance_data.departmental_spend_nov_2024
union all
SELECT 4 as month_order, 'December_2024' as Month, sum(Invoice_amount) as total_spent  FROM finance_data.departmental_spend_dec_2024
union all
SELECT 5 as month_order, 'January_2025' as Month, sum(Invoice_amount) as total_spent  FROM finance_data.departmental_spend_jan_2025
) as monthly_spend 
order by month_order;
SELECT @@hostname AS server_name;

# adding new column report_month in all tables to bring dynamically month-year(eg:january-2025)
alter table finance_data.departmental_spend_jan_2025
add column report_month varchar(20);
update finance_data.departmental_spend_jan_2025
set report_month = date_format(check_Date, '%M-%Y');

drop table total_spend_per_monthly;
# Merge all, Monthly Data into One Table
create table total_spend_per_monthly
(
department varchar(255),
organisation varchar(255),
check_date date,
expense_type varchar(255),
supplier varchar(255), 
invoice_number varchar(255), 
invoice_amount decimal(15,2),
postcode varchar(10),
report_month varchar(20)
);

#combine all tables in to one table
insert into total_spend_per_monthly
(department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month)
select department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month from departmental_spend_sep_2024;
insert into total_spend_per_monthly
(department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month)
select department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month from departmental_spend_oct_2024;
insert into total_spend_per_monthly
(department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month)
select department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month from departmental_spend_nov_2024;
insert into total_spend_per_monthly
(department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month)
select department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month from departmental_spend_dec_2024;
insert into total_spend_per_monthly
(department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month)
select department, organisation, check_date, expense_type, supplier, invoice_number,
invoice_amount, postcode, report_month from departmental_spend_jan_2025;

#Create view for reusable and auto update 
#calculate total_spend per monthly
select date_format(check_date, '%b-%Y') as Month_Year, sum(invoice_amount) as total_spend from 
total_spend_per_monthly group by Month_Year;

#Create view for reusable and auto update 
#calculate over all total_spend
select  sum(invoice_amount) as total_spend from 
total_spend_per_monthly;

#calculate total spend by each organisation
select organisation, sum(invoice_amount) as total_spend from 
all_spend group by  organisation order by total_spend desc;

#calculate total spend by expense type
select expense_type, sum(invoice_amount) as total_spend from 
total_spend_per_monthly group by  expense_type order by total_spend desc;

#Create view for reusable and auto update 
#Top 10 Suppliers by Spend using rank
select supplier, sum(invoice_amount) as total_spend,
rank() over(order by sum(invoice_amount) desc) as rank_position
from total_spend_per_monthly group by supplier limit 10;

# create Stored Procedure: Log Monthly Spend into Summary Table
#(Run this once after creating table: finance_data.monthly_spend_summary)
drop table monthly_spend_summary;
create table monthly_spend_summary
(
Month_Year varchar(20), total_spend dec(15,2));

CALL log_monthly_spend('Sep-2024');
CALL log_monthly_spend('Oct-2024');
CALL log_monthly_spend('Nov-2024');
CALL log_monthly_spend('Dec-2024');
CALL log_monthly_spend('Jan-2025');

select DATE_FORMAT(check_date, '%b-%Y') as Month_Year, sum(invoice_amount) as total_spend
from total_spend_per_monthly
group by DATE_FORMAT(check_date, '%b-%Y');


#calculate organisation wise monthly spend
select organisation, date_format(check_date, '%b-%Y') as Month_Year, sum(invoice_amount) as total_spend
from total_spend_per_monthly group by organisation, Month_Year order by Month_Year;

#calculate supplier wise monthly spend
select supplier, date_format(check_date, '%b-%Y') as Month_Year, sum(invoice_amount) as total_spend
from total_spend_per_monthly group by supplier, Month_Year order by Month_Year;

# High-Value Transactions Over £1M
select * from total_spend_per_monthly
where invoice_amount > 1000000
order by invoice_amount desc;

# By Supplier #Average, Min, Max, spend per transaction
#Use this when: You want to benchmark supplier performance, 
#identify unusually high/low invoices, and renegotiate contracts with costly vendors.
select supplier, round(avg(invoice_amount),2) as avg_spend,
	max(invoice_amount) as highest_spend,
	min(invoice_amount) as min_spend 
    from total_spend_per_monthly 
    where invoice_amount>0
    group by supplier
    order by avg_spend desc;
    
#By Organisation #Average, Min, Max, spend per transaction 
#Use this when: 
#You want to see which teams are spending the most per transaction, and where cost control may be needed.

select organisation, round(avg(invoice_amount),2) as avg_spend,
	max(invoice_amount) as highest_spend,
	min(invoice_amount) as min_spend 
    from total_spend_per_monthly
    where invoice_amount>0
    group by organisation
    order by avg_spend desc;
    
# By Expense Type  #Average, Min, Max, spend per transaction 
#Use this when:
#You're analyzing how much is typically spent on each category (e.g., electricity vs. consultancy) 
# — very helpful for budgeting and identifying unnecessary high-cost categories.

select expense_type, round(avg(invoice_amount),2) as avg_spend,
	max(invoice_amount) as highest_spend,
	min(invoice_amount) as min_spend 
    from total_spend_per_monthly
    where invoice_amount>0
    group by expense_type
    order by avg_spend desc;
    
#Transaction & Supplier Summary
with cte1 as 
(select supplier, count(*) as total_transaction_count,
count(distinct(supplier)) as unique_suppliers 
from total_spend_per_monthly group by supplier)
select supplier, total_transaction_count
from cte1 group by supplier order by total_transaction_count desc;

#postcode level spend analysis
select postcode, sum(invoice_amount) as total_spend from total_spend_per_monthly
group by postcode order by total_spend desc;

# Month-over-Month Spend % Change
with monthly_totals as
(select date_format(check_date,'%Y-%m') as Month_Year, date_format(min(check_date), '%Y-%m') as sort_date,
sum(invoice_amount) as total_spend from total_spend_per_monthly 
group by Month_Year)
select Month_Year,
round((total_spend - lag(total_spend) over(order by  sort_date))/lag(total_spend) over(order by  sort_date)*100,2) as MoM_pct_Change
from monthly_totals; 

RENAME TABLE finance_data.total_spend_per_monthly TO finance_data.all_spend;
select * from vw_monthly_spend;

Update all_spend
set report_month = date_format(check_date, '%b-%Y');

#sort by date key
select date_format(check_date, '%b-%Y') as report_month,
date_format(min(check_date), '%Y-%m') as sort_key
from all_spend group by report_month order by sort_key;






























