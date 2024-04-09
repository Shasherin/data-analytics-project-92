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