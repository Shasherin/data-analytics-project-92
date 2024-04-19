/*Напишите запрос, который считает общее количество покупателей из таблицы customers*/
with customers_checked as( /*создаю виртуальную таблицу*/
	select *
	from(select *,
		row_number() OVER(partition by first_name, middle_initial, last_name, age order by first_name, last_name, middle_initial, age) AS row
		from customers) as row
	where row = 1 /*фильтрую дублирующиеся записи, сравнивая уникальность четырех полей: ФИО + возраст*/
	)
select count(*) as  "customers_count" /*считаю количество записей (уникальность каждой строки проверена ранее)*/
from customers_checked
;


/*второй способ проверки уникальности, что нашел:
select first_name, middle_initial, last_name, age, COUNT(*)  --каждой дублирующейся после группировки строке присваиваем count
from customers c 
group by first_name, middle_initial, last_name, age --группируем по уникальности 4х полей: ФИО + возвраст
having count (*) = 1 --оставляем только первое из каждой группированной строки(2 и последующие в count указывают на дубль)*/

/*отчет с продавцами у которых наибольшая выручка*/
select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller, /*объединил столбы  в 1 с пробелами между значениями*/
count(s.sales_id) as operations,  /*посчитал количество операций после группировки*/
floor(sum(quantity * price)) as income /*посчитал округленную до целого вниз выручку по продавцу после группировки*/
from sales s 
inner join products p 
	on s.product_id = p.product_id /* объединил таблицы*/
inner join employees e 
	on e.employee_id = s.sales_person_id /* объединил таблицы*/
group by sales_person_id, concat(first_name,' ', middle_initial, ' ', last_name) /* критерии группировки*/
order by income desc /*сортировка по выручке*/
limit 10 /*10 первых запросил*/
;

/*отчет с продавцами, чья выручка ниже средней выручки всех продавцов*/
with income_by_seller as (select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller,
count(s.sales_id) as operations,
sum(quantity * price) as income, 
floor(avg (quantity * price)) as average_income /*посчитал среднюю выручку по заказу сгруппированную по продавцам*/
from sales s 
inner join products p 
	on s.product_id = p.product_id
inner join employees e 
	on e.employee_id = s.sales_person_id
group by sales_person_id, concat(first_name,' ', middle_initial, ' ', last_name)
)
select seller,
	average_income
from income_by_seller
where  average_income < (select floor(avg(average_income)) from income_by_seller) /* сравнил среднюю выручку каждого продавца с общей средней по всем*/
order by average_income
;
/*Или
with income_by_seller as (select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller,
count(s.sales_id) as operations,
sum(quantity * price) as income,
floor(avg (quantity * price)) as average_income,
count(sales_id) as count_of_sales --посчитал количество продаж
from sales s 
inner join products p 
	on s.product_id = p.product_id
inner join employees e 
	on e.employee_id = s.sales_person_id
group by sales_person_id, concat(first_name,' ', middle_initial, ' ', last_name)
)
select seller,
	average_income
from income_by_seller
where  average_income < (select floor(sum(income) / sum(count_of_sales)) from income_by_seller) --сравнил с отношением суммы продаж к количеству продаж
order by average_income
;*/

/*отчет с данными по выручке по каждому продавцу и дню недели*/
select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller,
to_char(sale_date, 'Day') as day_of_week,  /*привели формат даты к дню недели*/
floor(sum(quantity * price)) as income
from sales s 
inner join products p 
	on s.product_id = p.product_id
inner join employees e 
	on e.employee_id = s.sales_person_id
group by to_char(sale_date, 'Day'), EXTRACT(ISODOW from sale_date), concat(first_name,' ', middle_initial, ' ', last_name) /*группировка по дню недели + продавцу*/
order by EXTRACT(ISODOW from sale_date), seller /*сортировка по номеру дня недели, где понедельник - 1, вскр - 7*/
;

/*отчет с возрастными группами покупателей*/
with category_by_age as (select age, /*создал вирт.таблицу*/
case when age >= 16 and age <= 25 then '16-25' /*добавил возрастную категорию для каждого покупателя*/
	 when age >= 26 and age <= 40 then '26-40'
	 when age >= 41 then '40+'
	 else 'uncategory' /* на всякий случай добавил категорию, если возраст покупателя не попал под остальные условия*/
end as age_category
from customers
)
select age_category,
	count(*) /*посчитал количество*/
from category_by_age
group by age_category /*сгруппировал по возрасту*/
order by age_category /*отсортировал по возрасту*/ 
;

/*отчет с количеством покупателей и выручкой по месяцам*/
select 
	extract (year from sale_date):: text || '-' || /*извлекли год, добавили '-'*/
	lpad(extract (month from sale_date):: text, 2, '0') as selling_month, /*извлекли месяц + привели к двузначному числу(добавляем слева 0, до 2х символов в номере) для корректной сортировки*/
	count(distinct s.customer_id) as total_customers, /*посчитали кол-во уникальных покупателей*/
	floor(sum(quantity * price)) as income
from sales s
inner join products p 
	on s.product_id = p.product_id
group by extract (year from sale_date):: text || '-' || LPAD(extract (month from sale_date):: text, 2, '0') /*сгруппировали по YYYY-MM*/
order by extract (year from sale_date):: text || '-' || LPAD(extract (month from sale_date):: text, 2, '0') /*отсортировали по YYYY-MM*/
;

/*или
select 
	to_char(s.sale_date, 'YYYY-MM') as selling_month, --оставили только 'YYYY-MM' из даты
	count(distinct s.customer_id) as total_customers,
	floor(sum(quantity * price)) as income
from sales s
inner join products p 
	on s.product_id = p.product_id
group by to_char(s.sale_date, 'YYYY-MM') 
order by to_char(s.sale_date, 'YYYY-MM')
;*/

/*отчет  с покупателями первая покупка которых пришлась на время проведения специальных акций*/
with rn_sales as ( /*создаём виртуальную таблицу*/
	select *,
		row_number() OVER(partition by customer_id order by sale_date, sales_id) AS row /*добавляем номер покупки в разрезе id покупателя, сортируя по дате, id покупки, не хватает времени покупки для уверенности, что покупка у покупателя первая(при наличии нескольких в 1 день)*/
	from sales
)
select 
	concat(c.first_name,' ', c.middle_initial, ' ', c.last_name) as customer, /*объединяем ФИО покупателя*/
	to_char(rns.sale_date, 'YYYY-MM-DD') as sale_date,  /*приводим к формату 'YYYY-MM-DD'*/
	concat(e.first_name,' ', e.middle_initial, ' ', e.last_name) as seller  /*объединяем ФИО продавца*/
from rn_sales rns
inner join products p 
	on rns.product_id = p.product_id
inner join employees e 
	on e.employee_id = rns.sales_person_id
inner join customers c
	on rns.customer_id = c.customer_id
where row = 1 and (rns.quantity * p.price) = 0 /*фильтруем покупки кроме первой с 0 ценой*/
order by rns.customer_id /*сортируем по id покупателя*/
;

;