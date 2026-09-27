/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Мацухов Алхан
 * Дата: 
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
WITH info_users AS (
	SELECT 
		(SELECT COUNT(*) FROM fantasy.users) AS total_users, -- общее количество игроков, зарегистрированных в игре
		COUNT(*) AS total_users_with_payer_1, -- количество платящих игроков
		ROUND(COUNT(*)::NUMERIC  / (SELECT COUNT(*) FROM fantasy.users)::NUMERIC, 2) AS payer_users -- доля платящих игроков от общего количества пользователей, зарегистрированных в игре
	FROM fantasy.users
	WHERE payer = 1 -- Фильтрации по платаящим игрокам
),
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
info_about_race_payer AS (
	SELECT
		race.race_id,
		race.race,
		COUNT(*) AS total_users_payer,
		COUNT(CASE WHEN users.payer = 1 THEN 1 END) AS paying_users,
		ROUND(COUNT(CASE WHEN users.payer = 1 THEN 1 END)::numeric / COUNT(*)::NUMERIC * 100.0, 2) AS paying_users_from_total_users_payer
	FROM fantasy.users users
	JOIN fantasy.race AS race ON race.race_id = users.race_id
	GROUP BY race.race_id, race.race 
),
-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
info_amount AS (
	SELECT
		COUNT(amount) AS total_amount,
		SUM(amount) AS total_amount_sum,
		MIN(amount) AS min_amount,
		MAX(amount) AS max_amount,
		AVG(amount)::numeric AS avg_amount,
		PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount)::numeric AS median_amount,
		STDDEV(amount)::numeric AS stand_dev_amount,
		COUNT(CASE WHEN amount = 0 THEN 1 END) AS total_amount_zero,
		ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)::numeric / COUNT(*)::numeric * 100.0, 2) AS zero_from_total_amount
	FROM fantasy.events
),
-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
info_amount_with_zero AS (
	SELECT
		COUNT(CASE WHEN amount = 0 THEN 1 END) AS total_amount_zero,
		ROUND(COUNT(CASE WHEN amount = 0 THEN 1 END)::numeric / COUNT(*)::numeric * 100.0, 2) AS zero_from_total_amount
	FROM fantasy.events
),
-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
info_about_game_items AS (
	SELECT
		item_code,
		COUNT(*) FILTER(WHERE amount > 0) AS total_items,
		(SELECT COUNT(*) FROM fantasy.events) AS total_items_all,
		ROUND(COUNT(*) FILTER(WHERE amount > 0) / (SELECT COUNT(*) FROM fantasy.events)::NUMERIC * 100.0, 2) AS popular_items
	FROM fantasy.events
	GROUP BY item_code
	ORDER BY popular_items DESC
),
-- Часть 2. Решение ad hoc-задачbи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
info_users_race_transaction AS (
	SELECT
		u.race_id,
		COUNT(DISTINCT u.id) AS unique_buyers, 
		COUNT(e.transaction_id) AS total_transactions, 
		SUM(e.amount) AS total_revenue, 
		COUNT(DISTINCT u.id) FILTER (WHERE u.payer = 1) AS paying_users_flag_count 
	FROM fantasy.events e
	JOIN fantasy.users u ON u.id = e.id
	WHERE e.amount > 0 
	GROUP BY u.race_id
)
SELECT 
	*
FROM info_users_race_transaction
