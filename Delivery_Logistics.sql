CREATE DATABASE indian_logistics_projects;

USE indian_logistics_projects;

SHOW TABLES;

USE indian_logistics_project;

SELECT COUNT(*) AS total_records FROM delivery_logistics;
DESCRIBE delivery_logistics;

-- Data Exploration & Quality Check
-- 1. Check for duplicate delivery IDs
SELECT 
    delivery_id, 
    COUNT(*) AS duplicate_count
FROM delivery_logistics
GROUP BY delivery_id
HAVING COUNT(*) > 1;

-- 2. High-level KPI summary across all 25,000 deliveries
SELECT 
    COUNT(*) AS total_deliveries,
    COUNT(DISTINCT delivery_partner) AS total_partners,
    ROUND(AVG(distance_km), 2) AS avg_distance_km,
    ROUND(AVG(package_weight_kg), 2) AS avg_weight_kg,
    ROUND(AVG(delivery_cost), 2) AS avg_cost_inr,
    ROUND(AVG(delivery_rating), 2) AS avg_customer_rating
FROM delivery_logistics;


-- Partner On-Time Performance & Delay Rate
# Which delivery partner delivers the most reliably, and which partner has the highest delay rate?
SELECT 
    delivery_partner,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN 'delayed' = 'Yes' THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(
        SUM(CASE WHEN 'delayed' = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS delay_rate_pct,
    ROUND(AVG(delivery_time_hours), 2) AS avg_actual_time_hrs,
    ROUND(AVG(expected_time_hours), 2) AS avg_expected_time_hrs,
    ROUND(AVG(delivery_rating), 2) AS avg_rating
FROM delivery_logistics
GROUP BY delivery_partner
ORDER BY delay_rate_pct ASC;


-- Cost Efficiency by Vehicle Type & Delivery Mode
##  Which vehicle types and delivery modes offer the lowest shipping cost per kilometer?
SELECT 
    delivery_mode,
    vehicle_type,
    COUNT(*) AS total_shipments,
    ROUND(AVG(distance_km), 2) AS avg_distance_km,
    ROUND(AVG(delivery_cost), 2) AS avg_cost_inr,
    ROUND(SUM(delivery_cost) / NULLIF(SUM(distance_km), 0), 2) AS cost_per_km_inr
FROM delivery_logistics
GROUP BY delivery_mode, vehicle_type
HAVING COUNT(*) >= 50
ORDER BY delivery_mode, cost_per_km_inr ASC;


-- Weather & Regional Bottleneck Analysis
## How severely do weather conditions (Rainy, Foggy, Stormy) increase delivery delays across regions?
SELECT 
    region,
    weather_condition,
    COUNT(*) AS total_deliveries,
    ROUND(
        SUM(CASE WHEN 'delayed' = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
        2
    ) AS delay_rate_pct,
    ROUND(AVG(delivery_time_hours - expected_time_hours), 2) AS avg_delay_variance_hrs
FROM delivery_logistics
GROUP BY region, weather_condition
ORDER BY region, delay_rate_pct DESC;


-- Impact of Delays & Delivery Status on Customer Ratings
## How much does a delayed delivery or failed status hurt customer satisfaction ratings?
SELECT 
    delivery_status,
    'delayed',
    COUNT(*) AS shipment_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS pct_of_total,
    ROUND(AVG(delivery_rating), 2) AS avg_customer_rating
FROM delivery_logistics
GROUP BY delivery_status, 'delayed'
ORDER BY avg_customer_rating DESC;


-- Ranking Top Partners per Region (Advanced CTE + Window Function)
## Who are the top 2 best-performing delivery partners in each Indian region based on lowest delay rate?
WITH PartnerRegionalStats AS (
    SELECT 
        region,
        delivery_partner,
        COUNT(*) AS total_orders,
        ROUND(
            SUM(CASE WHEN 'delayed' = 'Yes' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 
            2
        ) AS delay_rate_pct,
        ROUND(AVG(delivery_rating), 2) AS avg_rating
    FROM delivery_logistics
    GROUP BY region, delivery_partner
),
RankedPartners AS (
    SELECT 
        *,
        DENSE_RANK() OVER (
            PARTITION BY region 
            ORDER BY delay_rate_pct ASC, avg_rating DESC
        ) AS regional_rank
    FROM PartnerRegionalStats
)
SELECT 
    region,
    regional_rank,
    delivery_partner,
    total_orders,
    delay_rate_pct,
    avg_rating
FROM RankedPartners
WHERE regional_rank <= 2
ORDER BY region, regional_rank;
