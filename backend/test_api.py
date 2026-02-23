"""
API tests for the Plant Monitoring System.

Uses an in-memory SQLite database so tests are fast, isolated, and don't
touch the real DB. Seeds controlled data for deterministic assertions.
"""

from datetime import datetime, timedelta

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import Base, get_db
from main import app
from models import Asset, Facility, SensorReading

# ---------------------------------------------------------------------------
# Test database setup
# ---------------------------------------------------------------------------
engine = create_engine("sqlite:///:memory:", connect_args={"check_same_thread": False})
TestSession = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

NOW = datetime(2025, 6, 15, 12, 0, 0)
ONE_HOUR_AGO = NOW - timedelta(hours=1)
TWO_HOURS_AGO = NOW - timedelta(hours=2)


@pytest.fixture(autouse=True)
def setup_db():
    """Create tables, seed test data, then drop everything after each test."""
    Base.metadata.create_all(bind=engine)

    db = TestSession()

    # --- Facility ---
    facility = Facility(
        name="Test Plant",
        location="Test City",
        facility_type="Power Station",
        description="A test facility",
    )
    db.add(facility)
    db.flush()

    # --- Assets ---
    turbine = Asset(
        facility_id=facility.id,
        name="Turbine 1",
        asset_type="Turbine",
        status="operational",
    )
    pump = Asset(
        facility_id=facility.id,
        name="Pump 1",
        asset_type="Pump",
        status="warning",
    )
    db.add_all([turbine, pump])
    db.flush()

    # --- Readings with known values ---
    readings = [
        # Turbine temperature readings at different times
        SensorReading(asset_id=turbine.id, metric_name="temperature", value=540.0, unit="°C", timestamp=TWO_HOURS_AGO),
        SensorReading(asset_id=turbine.id, metric_name="temperature", value=545.0, unit="°C", timestamp=ONE_HOUR_AGO),
        SensorReading(asset_id=turbine.id, metric_name="temperature", value=550.0, unit="°C", timestamp=NOW),
        # Turbine power output
        SensorReading(asset_id=turbine.id, metric_name="power_output", value=260.0, unit="MW", timestamp=NOW),
        # Pump temperature
        SensorReading(asset_id=pump.id, metric_name="temperature", value=55.0, unit="°C", timestamp=NOW),
        # Pump flow rate
        SensorReading(asset_id=pump.id, metric_name="flow_rate", value=800.0, unit="m³/hr", timestamp=NOW),
    ]
    db.bulk_save_objects(readings)
    db.commit()
    db.close()

    yield

    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    with TestClient(app) as c:
        yield c


# ---------------------------------------------------------------------------
# GET /api/health
# ---------------------------------------------------------------------------
class TestHealth:
    def test_returns_ok(self, client):
        resp = client.get("/api/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert "timestamp" in data


# ---------------------------------------------------------------------------
# GET /api/facilities
# ---------------------------------------------------------------------------
class TestListFacilities:
    def test_returns_all_facilities(self, client):
        resp = client.get("/api/facilities")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]["name"] == "Test Plant"

    def test_facility_fields(self, client):
        resp = client.get("/api/facilities")
        fac = resp.json()[0]
        assert fac["location"] == "Test City"
        assert fac["facility_type"] == "Power Station"
        assert "id" in fac
        assert "created_at" in fac


# ---------------------------------------------------------------------------
# GET /api/facilities/{id}
# ---------------------------------------------------------------------------
class TestGetFacility:
    def test_returns_facility_with_assets(self, client):
        resp = client.get("/api/facilities/1")
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "Test Plant"
        assert len(data["assets"]) == 2

    def test_404_for_nonexistent(self, client):
        resp = client.get("/api/facilities/999")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# GET /api/facilities/{id}/dashboard
# ---------------------------------------------------------------------------
class TestDashboard:
    def test_returns_status_counts(self, client):
        resp = client.get("/api/facilities/1/dashboard")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_assets"] == 2
        assert data["assets_operational"] == 1
        assert data["assets_warning"] == 1
        assert data["assets_critical"] == 0
        assert data["assets_offline"] == 0

    def test_metric_summaries_present(self, client):
        resp = client.get("/api/facilities/1/dashboard")
        data = resp.json()
        summaries = data["metric_summaries"]
        metric_names = [s["metric_name"] for s in summaries]
        assert "temperature" in metric_names
        assert "power_output" in metric_names
        assert "flow_rate" in metric_names

    def test_temperature_aggregation(self, client):
        """Temperature is reported by both turbine (550) and pump (55). Check aggregation."""
        resp = client.get("/api/facilities/1/dashboard")
        data = resp.json()
        temp_summary = next(s for s in data["metric_summaries"] if s["metric_name"] == "temperature")
        assert temp_summary["total_value"] == 605.0  # 550 + 55
        assert temp_summary["avg_value"] == 302.5    # (550 + 55) / 2
        assert temp_summary["min_value"] == 55.0
        assert temp_summary["max_value"] == 550.0
        assert temp_summary["asset_count"] == 2

    def test_asset_statuses_included(self, client):
        resp = client.get("/api/facilities/1/dashboard")
        data = resp.json()
        statuses = data["asset_statuses"]
        assert len(statuses) == 2
        names = {s["asset_name"] for s in statuses}
        assert names == {"Turbine 1", "Pump 1"}

    def test_404_for_nonexistent(self, client):
        resp = client.get("/api/facilities/999/dashboard")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# GET /api/assets/{id}
# ---------------------------------------------------------------------------
class TestGetAsset:
    def test_returns_asset_with_readings(self, client):
        resp = client.get("/api/assets/1")
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "Turbine 1"
        assert data["status"] == "operational"
        # Should have latest readings (one per metric)
        assert len(data["latest_readings"]) >= 1

    def test_404_for_nonexistent(self, client):
        resp = client.get("/api/assets/999")
        assert resp.status_code == 404


# ---------------------------------------------------------------------------
# GET /api/readings
# ---------------------------------------------------------------------------
class TestReadings:
    def test_returns_readings_ordered_by_time_desc(self, client):
        resp = client.get("/api/readings")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) > 0
        # Check descending timestamp order
        timestamps = [r["timestamp"] for r in data]
        assert timestamps == sorted(timestamps, reverse=True)

    def test_filter_by_asset_id(self, client):
        resp = client.get("/api/readings", params={"asset_id": 1})
        data = resp.json()
        assert all(r["asset_id"] == 1 for r in data)

    def test_filter_by_metric_name(self, client):
        resp = client.get("/api/readings", params={"metric_name": "temperature"})
        data = resp.json()
        assert len(data) > 0
        assert all(r["metric_name"] == "temperature" for r in data)

    def test_filter_by_facility_id(self, client):
        resp = client.get("/api/readings", params={"facility_id": 1})
        data = resp.json()
        assert len(data) == 6  # all readings belong to facility 1

    def test_limit_parameter(self, client):
        resp = client.get("/api/readings", params={"limit": 2})
        data = resp.json()
        assert len(data) == 2

    def test_time_range_filter(self, client):
        """Filter to readings within the last 90 minutes — should exclude the 2hr old reading."""
        ninety_min_ago = (NOW - timedelta(minutes=90)).isoformat()
        resp = client.get("/api/readings", params={
            "start_time": ninety_min_ago,
            "metric_name": "temperature",
        })
        data = resp.json()
        # Should get: turbine@NOW (550), turbine@1hr (545), pump@NOW (55) — NOT turbine@2hr (540)
        values = sorted([r["value"] for r in data])
        assert 540.0 not in values
        assert 545.0 in values


# ---------------------------------------------------------------------------
# GET /api/facilities/{id}/metrics
# ---------------------------------------------------------------------------
class TestFacilityMetrics:
    def test_returns_distinct_metrics(self, client):
        resp = client.get("/api/facilities/1/metrics")
        assert resp.status_code == 200
        data = resp.json()
        metric_names = [m["metric_name"] for m in data]
        assert "temperature" in metric_names
        assert "power_output" in metric_names
        assert "flow_rate" in metric_names

    def test_empty_facility_returns_empty_list(self, client):
        resp = client.get("/api/facilities/999/metrics")
        data = resp.json()
        assert data == []
