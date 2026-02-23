"""
Database initialization and seed script.

Creates all tables (migration) and populates them with realistic sample data.
Generates 24 hours of historical sensor readings at 5-minute intervals so the
dashboard has meaningful time-series data from the moment it loads.

Run directly:  python init_db.py
Also called by main.py on startup if the DB is empty.
"""

import math
import random
from datetime import datetime, timedelta

from database import Base, SessionLocal, engine
from models import Asset, Facility, SensorReading


def create_tables():
    """Create all tables defined in models.py (idempotent)."""
    Base.metadata.create_all(bind=engine)
    print("✓ Database tables created")


# ---------------------------------------------------------------------------
# Facility & asset definitions
# ---------------------------------------------------------------------------
FACILITIES = [
    {
        "name": "Riverside Power Station",
        "location": "Houston, TX",
        "facility_type": "Power Station",
        "description": "Combined-cycle natural gas power station, 800 MW capacity",
        "assets": [
            {"name": "Gas Turbine A", "asset_type": "Turbine", "status": "operational"},
            {"name": "Gas Turbine B", "asset_type": "Turbine", "status": "operational"},
            {"name": "Steam Turbine", "asset_type": "Turbine", "status": "operational"},
            {"name": "Heat Recovery Boiler", "asset_type": "Boiler", "status": "operational"},
            {"name": "Cooling Tower 1", "asset_type": "Cooling System", "status": "operational"},
            {"name": "Cooling Tower 2", "asset_type": "Cooling System", "status": "warning"},
            {"name": "Main Transformer", "asset_type": "Electrical", "status": "operational"},
            {"name": "Feedwater Pump", "asset_type": "Pump", "status": "operational"},
        ],
    },
    {
        "name": "Northshore Chemical Plant",
        "location": "Baton Rouge, LA",
        "facility_type": "Chemical Plant",
        "description": "Ethylene production facility, 500k tons/year capacity",
        "assets": [
            {"name": "Cracking Furnace 1", "asset_type": "Furnace", "status": "operational"},
            {"name": "Cracking Furnace 2", "asset_type": "Furnace", "status": "operational"},
            {"name": "Distillation Column A", "asset_type": "Column", "status": "operational"},
            {"name": "Compressor Unit", "asset_type": "Compressor", "status": "warning"},
            {"name": "Reactor Vessel", "asset_type": "Reactor", "status": "operational"},
            {"name": "Heat Exchanger Bank", "asset_type": "Heat Exchanger", "status": "operational"},
        ],
    },
]

# ---------------------------------------------------------------------------
# Metric profiles per asset type — (metric_name, unit, base_value, noise_amp)
# noise_amp controls the ± random variation around base_value
# ---------------------------------------------------------------------------
METRIC_PROFILES = {
    "Turbine": [
        ("temperature", "°C", 540, 15),
        ("pressure", "bar", 35, 2),
        ("power_output", "MW", 260, 20),
        ("vibration", "mm/s", 2.5, 0.8),
        ("rpm", "RPM", 3600, 30),
    ],
    "Boiler": [
        ("temperature", "°C", 480, 20),
        ("pressure", "bar", 80, 5),
        ("steam_flow", "tons/hr", 320, 25),
        ("efficiency", "%", 92, 3),
    ],
    "Cooling System": [
        ("temperature", "°C", 28, 4),
        ("flow_rate", "m³/hr", 4500, 300),
        ("power_consumption", "MW", 3.2, 0.5),
    ],
    "Electrical": [
        ("voltage", "kV", 345, 5),
        ("current", "A", 1200, 80),
        ("power_output", "MW", 780, 30),
        ("temperature", "°C", 65, 8),
    ],
    "Pump": [
        ("pressure", "bar", 45, 3),
        ("flow_rate", "m³/hr", 800, 60),
        ("temperature", "°C", 55, 5),
        ("power_consumption", "MW", 2.8, 0.3),
        ("vibration", "mm/s", 1.8, 0.5),
    ],
    "Furnace": [
        ("temperature", "°C", 850, 30),
        ("pressure", "bar", 2.5, 0.3),
        ("fuel_flow", "m³/hr", 1200, 100),
        ("power_consumption", "MW", 15, 2),
        ("efficiency", "%", 88, 4),
    ],
    "Column": [
        ("temperature", "°C", 120, 10),
        ("pressure", "bar", 12, 1),
        ("flow_rate", "m³/hr", 350, 30),
        ("product_purity", "%", 99.2, 0.5),
    ],
    "Compressor": [
        ("pressure", "bar", 28, 3),
        ("temperature", "°C", 95, 8),
        ("power_consumption", "MW", 8.5, 1),
        ("vibration", "mm/s", 3.2, 1),
        ("flow_rate", "m³/hr", 2000, 150),
    ],
    "Reactor": [
        ("temperature", "°C", 280, 15),
        ("pressure", "bar", 45, 3),
        ("flow_rate", "m³/hr", 500, 40),
        ("conversion_rate", "%", 94, 2),
    ],
    "Heat Exchanger": [
        ("temperature", "°C", 180, 12),
        ("pressure", "bar", 15, 1.5),
        ("flow_rate", "m³/hr", 600, 50),
        ("efficiency", "%", 85, 5),
    ],
}


def _generate_value(base: float, noise: float, t: float) -> float:
    """
    Generate a sensor value with:
    - a slow sinusoidal drift (simulates load changes over a day)
    - random noise (simulates real sensor jitter)
    The 't' param is hours elapsed [0..24] which drives the sine wave.
    """
    drift = math.sin(2 * math.pi * t / 24) * noise * 0.4
    jitter = random.gauss(0, noise * 0.3)
    return round(base + drift + jitter, 2)


def seed_data():
    """Populate the database with facilities, assets, and 24h of readings."""
    db = SessionLocal()

    # Skip if data already exists
    if db.query(Facility).count() > 0:
        print("✓ Database already seeded — skipping")
        db.close()
        return

    now = datetime.utcnow()
    start_time = now - timedelta(hours=24)

    all_readings = []

    for fac_def in FACILITIES:
        facility = Facility(
            name=fac_def["name"],
            location=fac_def["location"],
            facility_type=fac_def["facility_type"],
            description=fac_def["description"],
        )
        db.add(facility)
        db.flush()  # get facility.id

        for asset_def in fac_def["assets"]:
            asset = Asset(
                facility_id=facility.id,
                name=asset_def["name"],
                asset_type=asset_def["asset_type"],
                status=asset_def["status"],
            )
            db.add(asset)
            db.flush()  # get asset.id

            metrics = METRIC_PROFILES.get(asset_def["asset_type"], [])

            # Generate readings every 5 minutes for the past 24 hours
            t = start_time
            while t <= now:
                hours_elapsed = (t - start_time).total_seconds() / 3600
                for metric_name, unit, base, noise in metrics:
                    reading = SensorReading(
                        asset_id=asset.id,
                        metric_name=metric_name,
                        value=_generate_value(base, noise, hours_elapsed),
                        unit=unit,
                        timestamp=t,
                    )
                    all_readings.append(reading)
                t += timedelta(minutes=5)

    # Bulk insert readings for performance
    db.bulk_save_objects(all_readings)
    db.commit()

    total_readings = len(all_readings)
    total_assets = sum(len(f["assets"]) for f in FACILITIES)
    print(f"✓ Seeded {len(FACILITIES)} facilities, {total_assets} assets, {total_readings:,} sensor readings")
    db.close()


if __name__ == "__main__":
    create_tables()
    seed_data()
    print("\nDatabase ready!")
