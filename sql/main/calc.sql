drop table if exists results;
create table results(
	id INT,
	response TEXT
);

-- 1. Вывести максимальное количество человек в одном бронировании
insert into bookings.results
select 1, max(cnt) from
(select count(passenger_id) as cnt from bookings.tickets
group by book_ref) s1;

-- 2. Вывести количество бронирований с количеством людей больше среднего значения людей на одно бронирование
insert into bookings.results
select 2, count(book_ref) from
(select book_ref from bookings.tickets
group by book_ref
having count(passenger_id) >
(select avg(psg_to_book) from
(select count(passenger_id) as psg_to_book from bookings.tickets
group by book_ref) s1)
) s2;

-- 3. Вывести количество бронирований, у которых состав пассажиров повторялся два и более раза, среди бронирований с максимальным количеством людей
insert into bookings.results
select 3, count(book_ref) from
(select group_psg, book_ref, count(book_ref) over(partition by group_psg) as cnt from
(select
book_ref, string_agg(passenger_id, ';' order by passenger_id) as group_psg
from bookings.tickets
group by book_ref
having count(passenger_id) = (select max(cnt) from
(select count(passenger_id) as cnt from bookings.tickets
group by book_ref) s1)) s2
) s3
where cnt > 1;

-- 4. Вывести номера брони и контактную информацию по пассажирам в брони (passenger_id, passenger_name, contact_data) с количеством людей в брони = 3
insert into bookings.results
select 4, concat(book_ref, '|', string_agg(info, '|' order by info)) from
(select * from
(select book_ref, concat(passenger_id, '|', passenger_name, '|', contact_data) as info,
count(passenger_id) over(partition by book_ref) psg_num from bookings.tickets
order by book_ref, passenger_id, passenger_name, contact_data) s1
where psg_num=3) s2
group by book_ref;

-- 5. Вывести максимальное количество перелётов на бронь
insert into bookings.results
select 5, count(flight_id) as cnt
from
bookings.tickets join bookings.ticket_flights
on
tickets.ticket_no = ticket_flights.ticket_no
group by book_ref
order by cnt desc
limit 1;

-- 6. Вывести максимальное количество перелётов на пассажира в одной брони
insert into bookings.results
select 6, count(flight_id) as cnt
from
bookings.tickets join bookings.ticket_flights
on
tickets.ticket_no = ticket_flights.ticket_no
group by book_ref, passenger_id
order by cnt desc
limit 1;

-- 7. Вывести максимальное количество перелётов на пассажира
insert into bookings.results
select 7, count(flight_id) as cnt
from
bookings.tickets join bookings.ticket_flights
on
tickets.ticket_no = ticket_flights.ticket_no
group by passenger_id
order by cnt desc
limit 1;

-- 8. Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общие траты на билеты, для пассажира потратившему минимальное количество денег на перелеты
insert into bookings.results
select 8, concat(info, '|', tot_amount) from
(select *, min(tot_amount) over() as min_tot_amnt from
(select concat(passenger_id, '|', passenger_name, '|', contact_data) as info, sum(amount) as tot_amount
from
bookings.tickets join bookings.ticket_flights
on
tickets.ticket_no = ticket_flights.ticket_no
group by passenger_id, passenger_name, contact_data
order by passenger_id, passenger_name, contact_data
) s1 ) s2
where tot_amount = min_tot_amnt;

-- 9. Вывести контактную информацию по пассажиру(ам) (passenger_id, passenger_name, contact_data) и общее время в полётах, для пассажира, который провёл максимальное время в полётах
insert into bookings.results
select 9, concat(passenger_id, '|', passenger_name, '|', contact_data, '|', sum_act_d) as info from
(select passenger_id,
       passenger_name,
       contact_data,
       sum(actual_duration) as sum_act_d,
       rank() over (order by sum(actual_duration) desc) as rnk
from
bookings.tickets bt
join bookings.ticket_flights btf on bt.ticket_no = btf.ticket_no
join  bookings.flights_v bf on btf.flight_id = bf.flight_id
where status = 'Arrived'
group by passenger_id, passenger_name, contact_data
order by sum_act_d desc) s1
where rnk = 1
order by info;

-- 10. Вывести город(а) с количеством аэропортов больше одного
insert into bookings.results
select 10, city
from bookings.airports
group by city
having count(airport_code) > 1
order by city;

-- 11. Вывести город(а), у которого самое меньшее количество городов прямого сообщения
insert into bookings.results
select 11, departure_city from
(select departure_city,
	   rank() over (order by count(distinct arrival_city)) as rnk
from bookings.routes
group by departure_city
order by departure_city) s1
where rnk = 1;

-- 12. Вывести пары городов, у которых нет прямых сообщений исключив реверсные дубликаты
insert into bookings.results
select 12, concat(city1, '|', city2) city1_2 from
(select t1.city as city1, t2.city as city2
from bookings.airports t1,
     bookings.airports t2
where t1.city < t2.city
except
select arrival_city, departure_city
from routes
except
select departure_city, arrival_city 
from routes) s1
order by city1_2;

-- 13. Вывести города, до которых нельзя добраться без пересадок из Москвы
insert into bookings.results
select 13, city from airports
where city != 'Москва' and city NOT in
(select arrival_city from bookings.routes
 where departure_city = 'Москва')
order by city;

-- 14. Вывести модель самолета, который выполнил больше всего рейсов
insert into bookings.results
select 14, model from
(select model, count(flight_id), rank() over(order by count(flight_id) desc) as rnk from
bookings.flights join bookings.aircrafts 
on
flights .aircraft_code = aircrafts.aircraft_code
where status = 'Arrived'
group by model) s1
where rnk = 1;

-- 15. Вывести модель самолета, который перевез больше всего пассажиров
insert into bookings.results
select 15, model from
(select ba.model, count(distinct btf.ticket_no), rank() over(order by count(distinct btf.ticket_no) desc) as rnk
from bookings.ticket_flights btf
join bookings.flights bf on btf.flight_id = bf.flight_id
join bookings.aircrafts ba on bf.aircraft_code = ba.aircraft_code
where bf.status = 'Arrived'
group by ba.model) s1
where rnk = 1;

-- 16. Вывести отклонение в минутах суммы запланированного времени перелета от фактического по всем перелётам
insert into bookings.results
select 16, abs(extract(epoch from sum(scheduled_duration) - sum(actual_duration)) / 60)::int as difference
FROM bookings.flights_v
WHERE status = 'Arrived';

-- 17. Вывести города, в которые осуществлялся перелёт из Санкт-Петербурга 2016-09-13
insert into bookings.results
select distinct 17, arrival_city
from bookings.flights_v
where actual_departure::date = '2016-09-13' and
      status = 'Arrived' and
      departure_city = 'Санкт-Петербург'
order by arrival_city;

-- 18. Вывести перелёт(ы) с максимальной стоимостью всех билетов
insert into bookings.results
select 18, flight_id from
(select btf.flight_id,
        rank() over (order by sum(btf.amount) desc) as rnk
 from bookings.ticket_flights btf
 join bookings.flights bf ON btf.flight_id = bf.flight_id
 where bf.status != 'Cancelled'
 group by btf.flight_id
 order by sum(btf.amount) desc) s1
where rnk = 1
order by s1.flight_id;

-- 19. Выбрать дни в которых было осуществлено минимальное количество перелётов
insert into bookings.results
select 19 as id, act_d from
(select actual_departure::date as act_d,
        rank() over (order by COUNT(actual_departure::date)) as rnk
 from bookings.flights_v
 where status != 'Cancelled' and actual_departure is not null
 group by actual_departure::date) s1
where rnk = 1
order by act_d;

-- 20. Вывести среднее количество вылетов в день из Москвы за 09 месяц 2016 года
insert into bookings.results
select 20, avg(act_d) from
(select count(actual_departure) as act_d
from flights_v
where status in ('Departed', 'Arrived') and departure_city = 'Москва' and
      extract(month from actual_departure) = '09' and
      extract(year from actual_departure) = '2016'
group by actual_departure::date) s1;

-- 21. Вывести топ 5 городов у которых среднее время перелета до пункта назначения больше 3 часов
insert into bookings.results
select 21, departure_city from bookings.flights_v
where status = 'Arrived'
group by departure_city
having avg(actual_duration) > interval '3 hours'
order by avg(actual_duration) desc, departure_city asc
limit 5;


