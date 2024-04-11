4)
with customers_checked as( --создаю виртуальную таблицу
	select *
	from(select *,
		row_number() OVER(partition by first_name, middle_initial, last_name, age order by first_name, last_name, middle_initial, age) AS row
		from customers) as row
	where row = 1 --фильтрую дублирующиеся записи, сравнивая уникальность четырех полей: ФИО + возраст
	)
select count(*) as  "customers_count" --считаю количество записей (уникальность каждой строки проверена ранее)
from customers_checked
;


второй способ проверки уникальности, что нашел:
select first_name, middle_initial, last_name, age, COUNT(*)  --каждой дублирующейся после группировки строке присваиваем count
from customers c 
group by first_name, middle_initial, last_name, age --группируем по уникальности 4х полей: ФИО + возвраст
having count (*) = 1 --оставляем только первое из каждой группированной строки(2 и последующие в count указывают на дубль)

5a) 
select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller, --объединил столбы  в 1 с пробелами между значениями
count(s.sales_id) as operations,  --посчитал количество операций после группировки
floor(sum(quantity * price)) as income --посчитал округленную до целого вниз выручку по продавцу после группировки
from sales s 
inner join products p 
	on s.product_id = p.product_id -- объединил таблицы
inner join employees e 
	on e.employee_id = s.sales_person_id -- объединил таблицы
group by sales_person_id, concat(first_name,' ', middle_initial, ' ', last_name) -- критерии группировки
order by income desc --сортировка по выручке
limit 10 --10 лучших продавцов запросил к отображению
;

5b)
with income_by_seller as (select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller,
count(s.sales_id) as operations,
sum(quantity * price) as income, 
floor(avg (quantity * price)) as average_income --посчитал среднюю выручку по заказу сгруппированную по продавцам
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
where  average_income < (select floor(avg(average_income)) from income_by_seller) - сравнил среднюю выручку каждого продавца с общей ср
order by average_income
;
Или
 
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
	--(select floor(avg(average_income)) from income_by_seller) as avg_income_for_all
from income_by_seller
where  average_income < (select floor(sum(income) / sum(count_of_sales)) from income_by_seller) --сравнил с отношением суммы продаж к количеству продаж
order by average_income
;

5с)
select 
concat(first_name,' ', middle_initial, ' ', last_name) as seller,
to_char(sale_date, 'Day') as day_of_week,  --привели формат даты к дню недели
floor(sum(quantity * price)) as income
from sales s 
inner join products p 
	on s.product_id = p.product_id
inner join employees e 
	on e.employee_id = s.sales_person_id
group by to_char(sale_date, 'Day'), EXTRACT(ISODOW from sale_date), concat(first_name,' ', middle_initial, ' ', last_name) --группировка по дню недели + продавцу
order by EXTRACT(ISODOW from sale_date), seller --сортировка по номеру дня недели, где понедельник - 1, вскр - 7
;

6a)
with category_by_age as (select age, --создал вирт.таблицу
case when age >= 16 and age <= 25 then '16-25' --добавил возрастную категорию для каждого покупателя
	 when age >= 26 and age <= 40 then '26-40'
	 when age >= 41 then '40+'
	 else 'uncategory' -- на всякий случай добавил категорию, если возраст покупателя не попал под остальные условия
end as age_category
from customers
)
select age_category,
	count(*) --посчитал количество
from category_by_age
group by age_category --сгруппировал по возрасту
order by age_category --отсортировал по возрасту 
;