CREATE DATABASE IF NOT EXISTS ride_hailing_ops;
USE ride_hailing_ops;

CREATE TABLE IF NOT EXISTS fact_bookings (
    id INT PRIMARY KEY,
    booking_date DATE,
    booking_time TIME,
    booking_id VARCHAR(50),
    booking_status VARCHAR(50),
    customer_id VARCHAR(50),
    vehicle_type VARCHAR(30),
    pickup_location VARCHAR(100),
    drop_location VARCHAR(100),
    avg_vtat DECIMAL(5,2),
    avg_ctat DECIMAL(5,2),
    booking_value DECIMAL(10,2),
    ride_distance DECIMAL(8,2),
    driver_ratings DECIMAL(3,2),
    customer_rating DECIMAL(3,2),
    payment_method VARCHAR(30),
    day_name VARCHAR(15),
    hour INT,
    is_weekend BOOLEAN,
    fare_category VARCHAR(20),
    distance_category VARCHAR(20),
    time_slot VARCHAR(20)
);


CREATE TABLE IF NOT EXISTS operational_issues (
    id INT PRIMARY KEY,
    booking_id VARCHAR(50),
    cancelled_rides_by_customer INT,
    reason_for_cancelling_by_customer VARCHAR(255),
    cancelled_rides_by_driver INT,
    driver_cancellation_reason VARCHAR(255),
    incomplete_rides INT,
    incomplete_rides_reason VARCHAR(255),
    FOREIGN KEY (id) REFERENCES fact_bookings(id)
);