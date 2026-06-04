from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from sqlalchemy import create_engine
import urllib.parse

print("⏳ Step 1: Connecting to MySQL to extract transactional timeline...")

USER = "root"
PASSWORD = ""  # <-- Update with your actual MySQL password
HOST = "127.0.0.1"
PORT = 3306
DATABASE = "ride_hailing_ops"

encoded_password = urllib.parse.quote_plus(PASSWORD)
engine = create_engine(
    f"mysql+pymysql://{USER}:{encoded_password}@{HOST}:{PORT}/{DATABASE}"
)

query = "SELECT booking_date, COUNT(*) as actual_bookings FROM fact_bookings GROUP BY booking_date ORDER BY booking_date;"
daily_demand = pd.read_sql(query, engine)

daily_demand["booking_date"] = pd.to_datetime(daily_demand["booking_date"])
daily_demand = daily_demand.sort_values("booking_date").reset_index(drop=True)

print(
    f"📊 Data extracted successfully. Found {len(daily_demand)} operational days."
)

daily_demand["rolling_7d_avg"] = (
    daily_demand["actual_bookings"].rolling(window=7, min_periods=1).mean()
)

x = np.arange(len(daily_demand))
y = daily_demand["actual_bookings"].values
slope, intercept = np.polyfit(x, y, 1)
daily_demand["trend"] = slope * x + intercept

print("⚙️ Step 2: Running 15-Day Forward Predictive Matrix...")

last_date = daily_demand["booking_date"].max()
future_dates = [last_date + pd.Timedelta(days=i) for i in range(1, 16)]

future_x = np.arange(len(daily_demand), len(daily_demand) + 15)
future_trend = slope * future_x + intercept

recent_seasonality = daily_demand["actual_bookings"].iloc[-7:].values / (
    slope * x[-7:] + intercept
)
future_seasonality = [recent_seasonality[i % 7] for i in range(15)]
forecasted_values = (future_trend * future_seasonality).astype(int)

df_forecast = pd.DataFrame(
    {"booking_date": future_dates, "forecasted_bookings": forecasted_values}
)

print("🎨 Step 3: Generating presentation-grade analytical visuals...")

plt.figure(figsize=(12, 6))
plt.plot(
    daily_demand["booking_date"],
    daily_demand["actual_bookings"],
    label="Actual Historical Volume",
    color="#2c3e50",
    alpha=0.3,
)
plt.plot(
    daily_demand["booking_date"],
    daily_demand["rolling_7d_avg"],
    label="7-Day Moving Average Baseline",
    color="#2980b9",
    linewidth=2,
)
plt.plot(
    df_forecast["booking_date"],
    df_forecast["forecasted_bookings"],
    label="15-Day Forward Operational Forecast",
    color="#27ae60",
    linestyle="--",
    linewidth=2,
    marker="o",
)

plt.title(
    "Ride-Hailing Fleet Matrix: 15-Day Predictive Demand Forecast",
    fontsize=14,
    weight="bold",
    pad=15,
)
plt.xlabel("Operational Timeline", fontsize=11, labelpad=10)
plt.ylabel("Absolute Booking Requests Counts", fontsize=11, labelpad=10)
plt.grid(True, linestyle=":", alpha=0.5)
plt.legend(loc="upper left", frameon=True)
plt.xticks(rotation=15)
plt.tight_layout()

Path("reports").mkdir(exist_ok=True)
Path("data").mkdir(exist_ok=True)

plt.savefig("reports/demand_forecast_chart.png", dpi=300)
df_forecast.to_csv("data/demand_forecast_predictions.csv", index=False)

print("\n🏆 SUCCESS! Forecast data saved to 'data/' and chart saved to 'reports/demand_forecast_chart.png'.")