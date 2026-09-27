/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Мацухов Алхан
 * Дата: 27.09.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT 
    COUNT(id) AS total_users,
    SUM(payer) AS total_paying_users,
    ROUND(AVG(payer)::NUMERIC * 100.0, 2) AS payer_users_share_pct
FROM fantasy.users;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа
SELECT
    r.race AS "Раса персонажа",
    COUNT(u.id) AS total_users_in_race,
    SUM(u.payer) AS paying_users_in_race,
    ROUND(AVG(u.payer)::NUMERIC * 100.0, 2) AS paying_users_share_pct
FROM fantasy.users u
JOIN fantasy.race r ON r.race_id = u.race_id
GROUP BY r.race_id, r.race
ORDER BY total_users_in_race DESC;


-- 2.1. Статистические показатели по полю amount
SELECT
    COUNT(amount) AS total_transactions,
    SUM(amount) AS total_amount_sum,
    MIN(amount) FILTER (WHERE amount > 0) AS min_amount_clean,
    MAX(amount) AS max_amount,
    AVG(amount) FILTER (WHERE amount > 0)::NUMERIC(10, 2) AS avg_amount_clean,
    PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY amount)::NUMERIC(10, 2) AS median_amount,
    STDDEV(amount)::NUMERIC(10, 2) AS stand_dev_amount
FROM fantasy.events;


-- 2.2. Аномальные нулевые покупки
SELECT
    COUNT(transaction_id) FILTER (WHERE amount = 0) AS total_amount_zero,
    ROUND(COUNT(transaction_id) FILTER (WHERE amount = 0)::NUMERIC / COUNT(transaction_id)::NUMERIC * 100.0, 2) AS zero_from_total_amount
FROM fantasy.events;

-- 2.3. Популярные эпические предметы
SELECT
    i.game_items  AS "Название предмета",
    COUNT(e.transaction_id) AS total_items_sold,
    ROUND(COUNT(e.transaction_id)::NUMERIC / (SELECT COUNT(*) FROM fantasy.events WHERE amount > 0)::NUMERIC * 100.0, 2) AS popular_items_pct,
    ROUND(
        COUNT(DISTINCT e.id)::NUMERIC / 
        (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0)::NUMERIC * 100.0, 2
    ) AS buyers_share_pct
FROM fantasy.events e
JOIN fantasy.items i ON i.item_code = e.item_code
WHERE e.amount > 0 OR e.amount IS NULL
GROUP BY i.game_items 
ORDER BY total_items_sold DESC;
-- Часть 2. Решение Ad-hoc задач
-- Задача 2. Зависимость активности игроков от расы персонажа
WITH info_users_race AS (
	SELECT
		u.race_id,
		COUNT(DISTINCT u.id) AS total_registration 
	FROM fantasy.users u 
	GROUP BY u.race_id 
),
info_users_race_transaction AS (
	SELECT 
		u.race_id,
		r.race,
		COUNT(DISTINCT e.id) AS uniqe_users,
		COUNT(e.transaction_id) AS total_transaction,
		SUM(e.amount) AS total_amount,
		COUNT(DISTINCT u.id) FILTER(WHERE u.payer = 1) AS users_payer
	FROM fantasy.events e
	JOIN fantasy.users u  ON e.id = u.id 
	JOIN fantasy.race r ON r.race_id = u.race_id 
	WHERE e.amount > 0
	GROUP BY u.race_id, r.race 
)
SELECT
	r.race AS "Название расы",
	iur.total_registration AS "Количесвто зарегестрированных игроков",
	ROUND(iusrt.uniqe_users / iur.total_registration::NUMERIC * 100.0, 2) AS "2. Доля покупателей",
	ROUND(iusrt.users_payer / iur.total_registration::NUMERIC * 100.0, 2) AS "3. Доля платящих",
	ROUND(iusrt.total_transaction / iusrt.uniqe_users::NUMERIC, 2) AS "4. Среднее кол-во покупок",
	ROUND(iusrt.total_amount::numeric / iusrt.total_transaction::NUMERIC, 2) AS "5. Средняя стоимость",
	ROUND(iusrt.total_amount::numeric / iusrt.uniqe_users::NUMERIC, 2) AS "6. Средняя сумма покупок"
FROM fantasy.race r
LEFT JOIN info_users_race_transaction iusrt ON iusrt.race_id = r.race_id 
LEFT JOIN info_users_race iur ON iur.race_id = r.race_id 
ORDER BY "6. Средняя сумма покупок" DESC