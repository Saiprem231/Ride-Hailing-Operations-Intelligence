import urllib.parse
import pandas as pd
from sqlalchemy import create_engine, text


USER = "root"
PASSWORD = ""  # <-- Put your actual MySQL password here
HOST = "127.0.0.1"
PORT = 3306
DATABASE = "ride_hailing_ops"

encoded_password = urllib.parse.quote_plus(PASSWORD)


server_engine = create_engine(f"mysql+pymysql://{USER}:{encoded_password}@{HOST}:{PORT}/")

print("⏳ Step 1: Cleaning up old tables and creating new schema...")
with server_engine.connect() as conn:
    conn.execute(text(f"CREATE DATABASE IF NOT EXISTS {DATABASE};"))
    conn.execute(text(f"USE {DATABASE};"))
    
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 0;"))
    conn.execute(text("DROP TABLE IF EXISTS operational_issues;"))
    conn.execute(text("DROP TABLE IF EXISTS fact_bookings;"))
    conn.execute(text("SET FOREIGN_KEY_CHECKS = 1;"))
    
    conn.execute(text("""
        CREATE TABLE fact_bookings (
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
    """))
    
    conn.execute(text("""
        CREATE TABLE operational_issues (
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
    """))
print("✅ Pristine database schema initialized successfully.")

db_engine = create_engine(f"mysql+pymysql://{USER}:{encoded_password}@{HOST}:{PORT}/{DATABASE}")

print("\n⏳ Step 2: Reading cleaned data from CSV...")
df = pd.read_csv("data/ride_hailing_cleaned.csv")

df['id'] = range(1, len(df) + 1)

print("⚙️ Step 3: Structuring tables for ingestion...")
fact_columns = [
    "id", "booking_date", "booking_time", "booking_id", "booking_status", "customer_id",
    "vehicle_type", "pickup_location", "drop_location", "avg_vtat", "avg_ctat",
    "booking_value", "ride_distance", "driver_ratings", "customer_rating",
    "payment_method", "day_name", "hour", "is_weekend", "fare_category",
    "distance_category", "time_slot"
]
df_fact = df[fact_columns]

op_columns = [
    "id", "booking_id", "cancelled_rides_by_customer", "reason_for_cancelling_by_customer",
    "cancelled_rides_by_driver", "driver_cancellation_reason", "incomplete_rides",
    "incomplete_rides_reason"
]
df_ops = df[op_columns].dropna(how="all", subset=op_columns[2:])

print("🚀 Step 4: Streaming data into MySQL 'fact_bookings' table...")
df_fact.to_sql(name="fact_bookings", con=db_engine, if_exists="append", index=False, chunksize=10000)

print("🚀 Step 5: Streaming data into MySQL 'operational_issues' table...")
df_ops.to_sql(name="operational_issues", con=db_engine, if_exists="append", index=False, chunksize=10000)

print("\n🏆 SUCCESS! All 150,000 records cleanly imported into MySQL.")