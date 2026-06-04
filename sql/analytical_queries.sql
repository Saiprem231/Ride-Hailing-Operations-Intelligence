-- ------------------------------------------------------------------------------
-- QUERY 1: Marketplace Supply Stockouts (Revenue Leakage Analysis)
-- Business Value: Identifies specific high-demand locations where the platform 
-- is losing money because a driver was not found. Feeds Page 2 of the Dashboard.
-- ------------------------------------------------------------------------------
SELECT 
    pickup_location,
    COUNT(booking_id) AS missed_requests_count,
    SUM(booking_value) AS lost_gross_revenue_inr,
    ROUND(COUNT(booking_id) * 100.0 / SUM(COUNT(booking_id)) OVER(), 2) AS percentage_of_total_leakage
FROM 
    bookings_data
WHERE 
    booking_status = 'No Driver Found'
GROUP BY 
    pickup_location
ORDER BY 
    missed_requests_count DESC
LIMIT 10;


-- ------------------------------------------------------------------------------
-- QUERY 2: Hourly Demand & Revenue Density Matrix (Temporal Analysis)
-- Business Value: Maps out peak hours of the day alongside successful transaction 
-- metrics. Feeds the Line Chart on Page 3 and the Waterfall Chart on Page 4.
-- ------------------------------------------------------------------------------
SELECT 
    EXTRACT(HOUR FROM booking_time) AS hour_of_day,
    COUNT(booking_id) AS total_ride_requests,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS completed_rides,
    ROUND(
        SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) * 100.0 / COUNT(booking_id), 
        2
    ) AS fulfillment_success_rate_pct,
    SUM(CASE WHEN booking_status = 'Completed' THEN booking_value ELSE 0 END) AS net_realized_revenue_inr
FROM 
    bookings_data
GROUP BY 
    EXTRACT(HOUR FROM booking_time)
ORDER BY 
    hour_of_day ASC;


-- ------------------------------------------------------------------------------
-- QUERY 3: Fleet Performance & Unit Economics Breakdown
-- Business Value: Evaluates which vehicle types generate the highest average fares 
-- and travel lengths, helping management optimize vehicle cohort investments.
-- Feeds Page 4 & 5.
-- ------------------------------------------------------------------------------
SELECT 
    vehicle_type,
    COUNT(booking_id) AS total_bookings,
    SUM(CASE WHEN booking_status = 'Completed' THEN 1 ELSE 0 END) AS successful_trips,
    ROUND(AVG(ride_distance), 2) AS avg_ride_distance_km,
    ROUND(AVG(booking_value), 2) AS avg_fare_per_ride_inr,
    SUM(booking_value) AS aggregated_gross_booking_value_inr
FROM 
    bookings_data
GROUP BY 
    vehicle_type
ORDER BY 
    aggregated_gross_booking_value_inr DESC;


-- ------------------------------------------------------------------------------
-- QUERY 4: Customer vs. Driver Rating Discrepancy Matrix (Quality Control)
-- Business Value: Flags potential churn risks or bad actors in the marketplace 
-- by isolating cohorts where ratings fall below a standard 3.0 threshold.
-- Feeds Page 5.
-- ------------------------------------------------------------------------------
SELECT 
    vehicle_type,
    ROUND(AVG(customer_rating), 2) AS avg_passenger_rating_by_driver,
    ROUND(AVG(driver_rating), 2) AS avg_driver_rating_by_passenger,
    COUNT(CASE WHEN driver_rating <= 2.0 THEN 1 END) AS critical_driver_complaints,
    COUNT(CASE WHEN customer_rating <= 2.0 THEN 1 END) AS critical_customer_complaints
FROM 
    bookings_data
WHERE 
    booking_status = 'Completed'
    AND customer_rating IS NOT NULL 
    AND driver_rating IS NOT NULL
GROUP BY 
    vehicle_type
ORDER BY 
    critical_driver_complaints DESC;

-- ------------------------------------------------------------------------------
-- QUERY 5: Day-over-Day (DoD) Revenue Growth Analytics
-- Business Value: Calculates the daily trend of realized revenue and uses window 
-- functions to compute the exact percentage change compared to the previous day.
-- Demonstrates: LAG() Window Function, CTEs, and handling arithmetic nulls.
-- ------------------------------------------------------------------------------
WITH DailyRevenue AS (
    SELECT 
        booking_date,
        SUM(booking_value) AS daily_net_revenue_inr
    FROM 
        bookings_data
    WHERE 
        booking_status = 'Completed'
    GROUP BY 
        booking_date
)
SELECT 
    booking_date,
    daily_net_revenue_inr,
    LAG(daily_net_revenue_inr, 1) OVER (ORDER BY booking_date) AS previous_day_revenue_inr,
    ROUND(
        (daily_net_revenue_inr - LAG(daily_net_revenue_inr, 1) OVER (ORDER BY booking_date)) * 100.0 / 
        LAG(daily_net_revenue_inr, 1) OVER (ORDER BY booking_date), 
        2
    ) AS day_over_day_growth_pct
FROM 
    DailyRevenue
ORDER BY 
    booking_date ASC;


-- ------------------------------------------------------------------------------
-- QUERY 6: Customer Lifetime Value (LTV) Segmentation & Concentration Matrix
-- Business Value: Applies Pareto Principle analysis to segment passengers into 
-- cohorts (VIP, Regular, Low-Value) based on their cumulative platform spending.
-- Demonstrates: CASE WHEN logic paired with NTILE() or subquery aggregations.
-- ------------------------------------------------------------------------------
WITH CustomerSpending AS (
    SELECT 
        customer_id,
        COUNT(booking_id) AS total_trips,
        SUM(booking_value) AS total_lifetime_spend_inr
    FROM 
        bookings_data
    WHERE 
        booking_status = 'Completed'
    GROUP BY 
        customer_id
)
SELECT 
    CASE 
        WHEN total_lifetime_spend_inr >= 5000 THEN 'Tier 1: VIP High-Value'
        WHEN total_lifetime_spend_inr BETWEEN 1500 AND 4999 THEN 'Tier 2: Core Mid-Value'
        ELSE 'Tier 3: Low Frequency / Casual'
    END AS customer_value_segment,
    COUNT(customer_id) AS unique_passenger_count,
    SUM(total_trips) AS aggregated_trips,
    SUM(total_lifetime_spend_inr) AS aggregated_revenue_inr,
    ROUND(AVG(total_lifetime_spend_inr), 2) AS average_spend_per_customer_inr
FROM 
    CustomerSpending
GROUP BY 
    1
ORDER BY 
    aggregated_revenue_inr DESC;


-- ------------------------------------------------------------------------------
-- QUERY 7: Peak Demand Hour Anomalies (Z-Score/Standard Deviation Method)
-- Business Value: Statistical anomaly detection to pinpoint specific operational 
-- hours where the transaction volume surged significantly above the historic mean.
-- Demonstrates: Windowed Standard Deviation, AVG() OVER(), and statistical filtering.
-- ------------------------------------------------------------------------------
WITH HourlyVolumes AS (
    SELECT 
        booking_date,
        EXTRACT(HOUR FROM booking_time) AS hour_of_day,
        COUNT(booking_id) AS booking_count
    FROM 
        bookings_data
    GROUP BY 
        booking_date, 
        EXTRACT(HOUR FROM booking_time)
),
HourlyStats AS (
    SELECT 
        booking_date,
        hour_of_day,
        booking_count,
        AVG(booking_count) OVER(PARTITION BY hour_of_day) AS historical_average_volume,
        STDDEV(booking_count) OVER(PARTITION BY hour_of_day) AS volume_standard_deviation
    FROM 
        HourlyVolumes
)
SELECT 
    booking_date,
    hour_of_day,
    booking_count,
    ROUND(historical_average_volume, 2) AS avg_volume_for_this_hour,
    ROUND((booking_count - historical_average_volume) / NULLIF(volume_standard_deviation, 0), 2) AS z_score
FROM 
    HourlyStats
WHERE 
    booking_count > (historical_average_volume + (1.5 * volume_standard_deviation))
ORDER BY 
    z_score DESC;


-- ------------------------------------------------------------------------------
-- QUERY 8: Driver Fulfillment Velocity & Speed Ranks
-- Business Value: Ranks pickup locations by their efficiency, showcasing which 
-- areas process rides over maximum average distances with successful completions.
-- Demonstrates: DENSE_RANK() Window Function with complex sorting.
-- ------------------------------------------------------------------------------
SELECT 
    pickup_location,
    COUNT(booking_id) AS fulfilled_rides,
    ROUND(SUM(ride_distance), 2) AS total_distance_covered_km,
    DENSE_RANK() OVER (ORDER BY SUM(ride_distance) DESC) AS efficiency_rank
FROM 
    bookings_data
WHERE 
    booking_status = 'Completed'
GROUP BY 
    pickup_location
ORDER BY 
    efficiency_rank ASC
LIMIT 10;