"""
Pydantic schemas for request/response serialization.
Separated from ORM models to keep a clean boundary between
the database layer and the API contract.
"""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


# ---------------------------------------------------------------------------
# Sensor Readings
# ---------------------------------------------------------------------------
class SensorReadingOut(BaseModel):
    id: int
    asset_id: int
    metric_name: str
    value: float
    unit: str
    timestamp: datetime

    class Config:
        from_attributes = True


# ---------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------
class AssetBrief(BaseModel):
    id: int
    name: str
    asset_type: str
    status: str
    created_at: datetime

    class Config:
        from_attributes = True


class AssetDetail(AssetBrief):
    facility_id: int
    latest_readings: list[SensorReadingOut] = []


# ---------------------------------------------------------------------------
# Facilities
# ---------------------------------------------------------------------------
class FacilityBrief(BaseModel):
    id: int
    name: str
    location: str
    facility_type: str
    description: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class FacilityDetail(FacilityBrief):
    assets: list[AssetBrief] = []


# ---------------------------------------------------------------------------
# Dashboard summary
# ---------------------------------------------------------------------------
class MetricSummary(BaseModel):
    """Aggregated value for a single metric across all assets in a facility."""
    metric_name: str
    unit: str
    total_value: float
    avg_value: float
    min_value: float
    max_value: float
    asset_count: int  # how many assets report this metric


class AssetStatus(BaseModel):
    """Current status snapshot for a single asset."""
    asset_id: int
    asset_name: str
    asset_type: str
    status: str
    latest_readings: list[SensorReadingOut] = []


class DashboardSummary(BaseModel):
    """Top-level dashboard payload for a facility."""
    facility: FacilityBrief
    metric_summaries: list[MetricSummary]
    asset_statuses: list[AssetStatus]
    total_assets: int
    assets_operational: int
    assets_warning: int
    assets_critical: int
    assets_offline: int
    last_updated: datetime
