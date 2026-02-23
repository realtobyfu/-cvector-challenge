"""
Plant Monitoring System — FastAPI Backend

Endpoints:
  GET  /api/facilities                  — List all facilities
  GET  /api/facilities/{id}             — Facility detail with assets
  GET  /api/facilities/{id}/dashboard   — Dashboard summary (aggregated metrics)
  GET  /api/assets/{id}                 — Asset detail with latest readings
  GET  /api/readings                    — Sensor readings with filtering
  GET  /api/health                      — Health check

Background:
  A background task injects new sensor readings every 30 seconds so the
  dashboard always has fresh data streaming in without needing an external
  data generator process.
"""

import asyncio
import math
import random
from contextlib import asynccontextmanager
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import distinct, func
from sqlalchemy.orm import Session

from database import SessionLocal, get_db
from init_db import METRIC_PROFILES, create_tables, seed_data
from models import Asset, Facility, SensorReading
from schemas import (
    AssetDetail,
    AssetStatus,
    DashboardSummary,
    FacilityBrief,
    FacilityDetail,
    MetricSummary,
    SensorReadingOut,
)

# ---------------------------------------------------------------------------
# Background data generator
# ---------------------------------------------------------------------------
_generator_running = False


async def _generate_live_readings():
    """
    Background coroutine that inserts fresh sensor readings every 30 seconds.
    This satisfies the requirement for dynamically generated sample data and
    ensures the dashboard always has new data to display.
    """
    global _generator_running
    _generator_running = True

    while _generator_running:
        await asyncio.sleep(30)
        db = SessionLocal()
        try:
            assets = db.query(Asset).all()
            now = datetime.utcnow()
            hours = now.hour + now.minute / 60  # time-of-day for drift

            readings = []
            for asset in assets:
                metrics = METRIC_PROFILES.get(asset.asset_type, [])
                for metric_name, unit, base, noise in metrics:
                    drift = math.sin(2 * math.pi * hours / 24) * noise * 0.4
                    jitter = random.gauss(0, noise * 0.3)
                    value = round(base + drift + jitter, 2)
                    readings.append(
                        SensorReading(
                            asset_id=asset.id,
                            metric_name=metric_name,
                            value=value,
                            unit=unit,
                            timestamp=now,
                        )
                    )
            db.bulk_save_objects(readings)
            db.commit()
        except Exception as e:
            print(f"[data-gen] Error: {e}")
            db.rollback()
        finally:
            db.close()


# ---------------------------------------------------------------------------
# Application lifespan
# ---------------------------------------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup: create tables, seed data, launch background generator."""
    create_tables()
    seed_data()

    task = asyncio.create_task(_generate_live_readings())
    yield

    global _generator_running
    _generator_running = False
    task.cancel()


# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
app = FastAPI(
    title="CVector Plant Monitor",
    description="REST API for industrial facility monitoring",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------
@app.get("/api/health")
def health_check():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat()}


# ---------------------------------------------------------------------------
# Facilities
# ---------------------------------------------------------------------------
@app.get("/api/facilities", response_model=list[FacilityBrief])
def list_facilities(db: Session = Depends(get_db)):
    return db.query(Facility).all()


@app.get("/api/facilities/{facility_id}", response_model=FacilityDetail)
def get_facility(facility_id: int, db: Session = Depends(get_db)):
    facility = db.query(Facility).filter(Facility.id == facility_id).first()
    if not facility:
        raise HTTPException(status_code=404, detail="Facility not found")
    return facility


# ---------------------------------------------------------------------------
# Dashboard summary
# ---------------------------------------------------------------------------
@app.get("/api/facilities/{facility_id}/dashboard", response_model=DashboardSummary)
def get_dashboard(facility_id: int, db: Session = Depends(get_db)):
    """
    Returns aggregated plant status:
    - Latest value per metric per asset, then aggregated across the facility
    - Status counts (operational / warning / critical / offline)
    - Per-asset status with their most recent readings
    """
    facility = db.query(Facility).filter(Facility.id == facility_id).first()
    if not facility:
        raise HTTPException(status_code=404, detail="Facility not found")

    assets = db.query(Asset).filter(Asset.facility_id == facility_id).all()
    asset_ids = [a.id for a in assets]

    if not asset_ids:
        return DashboardSummary(
            facility=facility,
            metric_summaries=[],
            asset_statuses=[],
            total_assets=0,
            assets_operational=0,
            assets_warning=0,
            assets_critical=0,
            assets_offline=0,
            last_updated=datetime.utcnow(),
        )

    # --- Get latest reading per (asset, metric) using a subquery ---
    latest_subq = (
        db.query(
            SensorReading.asset_id,
            SensorReading.metric_name,
            func.max(SensorReading.timestamp).label("max_ts"),
        )
        .filter(SensorReading.asset_id.in_(asset_ids))
        .group_by(SensorReading.asset_id, SensorReading.metric_name)
        .subquery()
    )

    latest_readings = (
        db.query(SensorReading)
        .join(
            latest_subq,
            (SensorReading.asset_id == latest_subq.c.asset_id)
            & (SensorReading.metric_name == latest_subq.c.metric_name)
            & (SensorReading.timestamp == latest_subq.c.max_ts),
        )
        .all()
    )

    # --- Aggregate by metric ---
    metric_buckets: dict[str, list[SensorReading]] = {}
    for r in latest_readings:
        metric_buckets.setdefault(r.metric_name, []).append(r)

    metric_summaries = []
    for metric_name, readings in sorted(metric_buckets.items()):
        values = [r.value for r in readings]
        metric_summaries.append(
            MetricSummary(
                metric_name=metric_name,
                unit=readings[0].unit,
                total_value=round(sum(values), 2),
                avg_value=round(sum(values) / len(values), 2),
                min_value=round(min(values), 2),
                max_value=round(max(values), 2),
                asset_count=len(values),
            )
        )

    # --- Per-asset status ---
    readings_by_asset: dict[int, list] = {}
    for r in latest_readings:
        readings_by_asset.setdefault(r.asset_id, []).append(r)

    asset_statuses = []
    for asset in assets:
        asset_statuses.append(
            AssetStatus(
                asset_id=asset.id,
                asset_name=asset.name,
                asset_type=asset.asset_type,
                status=asset.status,
                latest_readings=readings_by_asset.get(asset.id, []),
            )
        )

    # --- Status counts ---
    status_counts = {"operational": 0, "warning": 0, "critical": 0, "offline": 0}
    for a in assets:
        status_counts[a.status] = status_counts.get(a.status, 0) + 1

    return DashboardSummary(
        facility=facility,
        metric_summaries=metric_summaries,
        asset_statuses=asset_statuses,
        total_assets=len(assets),
        assets_operational=status_counts["operational"],
        assets_warning=status_counts["warning"],
        assets_critical=status_counts["critical"],
        assets_offline=status_counts["offline"],
        last_updated=datetime.utcnow(),
    )


# ---------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------
@app.get("/api/assets/{asset_id}", response_model=AssetDetail)
def get_asset(asset_id: int, db: Session = Depends(get_db)):
    asset = db.query(Asset).filter(Asset.id == asset_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Asset not found")

    # Fetch latest reading per metric for this asset
    latest_subq = (
        db.query(
            SensorReading.metric_name,
            func.max(SensorReading.timestamp).label("max_ts"),
        )
        .filter(SensorReading.asset_id == asset_id)
        .group_by(SensorReading.metric_name)
        .subquery()
    )

    latest_readings = (
        db.query(SensorReading)
        .join(
            latest_subq,
            (SensorReading.metric_name == latest_subq.c.metric_name)
            & (SensorReading.timestamp == latest_subq.c.max_ts),
        )
        .filter(SensorReading.asset_id == asset_id)
        .all()
    )

    return AssetDetail(
        id=asset.id,
        name=asset.name,
        asset_type=asset.asset_type,
        status=asset.status,
        facility_id=asset.facility_id,
        created_at=asset.created_at,
        latest_readings=latest_readings,
    )


# ---------------------------------------------------------------------------
# Sensor readings with filtering
# ---------------------------------------------------------------------------
@app.get("/api/readings", response_model=list[SensorReadingOut])
def get_readings(
    facility_id: Optional[int] = Query(None, description="Filter by facility"),
    asset_id: Optional[int] = Query(None, description="Filter by asset"),
    metric_name: Optional[str] = Query(None, description="Filter by metric name"),
    start_time: Optional[datetime] = Query(None, description="Start of time range (ISO 8601)"),
    end_time: Optional[datetime] = Query(None, description="End of time range (ISO 8601)"),
    limit: int = Query(500, ge=1, le=5000, description="Max results"),
    db: Session = Depends(get_db),
):
    """
    Query sensor readings with flexible filtering.
    All filters are optional and combinable.
    """
    query = db.query(SensorReading)

    if facility_id is not None:
        asset_ids = [
            a.id for a in db.query(Asset.id).filter(Asset.facility_id == facility_id).all()
        ]
        query = query.filter(SensorReading.asset_id.in_(asset_ids))

    if asset_id is not None:
        query = query.filter(SensorReading.asset_id == asset_id)

    if metric_name is not None:
        query = query.filter(SensorReading.metric_name == metric_name)

    if start_time is not None:
        query = query.filter(SensorReading.timestamp >= start_time)

    if end_time is not None:
        query = query.filter(SensorReading.timestamp <= end_time)

    return query.order_by(SensorReading.timestamp.desc()).limit(limit).all()


# ---------------------------------------------------------------------------
# Available metrics (convenience endpoint for the frontend)
# ---------------------------------------------------------------------------
@app.get("/api/facilities/{facility_id}/metrics")
def get_facility_metrics(facility_id: int, db: Session = Depends(get_db)):
    """Returns distinct metric names available for a facility."""
    asset_ids = [
        a.id for a in db.query(Asset.id).filter(Asset.facility_id == facility_id).all()
    ]
    if not asset_ids:
        return []

    rows = (
        db.query(SensorReading.metric_name, SensorReading.unit)
        .filter(SensorReading.asset_id.in_(asset_ids))
        .distinct()
        .all()
    )
    return [{"metric_name": r[0], "unit": r[1]} for r in rows]
