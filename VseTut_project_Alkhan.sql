/* Проект «Разработка витрины и решение ad-hoc задач»
 * Цель проекта: подготовка витрины данных маркетплейса «ВсёТут»
 * и решение четырех ad hoc задач на её основе
 * 
 * Автор: Алхан 
 * Дата: 29.09.2026
*/



-- Часть 1. Разработка витрины данных
-- Напишите ниже запрос для создания витрины данных
 WITH top_regions AS (
	SELECT 
		u.region
	FROM ds_ecom.users u
	JOIN ds_ecom.orders o ON o.buyer_id = u.buyer_id 
	WHERE o.order_status IN ('Доставлено', 'Отменено')
	GROUP BY u.region 
	ORDER BY COUNT(*) DESC
	LIMIT 3
),
orders_payments_info AS (
	SELECT
		op.order_id,
		MIN(CASE WHEN op.payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS is_first_money_transfer,
		MAX(CASE WHEN op.payment_installments > 1 THEN 1 ELSE 0 END) AS is_installment,
		MAX(CASE WHEN op.payment_type = 'промокод' THEN 1 ELSE 0 END) AS is_promo
	FROM ds_ecom.order_payments op
	GROUP BY op.order_id
),
order_cost_info AS (
	SELECT
		ot.order_id,
		SUM(ot.price + ot.delivery_cost) AS total_order_costs
	FROM ds_ecom.order_items ot
	JOIN ds_ecom.orders o ON o.order_id = ot.order_id
	WHERE o.order_status = 'Доставлено'
	GROUP BY ot.order_id
),
order_reviews_agg AS (
	SELECT
		ora.order_id,
		AVG(CASE WHEN ora.review_score BETWEEN 10 AND 50 THEN ora.review_score / 10 ELSE ora.review_score END) AS avg_review_score
	FROM ds_ecom.order_reviews ora
	GROUP BY ora.order_id
),
pre_mart AS (
	SELECT 
		o.order_id,
		u.user_id,
		tr.region,
		o.order_status,
		oci.total_order_costs,
		ora.avg_review_score,
		ori.is_first_money_transfer,
		ori.is_installment,
		ori.is_promo,
		o.order_purchase_ts
	FROM ds_ecom.orders o
	JOIN ds_ecom.users u ON u.buyer_id = o.buyer_id
	JOIN top_regions tr ON tr.region = u.region
	LEFT JOIN orders_payments_info ori ON ori.order_id = o.order_id
	LEFT JOIN order_cost_info oci ON oci.order_id = o.order_id
	LEFT JOIN order_reviews_agg ora ON ora.order_id = o.order_id
	WHERE o.order_status IN ('Доставлено', 'Отменено')
),
user_data_mart AS (
	SELECT
		-- 1. Базовая информация о клиенте и времени его активности: 
		user_id,
		region,
		MIN(order_purchase_ts) AS first_order_ts,
		MAX(order_purchase_ts) AS last_order_ts,
		DATE_TRUNC('day', MAX(order_purchase_ts) - MIN(order_purchase_ts)) AS lifetime,
		-- 2. Информация о заказах клиента: 
		COUNT(order_id) AS total_orders,
		ROUND(AVG(avg_review_score), 2) AS avg_order_rating,
		SUM(CASE WHEN avg_review_score IS NOT NULL THEN 1 ELSE 0 END) AS num_orders_with_rating,
		SUM(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS num_canceled_orders,
		ROUND(COUNT(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)::NUMERIC, 2) AS canceled_orders_ratio,
		-- 3. Информация о платежах: 
		SUM(total_order_costs) AS total_order_costs,
		AVG(total_order_costs) AS avg_order_cost,
		SUM(is_installment) AS num_installment_orders,
		SUM(is_promo) AS num_orders_with_promo,
		-- 4. Вспомогательные бинарные признаки: 
		MAX(is_first_money_transfer) AS used_money_transfer,
		MAX(is_installment) AS used_installments,
		MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
	FROM pre_mart
	GROUP BY user_id, region 
)
SELECT *
FROM user_data_mart;
/* Часть 2. Решение ad hoc задач
 * Для каждой задачи напишите отдельный запрос.
 * После каждой задачи оставьте краткий комментарий с выводами по полученным результатам.
*/
/* Задача 1. Сегментация пользователей 
 * Разделите пользователей на группы по количеству совершённых ими заказов.
 * Подсчитайте для каждой группы общее количество пользователей,
 * среднее количество заказов, среднюю стоимость заказа.
 * 
 * Выделите такие сегменты:
 * - 1 заказ — сегмент 1 заказ
 * - от 2 до 5 заказов — сегмент 2-5 заказов
 * - от 6 до 10 заказов — сегмент 6-10 заказов
 * - 11 и более заказов — сегмент 11 и более заказов
*/
-- Напишите ваш запрос тут
 WITH top_regions AS (
	SELECT 
		u.region
	FROM ds_ecom.users u
	JOIN ds_ecom.orders o ON o.buyer_id = u.buyer_id 
	WHERE o.order_status IN ('Доставлено', 'Отменено')
	GROUP BY u.region 
	ORDER BY COUNT(*) DESC
	LIMIT 3
),
orders_payments_info AS (
	SELECT
		op.order_id,
		MIN(CASE WHEN op.payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS is_first_money_transfer,
		MAX(CASE WHEN op.payment_installments > 1 THEN 1 ELSE 0 END) AS is_installment,
		MAX(CASE WHEN op.payment_type = 'промокод' THEN 1 ELSE 0 END) AS is_promo
	FROM ds_ecom.order_payments op
	GROUP BY op.order_id
),
order_cost_info AS (
	SELECT
		ot.order_id,
		SUM(ot.price + ot.delivery_cost) AS total_order_costs
	FROM ds_ecom.order_items ot
	JOIN ds_ecom.orders o ON o.order_id = ot.order_id
	WHERE o.order_status = 'Доставлено'
	GROUP BY ot.order_id
),
order_reviews_agg AS (
	SELECT
		ora.order_id,
		AVG(CASE WHEN ora.review_score BETWEEN 10 AND 50 THEN ora.review_score / 10 ELSE ora.review_score END) AS avg_review_score
	FROM ds_ecom.order_reviews ora
	GROUP BY ora.order_id
),
pre_mart AS (
	SELECT 
		o.order_id,
		u.user_id,
		tr.region,
		o.order_status,
		oci.total_order_costs,
		ora.avg_review_score,
		ori.is_first_money_transfer,
		ori.is_installment,
		ori.is_promo,
		o.order_purchase_ts
	FROM ds_ecom.orders o
	JOIN ds_ecom.users u ON u.buyer_id = o.buyer_id
	JOIN top_regions tr ON tr.region = u.region
	LEFT JOIN orders_payments_info ori ON ori.order_id = o.order_id
	LEFT JOIN order_cost_info oci ON oci.order_id = o.order_id
	LEFT JOIN order_reviews_agg ora ON ora.order_id = o.order_id
	WHERE o.order_status IN ('Доставлено', 'Отменено')
),
user_data_mart AS (
	SELECT
		-- 1. Базовая информация о клиенте и времени его активности: 
		user_id,
		region,
		MIN(order_purchase_ts) AS first_order_ts,
		MAX(order_purchase_ts) AS last_order_ts,
		DATE_TRUNC('day', MAX(order_purchase_ts) - MIN(order_purchase_ts)) AS lifetime,
		-- 2. Информация о заказах клиента: 
		COUNT(order_id) AS total_orders,
		ROUND(AVG(avg_review_score), 2) AS avg_order_rating,
		SUM(CASE WHEN avg_review_score IS NOT NULL THEN 1 ELSE 0 END) AS num_orders_with_rating,
		SUM(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS num_canceled_orders,
		ROUND(COUNT(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)::NUMERIC, 2) AS canceled_orders_ratio,
		-- 3. Информация о платежах: 
		SUM(total_order_costs) AS total_order_costs,
		AVG(total_order_costs) AS avg_order_cost,
		SUM(is_installment) AS num_installment_orders,
		SUM(is_promo) AS num_orders_with_promo,
		-- 4. Вспомогательные бинарные признаки: 
		MAX(is_first_money_transfer) AS used_money_transfer,
		MAX(is_installment) AS used_installments,
		MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
	FROM pre_mart
	GROUP BY user_id, region 
),
user_segments AS (
	SELECT 
		user_id,
		total_order_costs,
		total_orders,
		CASE 
			WHEN total_orders = 1 THEN '1 заказ'
			WHEN total_orders BETWEEN 2 AND 5 THEN '2—5 заказов'
			WHEN total_orders BETWEEN 6 AND 10 THEN '6–10 заказов'
			ELSE '11 и более заказов'
		END AS segment_name
	FROM user_data_mart
)
SELECT 
	segment_name,
	COUNT(user_id),
	AVG(total_orders),
	ROUND(SUM(total_order_costs) / SUM(total_orders), 2)
FROM user_segments
GROUP BY segment_name;
/* Напишите краткий комментарий с выводами по результатам задачи 1.
 * Видно, чем меньше пользователей, тем больше цена среднего заказа, значит пользователи совершают 
 * оплаты за товары с крупной стоимостью, но пользователи с большим количество постоянные клиенты 
*/
/* Задача 2. Ранжирование пользователей 
 * Отсортируйте пользователей, сделавших 3 заказа и более, по убыванию среднего чека покупки.  
 * Выведите 15 пользователей с самым большим средним чеком среди указанной группы.
*/
WITH top_regions AS (
	SELECT 
		u.region
	FROM ds_ecom.users u
	JOIN ds_ecom.orders o ON o.buyer_id = u.buyer_id 
	WHERE o.order_status IN ('Доставлено', 'Отменено')
	GROUP BY u.region 
	ORDER BY COUNT(*) DESC
	LIMIT 3
),
orders_payments_info AS (
	SELECT
		op.order_id,
		MIN(CASE WHEN op.payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS is_first_money_transfer,
		MAX(CASE WHEN op.payment_installments > 1 THEN 1 ELSE 0 END) AS is_installment,
		MAX(CASE WHEN op.payment_type = 'промокод' THEN 1 ELSE 0 END) AS is_promo
	FROM ds_ecom.order_payments op
	GROUP BY op.order_id
),
order_cost_info AS (
	SELECT
		ot.order_id,
		SUM(ot.price + ot.delivery_cost) AS total_order_costs
	FROM ds_ecom.order_items ot
	JOIN ds_ecom.orders o ON o.order_id = ot.order_id
	WHERE o.order_status = 'Доставлено'
	GROUP BY ot.order_id
),
order_reviews_agg AS (
	SELECT
		ora.order_id,
		AVG(CASE WHEN ora.review_score BETWEEN 10 AND 50 THEN ora.review_score / 10 ELSE ora.review_score END) AS avg_review_score
	FROM ds_ecom.order_reviews ora
	GROUP BY ora.order_id
),
pre_mart AS (
	SELECT 
		o.order_id,
		u.user_id,
		tr.region,
		o.order_status,
		oci.total_order_costs,
		ora.avg_review_score,
		ori.is_first_money_transfer,
		ori.is_installment,
		ori.is_promo,
		o.order_purchase_ts
	FROM ds_ecom.orders o
	JOIN ds_ecom.users u ON u.buyer_id = o.buyer_id
	JOIN top_regions tr ON tr.region = u.region
	LEFT JOIN orders_payments_info ori ON ori.order_id = o.order_id
	LEFT JOIN order_cost_info oci ON oci.order_id = o.order_id
	LEFT JOIN order_reviews_agg ora ON ora.order_id = o.order_id
	WHERE o.order_status IN ('Доставлено', 'Отменено')
),
user_data_mart AS (
	SELECT
		-- 1. Базовая информация о клиенте и времени его активности: 
		user_id,
		region,
		MIN(order_purchase_ts) AS first_order_ts,
		MAX(order_purchase_ts) AS last_order_ts,
		DATE_TRUNC('day', MAX(order_purchase_ts) - MIN(order_purchase_ts)) AS lifetime,
		-- 2. Информация о заказах клиента: 
		COUNT(order_id) AS total_orders,
		ROUND(AVG(avg_review_score), 2) AS avg_order_rating,
		SUM(CASE WHEN avg_review_score IS NOT NULL THEN 1 ELSE 0 END) AS num_orders_with_rating,
		SUM(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS num_canceled_orders,
		ROUND(COUNT(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)::NUMERIC, 2) AS canceled_orders_ratio,
		-- 3. Информация о платежах: 
		SUM(total_order_costs) AS total_order_costs,
		AVG(total_order_costs) AS avg_order_cost,
		SUM(is_installment) AS num_installment_orders,
		SUM(is_promo) AS num_orders_with_promo,
		-- 4. Вспомогательные бинарные признаки: 
		MAX(is_first_money_transfer) AS used_money_transfer,
		MAX(is_installment) AS used_installments,
		MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
	FROM pre_mart
	GROUP BY user_id, region 
),
user_top_15 AS (
	SELECT
		user_id,
		region,
		total_orders,
		avg_order_cost
	FROM user_data_mart
)
-- Напишите ваш запрос тут
SELECT 
	*
FROM user_top_15
WHERE total_orders >= 3
ORDER BY avg_order_cost DESC 
LIMIT 15;
/* Напишите краткий комментарий с выводами по результатам задачи 2.
 * Больше всего заказов в Москве - 26, Санкт-Петербурге - 13, Новосибирская область - 9, самый большой чек у Санкт-Петербурга
 * Но в Новосибирской областе есть поля с NULL думаю, что заказы еще не былм доставлены или оплачены
*/

/* Задача 3. Статистика по регионам. 
 * Для каждого региона подсчитайте:
 * - общее число клиентов и заказов;
 * - среднюю стоимость одного заказа;
 * - долю заказов, которые были куплены в рассрочку;
 * - долю заказов, которые были куплены с использованием промокодов;
 * - долю пользователей, совершивших отмену заказа хотя бы один раз.
*/
WITH top_regions AS (
	SELECT 
		u.region
	FROM ds_ecom.users u
	JOIN ds_ecom.orders o ON o.buyer_id = u.buyer_id 
	WHERE o.order_status IN ('Доставлено', 'Отменено')
	GROUP BY u.region 
	ORDER BY COUNT(*) DESC
	LIMIT 3
),
orders_payments_info AS (
	SELECT
		op.order_id,
		MIN(CASE WHEN op.payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS is_first_money_transfer,
		MAX(CASE WHEN op.payment_installments > 1 THEN 1 ELSE 0 END) AS is_installment,
		MAX(CASE WHEN op.payment_type = 'промокод' THEN 1 ELSE 0 END) AS is_promo
	FROM ds_ecom.order_payments op
	GROUP BY op.order_id
),
order_cost_info AS (
	SELECT
		ot.order_id,
		SUM(ot.price + ot.delivery_cost) AS total_order_costs
	FROM ds_ecom.order_items ot
	JOIN ds_ecom.orders o ON o.order_id = ot.order_id
	WHERE o.order_status = 'Доставлено'
	GROUP BY ot.order_id
),
order_reviews_agg AS (
	SELECT
		ora.order_id,
		AVG(CASE WHEN ora.review_score BETWEEN 10 AND 50 THEN ora.review_score / 10 ELSE ora.review_score END) AS avg_review_score
	FROM ds_ecom.order_reviews ora
	GROUP BY ora.order_id
),
pre_mart AS (
	SELECT 
		o.order_id,
		u.user_id,
		tr.region,
		o.order_status,
		oci.total_order_costs,
		ora.avg_review_score,
		ori.is_first_money_transfer,
		ori.is_installment,
		ori.is_promo,
		o.order_purchase_ts
	FROM ds_ecom.orders o
	JOIN ds_ecom.users u ON u.buyer_id = o.buyer_id
	JOIN top_regions tr ON tr.region = u.region
	LEFT JOIN orders_payments_info ori ON ori.order_id = o.order_id
	LEFT JOIN order_cost_info oci ON oci.order_id = o.order_id
	LEFT JOIN order_reviews_agg ora ON ora.order_id = o.order_id
	WHERE o.order_status IN ('Доставлено', 'Отменено')
),
user_data_mart AS (
	SELECT
		-- 1. Базовая информация о клиенте и времени его активности: 
		user_id,
		region,
		MIN(order_purchase_ts) AS first_order_ts,
		MAX(order_purchase_ts) AS last_order_ts,
		DATE_TRUNC('day', MAX(order_purchase_ts) - MIN(order_purchase_ts)) AS lifetime,
		-- 2. Информация о заказах клиента: 
		COUNT(order_id) AS total_orders,
		ROUND(AVG(avg_review_score), 2) AS avg_order_rating,
		SUM(CASE WHEN avg_review_score IS NOT NULL THEN 1 ELSE 0 END) AS num_orders_with_rating,
		SUM(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS num_canceled_orders,
		ROUND(COUNT(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)::NUMERIC, 2) AS canceled_orders_ratio,
		-- 3. Информация о платежах: 
		SUM(total_order_costs) AS total_order_costs,
		AVG(total_order_costs) AS avg_order_cost,
		SUM(is_installment) AS num_installment_orders,
		SUM(is_promo) AS num_orders_with_promo,
		-- 4. Вспомогательные бинарные признаки: 
		MAX(is_first_money_transfer) AS used_money_transfer,
		MAX(is_installment) AS used_installments,
		MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
	FROM pre_mart
	GROUP BY user_id, region 
)
SELECT 
	region,
	SUM(total_orders) AS total_orders,
	COUNT(user_id) AS total_users,
	ROUND(SUM(total_order_costs) / SUM(total_orders)::NUMERIC * 100.0, 2) AS avg_costs,
	ROUND(SUM(used_installments) / SUM(total_orders)::NUMERIC * 100.0, 2),
	ROUND(SUM(num_orders_with_promo) / SUM(total_orders)::NUMERIC * 100.0 , 2),
	ROUND(AVG(used_cancel), 2)
FROM user_data_mart
GROUP BY region;
/* Напишите краткий комментарий с выводами по результатам задачи 3.
 * Анализ по ТОП-3 регионам демонстрирует равномерное распределение среднего чека.
*/


/* Задача 4. Активность пользователей по первому месяцу заказа в 2023 году
 * Разбейте пользователей на группы в зависимости от того, в какой месяц 2023 года они совершили первый заказ.
 * Для каждой группы посчитайте:
 * - общее количество клиентов, число заказов и среднюю стоимость одного заказа;
 * - средний рейтинг заказа;
 * - долю пользователей, использующих денежные переводы при оплате;
 * - среднюю продолжительность активности пользователя.
*/
WITH top_regions AS (
	SELECT 
		u.region
	FROM ds_ecom.users u
	JOIN ds_ecom.orders o ON o.buyer_id = u.buyer_id 
	WHERE o.order_status IN ('Доставлено', 'Отменено')
	GROUP BY u.region 
	ORDER BY COUNT(*) DESC
	LIMIT 3
),
orders_payments_info AS (
	SELECT
		op.order_id,
		MIN(CASE WHEN op.payment_type = 'денежный перевод' THEN 1 ELSE 0 END) AS is_first_money_transfer,
		MAX(CASE WHEN op.payment_installments > 1 THEN 1 ELSE 0 END) AS is_installment,
		MAX(CASE WHEN op.payment_type = 'промокод' THEN 1 ELSE 0 END) AS is_promo
	FROM ds_ecom.order_payments op
	GROUP BY op.order_id
),
order_cost_info AS (
	SELECT
		ot.order_id,
		SUM(ot.price + ot.delivery_cost) AS total_order_costs
	FROM ds_ecom.order_items ot
	JOIN ds_ecom.orders o ON o.order_id = ot.order_id
	WHERE o.order_status = 'Доставлено'
	GROUP BY ot.order_id
),
order_reviews_agg AS (
	SELECT
		ora.order_id,
		AVG(CASE WHEN ora.review_score BETWEEN 10 AND 50 THEN ora.review_score / 10 ELSE ora.review_score END) AS avg_review_score
	FROM ds_ecom.order_reviews ora
	GROUP BY ora.order_id
),
pre_mart AS (
	SELECT 
		o.order_id,
		u.user_id,
		tr.region,
		o.order_status,
		oci.total_order_costs,
		ora.avg_review_score,
		ori.is_first_money_transfer,
		ori.is_installment,
		ori.is_promo,
		o.order_purchase_ts
	FROM ds_ecom.orders o
	JOIN ds_ecom.users u ON u.buyer_id = o.buyer_id
	JOIN top_regions tr ON tr.region = u.region
	LEFT JOIN orders_payments_info ori ON ori.order_id = o.order_id
	LEFT JOIN order_cost_info oci ON oci.order_id = o.order_id
	LEFT JOIN order_reviews_agg ora ON ora.order_id = o.order_id
	WHERE o.order_status IN ('Доставлено', 'Отменено')
),
user_data_mart AS (
	SELECT
		-- 1. Базовая информация о клиенте и времени его активности: 
		user_id,
		region,
		MIN(order_purchase_ts) AS first_order_ts,
		MAX(order_purchase_ts) AS last_order_ts,
		DATE_TRUNC('day', MAX(order_purchase_ts) - MIN(order_purchase_ts)) AS lifetime,
		-- 2. Информация о заказах клиента: 
		COUNT(order_id) AS total_orders,
		ROUND(AVG(avg_review_score), 2) AS avg_order_rating,
		SUM(CASE WHEN avg_review_score IS NOT NULL THEN 1 ELSE 0 END) AS num_orders_with_rating,
		SUM(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS num_canceled_orders,
		ROUND(COUNT(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END)::NUMERIC / COUNT(order_id)::NUMERIC, 2) AS canceled_orders_ratio,
		-- 3. Информация о платежах: 
		SUM(total_order_costs) AS total_order_costs,
		AVG(total_order_costs) AS avg_order_cost,
		SUM(is_installment) AS num_installment_orders,
		SUM(is_promo) AS num_orders_with_promo,
		-- 4. Вспомогательные бинарные признаки: 
		MAX(is_first_money_transfer) AS used_money_transfer,
		MAX(is_installment) AS used_installments,
		MAX(CASE WHEN order_status = 'Отменено' THEN 1 ELSE 0 END) AS used_cancel
	FROM pre_mart
	GROUP BY user_id, region 
)
-- Напишите ваш запрос тут
SELECT 
	EXTRACT(MONTH FROM first_order_ts) AS month_buy,
	COUNT(user_id),
	SUM(total_orders),
	AVG(total_order_costs),
	AVG(avg_order_rating),
	ROUND(AVG(used_money_transfer)::NUMERIC * 100.0, 2),
	AVG(lifetime)
FROM user_data_mart
WHERE first_order_ts >= '2023-01-01 00:00:00' AND first_order_ts < '2024-01-01 00:00:00'
GROUP BY month_buy
ORDER BY month_buy ASC

/* Напишите краткий комментарий с выводами по результатам задачи 4.
 * 1) Количество пользователей увеличевось с каждым месяцем.
 * 2) Количество заказов тоже увеличивалось, но это в зависимости от сезона
 * 3) Средняя цена за заказ пркатически первые 8 месяцев почти равны, дальше от 3000 и выше тоже причина сезона
 * 4) Средняя оценка от 4 до 4.3 по пяти бальной шкале, тоже стабильно
 * 5) Использование денежных переведов, тоже используют активно
 * 6) С начало первой покупки, видно, что пользователь начинает промежуток падает между первой и следующем заказом.
