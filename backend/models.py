"""
SQLAlchemy ORM models for the plant monitoring system.

Schema design decisions:
- Facilities → Assets → SensorReadings (1:N:N hierarchy)
- sensor_readings indexed on (asset_id, metric_name, timestamp) for fast
  time-range + metric queries, which is the dominant access pattern for dashboards
- metric_name stored as a string (not FK to a metrics table) for flexibility —
  different asset types report different metrics, and we don't want schema changes
  every time a new sensor type is added
- unit stored alongside each reading so the API layer doesn't need a separate
  lookup table for display formatting
"""

from datetime import datetime

from sqlalchemy import (
    Column,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from database import Base


class Facility(Base):
    __tablename__ = "facilities"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    location = Column(String(255), nullable=False)
    facility_type = Column(String(100), nullable=False)  # e.g. "Power Station", "Chemical Plant"
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    assets = relationship("Asset", back_populates="facility", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Facility(id={self.id}, name='{self.name}')>"


class Asset(Base):
    __tablename__ = "assets"

    id = Column(Integer, primary_key=True, index=True)
    facility_id = Column(Integer, ForeignKey("facilities.id"), nullable=False, index=True)
    name = Column(String(255), nullable=False)
    asset_type = Column(String(100), nullable=False)  # e.g. "Turbine", "Boiler", "Pump"
    status = Column(String(50), default="operational")  # operational | warning | critical | offline
    created_at = Column(DateTime, default=datetime.utcnow)

    facility = relationship("Facility", back_populates="assets")
    sensor_readings = relationship("SensorReading", back_populates="asset", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Asset(id={self.id}, name='{self.name}', type='{self.asset_type}')>"


class SensorReading(Base):
    __tablename__ = "sensor_readings"

    id = Column(Integer, primary_key=True, index=True)
    asset_id = Column(Integer, ForeignKey("assets.id"), nullable=False)
    metric_name = Column(String(100), nullable=False)  # e.g. "temperature", "pressure", "power_consumption"
    value = Column(Float, nullable=False)
    unit = Column(String(50), nullable=False)  # e.g. "°C", "bar", "MW", "tons/hr"
    timestamp = Column(DateTime, nullable=False, default=datetime.utcnow)

    asset = relationship("Asset", back_populates="sensor_readings")

    # Composite index for the primary query pattern:
    # "give me readings for asset X, metric Y, between time A and B"
    __table_args__ = (
        Index("ix_readings_asset_metric_time", "asset_id", "metric_name", "timestamp"),
    )

    def __repr__(self):
        return f"<SensorReading(asset={self.asset_id}, metric='{self.metric_name}', value={self.value})>"
