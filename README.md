# CVector Plant Monitoring System

A real-time industrial plant monitoring dashboard built with **FastAPI**, **React**, **Ant Design**, and **Recharts**.

---

## Quick Start

### Backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

On first startup, the backend automatically:
1. Creates the SQLite database and all tables
2. Seeds 2 facilities, 14 assets, and ~24 hours of historical sensor data (~100k+ readings)
3. Starts a background task that generates new readings every 30 seconds

### Frontend

```bash
cd frontend
npm install
npm run dev
```

Open **http://localhost:3000**. The Vite dev server proxies `/api` requests to the FastAPI backend.

---

## Architecture

```
┌─────────────────┐       ┌──────────────────┐       ┌────────────┐
│  React SPA      │──────▶│  FastAPI          │──────▶│  SQLite    │
│  Ant Design     │  HTTP │  REST API         │  ORM  │  (SQLAlchemy)
│  Recharts       │◀──────│  Background gen   │◀──────│            │
└─────────────────┘       └──────────────────┘       └────────────┘
     polling @15s              inserts @30s
```

---

## Development Notes & Decisions

### Database Schema

**Three tables**: `facilities` → `assets` → `sensor_readings` (1:N:N)

The key design decision was the composite index on `(asset_id, metric_name, timestamp)` in `sensor_readings`. This is the primary access pattern — the dashboard constantly asks "give me readings for asset X, metric Y, between time A and B." Indexing all three columns together means this query hits the index directly without a table scan.

I chose to store `metric_name` as a free-form string rather than normalizing into a separate `metrics` table. In an industrial context, different asset types report completely different metrics (a turbine reports RPM and vibration; a cooling tower reports flow rate). A normalized approach would require schema changes every time a new sensor type appears. The string approach is more flexible and the composite index keeps queries fast.

`unit` is stored per-reading rather than per-metric-name because in practice, different facilities might measure the same concept in different units (metric vs imperial).

**Data generation**: `init_db.py` seeds 24 hours of readings at 5-minute intervals with realistic patterns — a sinusoidal drift simulates load changes over a day, and Gaussian noise simulates sensor jitter. This gives the time-series charts a realistic waveform shape, not just random noise.

The background data generator in `main.py` continues producing readings every 30 seconds so the dashboard always has fresh data streaming in.

### Backend API

**FastAPI** was chosen because CVector uses it and because it's genuinely the best fit here — Pydantic models give us typed serialization for free, async support for the background generator, and automatic OpenAPI docs at `/docs`.

Endpoints:
- `GET /api/facilities` — list all
- `GET /api/facilities/{id}` — detail with assets
- `GET /api/facilities/{id}/dashboard` — **the main endpoint**: aggregated metrics, status counts, per-asset latest readings. This is one request that gives the frontend everything it needs for the summary view.
- `GET /api/facilities/{id}/metrics` — available metric names (drives the chart's metric selector)
- `GET /api/readings` — flexible filtering by facility, asset, metric, time range. Powers the time-series chart.
- `GET /api/assets/{id}` — single asset detail

The dashboard endpoint uses a subquery pattern to get "latest reading per (asset, metric)" efficiently — a common SQL pattern for "most recent row per group." This avoids the N+1 problem of fetching latest readings one asset at a time.

**CORS** is wide-open (`*`) for development. In production you'd lock this to the frontend's origin.

### Frontend

**React + Ant Design + Recharts** — CVector's stack.

Component hierarchy:
```
App
├── StatusOverview      (operational/warning/critical/offline pill counts)
├── MetricCards         (aggregated numbers: total power, avg temp, etc.)
├── TimeSeriesChart     (area chart with metric/asset/time selectors)
└── AssetTable          (expandable rows showing per-asset readings)
```

**Polling**: A custom `usePolling` hook wraps any async fetch function with a `setInterval`. The dashboard polls every 15 seconds; the chart refreshes every 30 seconds. This satisfies "auto-refresh without page reload" simply and reliably. I chose polling over WebSockets because (a) the data only updates every 30 seconds server-side, so real-time push adds complexity without benefit, and (b) polling is more resilient to connection drops.

**MetricCards display logic**: Additive metrics (power, flow rates) show the **total** across all assets. Ratio metrics (efficiency, purity) show the **average**. This mirrors how a plant operator actually thinks — "what's our total output?" vs "what's our average efficiency?"

**Time-series chart**: Uses Recharts `AreaChart` with gradient fills. Supports selecting any metric, any combination of assets, and 1H/2H/6H/12H/24H time windows. Data from multiple assets is merged on a time axis with per-minute alignment.

**Visual design**: Terminal Light aesthetic — white background, IBM Plex Mono throughout, green (#1a7a4f) as the primary accent. Brutalist structure with hard grid borders and 1px dividers. Status indicators use green/amber/red. The goal was industrial-but-legible — like a terminal interface, not a generic SaaS dashboard.

### What I'd Do Next (if this were production)

1. **PostgreSQL + TimescaleDB** — SQLite is fine for the demo but sensor data at scale needs a time-series database. TimescaleDB's hypertables with automatic partitioning and compression would handle millions of readings per day.

2. **WebSocket push** — Replace polling with server-sent events or WebSocket for truly real-time updates when the data pipeline can support it.

3. **Alerting rules** — Let operators define thresholds (e.g., "alert if any turbine temp exceeds 580°C") with a rules engine that evaluates incoming readings.

4. **Historical comparison** — Overlay "same time last week" on charts so operators can spot deviations from normal patterns.

5. **Asset detail page** — Click an asset to see all its metrics, maintenance history, and anomaly detection results.

6. **Authentication & multi-tenancy** — JWT auth, role-based access (operator vs admin vs viewer), facility-level data isolation.

---

## API Documentation

With the backend running, visit **http://localhost:8000/docs** for the interactive Swagger UI.
