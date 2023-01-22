--Итоговая работа. Коростелев М.В.

SET search_path TO bookings

--ЗАДАНИЕ №1
--В каких городах больше одного аэропорта? 

-- Получаем данные из таблички airports. Выполняем фильтрацию, используя функцию count 
select airports.city
from airports 
group by airports.city
having count(airport_code)>1 


--ЗАДАНИЕ №2
--В каких аэропортах есть рейсы, выполняемые самолетом с максимальной дальностью перелета? (Подзапрос)

-- Присоединяем с помощью join таблицу aircrafts для определения характеристик судна. 
-- После с помощью подзапроса определяем макс. дальность перелта судна.
-- Выводим аэропорт прибытия(можем аэропорт вылета, данные не изменятся)
 
select distinct arrival_airport 
from flights f
join aircrafts as a on f.aircraft_code = a.aircraft_code 
where range = (select max(range)
	from aircrafts a2)  

	
--ЗАДАНИЕ №3
--Вывести 10 рейсов с максимальным временем задержки вылета (Оператор LIMIT)

-- С помощью where убираем строки, когда судно вылетело вовремя. 
-- Далее считаем разницу между фактическим временем вылета и плановым.
-- Далее сортируем (от макс к мин) и ставим лимит 10

select flight_id, actual_departure-scheduled_departure as "Задержка вылета" 
from flights f 
where actual_departure notnull 
order by "Задержка вылета"  desc 
limit 10




--ЗАДАНИЕ №4
--Были ли брони, по которым не были получены посадочные талоны? (Верный тип JOIN)


-- С помощью join присоединяем таблицу tickets, чтобы выйти на таблицу boarding_passes . 
-- Далее используем left join для возврата данных, которые совпадают из boarding_passes .
-- Далее выполняем ограничение where в котором прописываем, что значение по посадочному талону отсутствуют

select count(b.book_ref) as "Количество нереализованных броней" 
from bookings b 
join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.ticket_no is null 


--ЗАДАНИЕ №5
--Найдите количество свободных мест для каждого рейса, их % отношение к общему количеству мест в самолете. 
--Добавьте столбец с накопительным итогом -  
--суммарное накопление количества вывезенных пассажиров из каждого аэропорта на каждый день.
--Т.е. в этом столбце должна отражаться накопительная сумма. -
--сколько человек уже вылетело из данного аэропорта на этом или более ранних рейсах в течении дня.
--( Оконная функция, Подзапросы или/и cte)

 -- В сte1 считаем количество выданных посадочных талонов для каждого рейса
 -- В сte2 считаем количество мест в самолете
 -- Далее в запросе джойним оба сте по aircraft_code
 -- Для накопительной суммы используем оконную функцию группируя по фактическому времени вылета. 

with cte1 as (
	select 
		f.flight_id,
		f.flight_no,
		f.aircraft_code,
		f.departure_airport,
		f.actual_departure,
		count(bp.boarding_no) as "Количество посадочных мест"
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	group by f.flight_id),
cte2 as(
	select 
		s.aircraft_code,
		count(s.seat_no) as "Количество мест в самолете"
	from seats s 
	group by s.aircraft_code)
select 
	t.flight_no,
	t.departure_airport,
	t.actual_departure,
	"Количество посадочных мест",
	round(("Количество мест в самолете" - "Количество посадочных мест") / "Количество мест в самолете" :: numeric, 2) * 100 as "Количество free мест в самолете",
	sum("Количество посадочных мест") over (partition by (t.actual_departure::date) order by t.actual_departure) as "Количество человек вылетевших в этот день"
from cte1 t
join cte2 t1 on t1.aircraft_code = t.aircraft_code


--ЗАДАНИЕ №6
--Найдите процентное соотношение перелетов по типам самолетов от общего количества. (Подзапрос или окно, оператор ROUND)

-- Считаем количество рейсов через оператор count
-- В подзапросе находим общее число перелетов
-- Джойним таблицу по aircraft_code
-- Ну и группируем по модели самоллета 

select 
	a.model as "Модель самолета",
	count(f.flight_id) as "Рейсы",
	round(count(f.flight_id) / 
		(select count(f.flight_id)
		from flights f 
		where f.actual_departure is not null)::numeric * 100 , 1) as "Процент"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_departure is not null
group by a.model

--ЗАДАНИЕ №7
--Были ли города, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом в рамках перелета? (CTE)

 
-- В cte3 получаем мин стоимость по бизнес классу и макс по эконом классу
-- Группируем данные по городу отправления и прибытия, а также по классу билета.
-- Во внешнем запросе собираем данные по мин и макс по двум городам в 1 строку
-- Проверяем условие min(business_min) < max(economy_max)
-- Используем выражение exists для проверки возвращения строк в результате. Так как строк нет, значит \
-- нет городов, в которые можно  добраться бизнес - классом дешевле, чем эконом-классом


with cte3 as(
	select 
		a.city as dep_city,
		a2.city as arr_city,
		tf.fare_conditions,
		case 
			when tf.fare_conditions  = 'Business' 
			then min(tf.amount) 
			end as business_min,
		case 
			when tf.fare_conditions  = 'Economy' 
			then max(tf.amount) 
			end as economy_max
	from flights f 
	join ticket_flights tf on tf.flight_id = f.flight_id 
	join airports a on f.departure_airport = a.airport_code
	join airports a2 on f.arrival_airport = a2.airport_code
	group by 1, 2, 3)
select arr_city as "Прибытие"
from cte3
where exists(
select 
	dep_city as "Вылет", 
	arr_city as "Прибытие", 
	min(business_min) as "Минимум за бизнес", 
	max(economy_max) as "Максимум за эконом"
from cte3
group by 1, 2
having min(business_min) < max(economy_max))

--ЗАДАНИЕ №8
--Между какими городами нет прямых рейсов? 
--(Декартово произведение в предложении FROM, Самостоятельно созданные представления, Оператор EXCEPT)

-- Создаю представление для получения городов, между которыми есть рейсы
-- Делаем два джойна в представлении для получения города отправления и города прибытия
-- В основном запросе получаем декартово произведение всех городов, с условием их неравенства
-- Затем основного запроса убираю данные, которые есть в представлении.
 
 
create view direct_flight as
select distinct 
	a.city as "Город отбытия",
	a2.city as "Город прибытия"
from flights f 
join airports a on f.departure_airport = a.airport_code 
join airports a2 on f.arrival_airport = a2.airport_code
 
select distinct 
	a.city "Город отбытия",
	a2.city "Город прибытия"
from airports a, airports a2 
except 
select * from direct_flight
join ticket_flights tf on tf.flight_id = f.flight_id


--ЗАДАНИЕ №9
--Вычислите расстояние между аэропортами, связанными прямыми рейсами, 
--сравните с допустимой максимальной дальностью перелетов  в самолетах, обслуживающих эти рейсы *? 
--(Оператор RADIANS или использование sind/cosd, CASE)

-- С помощью выражения case проверил условие, что Допустимая дальность полета самолета > кратчайшего расстояния между городами
-- Джойним таблицу аэропортов по прибытию и убытию, также таблицу с самолетами

select distinct 
	ar.airport_name "Вылет",
	ar2.airport_name as "Прибытие",
	a."range"  as "Допустимая дальность полета самолета",	
	case when 
		a."range" >
		acos(sind(ar.latitude) * sind(ar2.latitude) + cosd(ar.latitude) * cosd(ar2.latitude) * cosd(ar.longitude - ar2.longitude)) * 6371 
		then 'Да!'
		else 'Нет!'
		end "Полет прошел успешно?"
from flights f
join airports ar on f.departure_airport = ar.airport_code
join airports ar2 on f.arrival_airport = ar2.airport_code
join aircrafts a on a.aircraft_code = f.aircraft_code 

--Задача №10. Сколько суммарно каждый тип самолета провел в воздухе, если брать завершенные перелеты.

--Задействуем таблицу с самолетами. Зная фактическое время прибытия и вылета находим суммарное время в воздухе.  Также проверяем приземлился ли самолет.

select 
	a.model as "Модель самолета",
	sum(f.actual_arrival - f.actual_departure) as "Суммарное время в воздухе"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_arrival is not null
group by a.model




--Задача №11. Сколько было получено посадочных талонов по каждой брони

-- С помощью оконной функции считаем количество билетов по каждой брони. Джойним таблицу boarding_passes 

select 
	book_ref as "Номер брони", 
	count(t.ticket_no) over (partition by book_ref) as "Кол-во билетов на бронь"
from tickets t 
join boarding_passes bp on bp.ticket_no = t.ticket_no 




--Задача №12. Вывести общую сумму продаж по каждому классу билетов


-- У нас три класса билетов. Считаем сумма продаж и группируем по классу 

select fare_conditions, sum(amount)  
from ticket_flights tf 
group by fare_conditions



--Задача №13. Найти маршрут с наибольшим финансовым оборотом


-- считаем сумма продаж по маршруту. Для получения маршрута джойним два раза таблицу city. Группируем по городам, сортируем по уменьшению и выводим максимальный оборот финансовый

select 
	a.city as "Город отбытия",
	a2.city as "Город прибытия",
	sum(tf.amount) as "Финансовый оборот"
from flights f 
join ticket_flights tf on tf.flight_id = f.flight_id 
join airports a on f.departure_airport = a.airport_code
join airports a2 on f.arrival_airport = a2.airport_code
group by 1, 2
order by 3 desc 
limit 1	
	


--Задача №14. Найти наилучший и наихудший месяц по бронированию билетов (количество и сумма)


-- С помощью сте находим количество броней и сумму по ним. Группируем по месяцам,получаем 3 месяца. 
-- После этого фильтруем по двум условиям, чтобы они были максимальны и минимальны


with cte1 as ( 
  select
    date_trunc('month', book_date ::date) as "Месяц", 
    count(book_ref) as "Количество",
    sum(total_amount) as "Сумма"
  from bookings b
  group by 1)
select "Месяц", "Количество", "Сумма" 
from cte1 
where "Количество" * "Сумма" = (select max("Количество" * "Сумма") from cte1) 
or "Количество" * "Сумма" = (select  min("Количество" * "Сумма") from cte1)

--Задача №15. Между какими городами пассажиры не делали пересадки? Пересадкой считается нахождение пассажира в промежуточном аэропорту менее 24 часов.

	
select distinct 
	a.city "Город отбытия",
	a2.city "Город прибытия"
from airports a, airports a2 
where a.city <> a2.city 
except
select distinct 
	a.city, 
	a2.city
from (
	select 
		f.departure_airport,
		f.arrival_airport,
		(f.scheduled_departure - lag(f.scheduled_arrival) over (partition by tf.ticket_no order by f.scheduled_arrival)) as "Пересадка"
	from ticket_flights tf
	inner join (select ticket_no 
	              from ticket_flights tf2
	              group by ticket_no 
	              having count(flight_id)>1) tt
	on tf.ticket_no = tt.ticket_no
	inner join flights f on f.flight_id = tf.flight_id) flights 
join airports a on a.airport_code = flights.departure_airport
join airports a2 on a2.airport_code = flights.arrival_airport
where "Пересадка"< interval '24 hour

