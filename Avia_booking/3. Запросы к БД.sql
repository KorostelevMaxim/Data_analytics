--�������� ������. ���������� �.�.

SET search_path TO bookings

--������� �1
--� ����� ������� ������ ������ ���������? 

-- �������� ������ �� �������� airports. ��������� ����������, ��������� ������� count 
select airports.city
from airports 
group by airports.city
having count(airport_code)>1 


--������� �2
--� ����� ���������� ���� �����, ����������� ��������� � ������������ ���������� ��������? (���������)

-- ������������ � ������� join ������� aircrafts ��� ����������� ������������� �����. 
-- ����� � ������� ���������� ���������� ����. ��������� ������� �����.
-- ������� �������� ��������(����� �������� ������, ������ �� ���������)
 
select distinct arrival_airport 
from flights f
join aircrafts as a on f.aircraft_code = a.aircraft_code 
where range = (select max(range)
	from aircrafts a2)  

	
--������� �3
--������� 10 ������ � ������������ �������� �������� ������ (�������� LIMIT)

-- � ������� where ������� ������, ����� ����� �������� �������. 
-- ����� ������� ������� ����� ����������� �������� ������ � ��������.
-- ����� ��������� (�� ���� � ���) � ������ ����� 10

select flight_id, actual_departure-scheduled_departure as "�������� ������" 
from flights f 
where actual_departure notnull 
order by "�������� ������"  desc 
limit 10




--������� �4
--���� �� �����, �� ������� �� ���� �������� ���������� ������? (������ ��� JOIN)


-- � ������� join ������������ ������� tickets, ����� ����� �� ������� boarding_passes . 
-- ����� ���������� left join ��� �������� ������, ������� ��������� �� boarding_passes .
-- ����� ��������� ����������� where � ������� �����������, ��� �������� �� ����������� ������ �����������

select count(b.book_ref) as "���������� ��������������� ������" 
from bookings b 
join tickets t on t.book_ref = b.book_ref 
left join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.ticket_no is null 


--������� �5
--������� ���������� ��������� ���� ��� ������� �����, �� % ��������� � ������ ���������� ���� � ��������. 
--�������� ������� � ������������� ������ -  
--��������� ���������� ���������� ���������� ���������� �� ������� ��������� �� ������ ����.
--�.�. � ���� ������� ������ ���������� ������������� �����. -
--������� ������� ��� �������� �� ������� ��������� �� ���� ��� ����� ������ ������ � ������� ���.
--( ������� �������, ���������� ���/� cte)

 -- � �te1 ������� ���������� �������� ���������� ������� ��� ������� �����
 -- � �te2 ������� ���������� ���� � ��������
 -- ����� � ������� ������� ��� ��� �� aircraft_code
 -- ��� ������������� ����� ���������� ������� ������� ��������� �� ������������ ������� ������. 

with cte1 as (
	select 
		f.flight_id,
		f.flight_no,
		f.aircraft_code,
		f.departure_airport,
		f.actual_departure,
		count(bp.boarding_no) as "���������� ���������� ����"
	from flights f 
	join boarding_passes bp on bp.flight_id = f.flight_id 
	group by f.flight_id),
cte2 as(
	select 
		s.aircraft_code,
		count(s.seat_no) as "���������� ���� � ��������"
	from seats s 
	group by s.aircraft_code)
select 
	t.flight_no,
	t.departure_airport,
	t.actual_departure,
	"���������� ���������� ����",
	round(("���������� ���� � ��������" - "���������� ���������� ����") / "���������� ���� � ��������" :: numeric, 2) * 100 as "���������� free ���� � ��������",
	sum("���������� ���������� ����") over (partition by (t.actual_departure::date) order by t.actual_departure) as "���������� ������� ���������� � ���� ����"
from cte1 t
join cte2 t1 on t1.aircraft_code = t.aircraft_code


--������� �6
--������� ���������� ����������� ��������� �� ����� ��������� �� ������ ����������. (��������� ��� ����, �������� ROUND)

-- ������� ���������� ������ ����� �������� count
-- � ���������� ������� ����� ����� ���������
-- ������� ������� �� aircraft_code
-- �� � ���������� �� ������ ��������� 

select 
	a.model as "������ ��������",
	count(f.flight_id) as "�����",
	round(count(f.flight_id) / 
		(select count(f.flight_id)
		from flights f 
		where f.actual_departure is not null)::numeric * 100 , 1) as "�������"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_departure is not null
group by a.model

--������� �7
--���� �� ������, � ������� �����  ��������� ������ - ������� �������, ��� ������-������� � ������ ��������? (CTE)

 
-- � cte3 �������� ��� ��������� �� ������ ������ � ���� �� ������ ������
-- ���������� ������ �� ������ ����������� � ��������, � ����� �� ������ ������.
-- �� ������� ������� �������� ������ �� ��� � ���� �� ���� ������� � 1 ������
-- ��������� ������� min(business_min) < max(economy_max)
-- ���������� ��������� exists ��� �������� ����������� ����� � ����������. ��� ��� ����� ���, ������ \
-- ��� �������, � ������� �����  ��������� ������ - ������� �������, ��� ������-�������


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
select arr_city as "��������"
from cte3
where exists(
select 
	dep_city as "�����", 
	arr_city as "��������", 
	min(business_min) as "������� �� ������", 
	max(economy_max) as "�������� �� ������"
from cte3
group by 1, 2
having min(business_min) < max(economy_max))

--������� �8
--����� ������ �������� ��� ������ ������? 
--(��������� ������������ � ����������� FROM, �������������� ��������� �������������, �������� EXCEPT)

-- ������ ������������� ��� ��������� �������, ����� �������� ���� �����
-- ������ ��� ������ � ������������� ��� ��������� ������ ����������� � ������ ��������
-- � �������� ������� �������� ��������� ������������ ���� �������, � �������� �� �����������
-- ����� ��������� ������� ������ ������, ������� ���� � �������������.
 
 
create view direct_flight as
select distinct 
	a.city as "����� �������",
	a2.city as "����� ��������"
from flights f 
join airports a on f.departure_airport = a.airport_code 
join airports a2 on f.arrival_airport = a2.airport_code
 
select distinct 
	a.city "����� �������",
	a2.city "����� ��������"
from airports a, airports a2 
except 
select * from direct_flight
join ticket_flights tf on tf.flight_id = f.flight_id


--������� �9
--��������� ���������� ����� �����������, ���������� ������� �������, 
--�������� � ���������� ������������ ���������� ���������  � ���������, ������������� ��� ����� *? 
--(�������� RADIANS ��� ������������� sind/cosd, CASE)

-- � ������� ��������� case �������� �������, ��� ���������� ��������� ������ �������� > ����������� ���������� ����� ��������
-- ������� ������� ���������� �� �������� � ������, ����� ������� � ����������

select distinct 
	ar.airport_name "�����",
	ar2.airport_name as "��������",
	a."range"  as "���������� ��������� ������ ��������",	
	case when 
		a."range" >
		acos(sind(ar.latitude) * sind(ar2.latitude) + cosd(ar.latitude) * cosd(ar2.latitude) * cosd(ar.longitude - ar2.longitude)) * 6371 
		then '��!'
		else '���!'
		end "����� ������ �������?"
from flights f
join airports ar on f.departure_airport = ar.airport_code
join airports ar2 on f.arrival_airport = ar2.airport_code
join aircrafts a on a.aircraft_code = f.aircraft_code 

--������ �10. ������� �������� ������ ��� �������� ������ � �������, ���� ����� ����������� ��������.

--����������� ������� � ����������. ���� ����������� ����� �������� � ������ ������� ��������� ����� � �������.  ����� ��������� ����������� �� �������.

select 
	a.model as "������ ��������",
	sum(f.actual_arrival - f.actual_departure) as "��������� ����� � �������"
from aircrafts a 
join flights f on f.aircraft_code = a.aircraft_code 
where f.actual_arrival is not null
group by a.model




--������ �11. ������� ���� �������� ���������� ������� �� ������ �����

-- � ������� ������� ������� ������� ���������� ������� �� ������ �����. ������� ������� boarding_passes 

select 
	book_ref as "����� �����", 
	count(t.ticket_no) over (partition by book_ref) as "���-�� ������� �� �����"
from tickets t 
join boarding_passes bp on bp.ticket_no = t.ticket_no 




--������ �12. ������� ����� ����� ������ �� ������� ������ �������


-- � ��� ��� ������ �������. ������� ����� ������ � ���������� �� ������ 

select fare_conditions, sum(amount)  
from ticket_flights tf 
group by fare_conditions



--������ �13. ����� ������� � ���������� ���������� ��������


-- ������� ����� ������ �� ��������. ��� ��������� �������� ������� ��� ���� ������� city. ���������� �� �������, ��������� �� ���������� � ������� ������������ ������ ����������

select 
	a.city as "����� �������",
	a2.city as "����� ��������",
	sum(tf.amount) as "���������� ������"
from flights f 
join ticket_flights tf on tf.flight_id = f.flight_id 
join airports a on f.departure_airport = a.airport_code
join airports a2 on f.arrival_airport = a2.airport_code
group by 1, 2
order by 3 desc 
limit 1	
	


--������ �14. ����� ��������� � ��������� ����� �� ������������ ������� (���������� � �����)


-- � ������� ��� ������� ���������� ������ � ����� �� ���. ���������� �� �������,�������� 3 ������. 
-- ����� ����� ��������� �� ���� ��������, ����� ��� ���� ����������� � ����������


with cte1 as ( 
  select
    date_trunc('month', book_date ::date) as "�����", 
    count(book_ref) as "����������",
    sum(total_amount) as "�����"
  from bookings b
  group by 1)
select "�����", "����������", "�����" 
from cte1 
where "����������" * "�����" = (select max("����������" * "�����") from cte1) 
or "����������" * "�����" = (select  min("����������" * "�����") from cte1)

--������ �15. ����� ������ �������� ��������� �� ������ ���������? ���������� ��������� ���������� ��������� � ������������� ��������� ����� 24 �����.

	
select distinct 
	a.city "����� �������",
	a2.city "����� ��������"
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
		(f.scheduled_departure - lag(f.scheduled_arrival) over (partition by tf.ticket_no order by f.scheduled_arrival)) as "���������"
	from ticket_flights tf
	inner join (select ticket_no 
	              from ticket_flights tf2
	              group by ticket_no 
	              having count(flight_id)>1) tt
	on tf.ticket_no = tt.ticket_no
	inner join flights f on f.flight_id = tf.flight_id) flights 
join airports a on a.airport_code = flights.departure_airport
join airports a2 on a2.airport_code = flights.arrival_airport
where "���������"< interval '24 hour

