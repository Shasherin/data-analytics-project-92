/*Напишите запрос, который считает общее количество
покупателей из таблицы customers*/
with customers_checked as ( /*создаю виртуальную таблицу*/
    select *
    from (select
        *,
        row_number()
            over (
                partition by first_name, middle_initial, last_name, age
                order by first_name, last_name, middle_initial, age
            )
        as rw
    from customers) as rw_number
    where
        rw = 1
/*фильтрую дублирующиеся записи,
сравнивая уникальность четырех полей: ФИО + возраст*/
)

select count(*) as customers_count
/*считаю количество записей (уникальность каждой строки проверена ранее)*/
from customers_checked;

/*второй способ проверки уникальности, что нашел:
select first_name, middle_initial, last_name, age, COUNT(*) as  customers_count
--каждой дублирующейся после группировки строке присваиваем count
from customers c
group by first_name, middle_initial, last_name, age
--группируем по уникальности 4х полей: ФИО + возвраст
having count (*) = 1; --оставляем только первое из каждой группированной строки
(2 и последующие в count указывают на дубль)*/

/*отчет с продавцами у которых наибольшая выручка*/
select
    concat(e.first_name, ' ', e.last_name) as seller,
    /*объединил столбы  в 1 с пробелами между значениями*/
    count(s.sales_id) as operations,
    /*посчитал количество операций после группировки*/
    floor(sum(s.quantity * p.price)) as income
    /*нешёл округленную до целого вниз выручку по продавцу после группировки*/
from sales as s
inner join products as p
    on s.product_id = p.product_id /* объединил таблицы*/
inner join employees as e
    on s.sales_person_id = e.employee_id /* объединил таблицы*/
group by
    s.sales_person_id, concat(e.first_name, ' ', e.last_name)
/* критерии группировки*/
order by income desc /*сортировка по выручке*/
limit 10; /*10 первых запросил*/

/*отчет с продавцами, чья выручка ниже средней выручки всех продавцов*/
with income_by_seller as (
    select
        concat(e.first_name, ' ', e.last_name) as seller,
        count(s.sales_id) as operations,
        sum(s.quantity * p.price) as income,
        floor(avg(s.quantity * p.price)) as average_income
        /*посчитал среднюю выручку по заказу сгруппированную по продавцам*/
    from employees as e
    inner join sales as s
        on e.employee_id = s.sales_person_id
    inner join products as p
        on s.product_id = p.product_id
    group by s.sales_person_id, concat(e.first_name, ' ', e.last_name)
)

select
    seller,
    average_income
from income_by_seller
where average_income < (select floor(avg(average_income)) from income_by_seller)
/* сравнил среднюю выручку каждого продавца с общей средней по всем*/
order by average_income;

/*отчет с данными по выручке по каждому продавцу и дню недели*/
select
    concat(e.first_name, ' ', e.last_name) as seller,
    lower(to_char(s.sale_date, 'Day')) as day_of_week,
    /*привели формат даты к дню недели*/
    floor(sum(s.quantity * p.price)) as income
from employees as e
inner join sales as s
    on e.employee_id = s.sales_person_id
inner join products as p
    on s.product_id = p.product_id
group by
    to_char(s.sale_date, 'Day'),
    extract(isodow from s.sale_date),
    concat(e.first_name, ' ', e.last_name)
    /*группировка по дню недели + продавцу*/
order by extract(isodow from s.sale_date), seller;
/*сортировка по номеру дня недели, где понедельник - 1, вскр - 7*/

/*отчет с возрастными группами покупателей*/
with category_by_age as (
    select
        age,/*создал вирт.таблицу*/
        case
            when age >= 16 and age <= 25 then '16-25'
            /*добавил возрастную категорию для каждого покупателя*/
            when age >= 26 and age <= 40 then '26-40'
            when age >= 41 then '40+'
            else 'uncategory'/* на всякий случай добавил категорию,
	        если возраст покупателя не попал под остальные условия*/
        end as age_category
    from customers
)

select
    age_category,
    count(*) as age_count/*посчитал количество*/
from category_by_age
group by age_category/*сгруппировал по возрасту*/
order by age_category;/*отсортировал по возрасту*/

/*отчет с количеством покупателей и выручкой по месяцам*/
select
    to_char(s.sale_date, 'YYYY-MM') as selling_month,
    --оставили только 'YYYY-MM' из даты
    count(distinct s.customer_id) as total_customers,
    floor(sum(s.quantity * p.price)) as income
from sales as s
inner join products as p
    on s.product_id = p.product_id
group by to_char(s.sale_date, 'YYYY-MM')
order by to_char(s.sale_date, 'YYYY-MM');

/*отчет  с покупателями первая покупка которых пришлась
на время проведения специальных акций*/
with rn_sales as ( /*создаём виртуальную таблицу*/
    select
        *,
        row_number() over (partition by
            customer_id
        order by sale_date, sales_id) as rw_number
    /*добавляем номер покупки в разрезе id покупателя,
    сортируя по дате, id покупки, не хватает времени покупки для
    уверенности, что покупка у покупателя первая
    (при наличии нескольких в 1 день)*/
    from sales
)

select
    concat(c.first_name, ' ', c.last_name) as customer,
    /*объединяем ФИО покупателя*/
    to_char(rns.sale_date, 'YYYY-MM-DD') as sale_date,
    /*приводим к формату 'YYYY-MM-DD'*/
    concat(e.first_name, ' ', e.last_name) as seller/*объединяем ФИО продавца*/
from customers as c
inner join rn_sales as rns
    on c.customer_id = rns.customer_id
inner join employees as e
    on rns.sales_person_id = e.employee_id
inner join products as p
    on rns.product_id = p.product_id
where rns.rw_number = 1 and (rns.quantity * p.price) = 0
/*фильтруем покупки кроме первой с 0 ценой*/
order by rns.customer_id;/*сортируем по id покупателя*/
