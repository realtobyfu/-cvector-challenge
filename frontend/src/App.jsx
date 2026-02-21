import React, { useState, useEffect, useCallback } from "react";
import {
  Layout,
  Select,
  Spin,
  Alert,
} from "antd";

import { fetchFacilities, fetchDashboard, fetchMetrics, fetchReadings } from "./api";
import { usePolling } from "./hooks/usePolling";
import StatusOverview from "./components/StatusOverview";
import MetricCards from "./components/MetricCards";
import TimeSeriesChart from "./components/TimeSeriesChart";
import AssetTable from "./components/AssetTable";

import "./app.css";

const { Header, Content } = Layout;

export default function App() {
  const [facilityId, setFacilityId] = useState(null);
  const [facilities, setFacilities] = useState([]);

  // Load facility list on mount
  useEffect(() => {
    fetchFacilities().then((data) => {
      setFacilities(data);
      if (data.length > 0) setFacilityId(data[0].id);
    });
  }, []);

  // Poll dashboard data every 15 seconds
  const fetchDash = useCallback(
    () => (facilityId ? fetchDashboard(facilityId) : Promise.resolve(null)),
    [facilityId]
  );
  const {
    data: dashboard,
    loading,
    error,
  } = usePolling(fetchDash, 15000, [facilityId]);

  // Poll available metrics
  const fetchMet = useCallback(
    () => (facilityId ? fetchMetrics(facilityId) : Promise.resolve([])),
    [facilityId]
  );
  const { data: metrics } = usePolling(fetchMet, 60000, [facilityId]);

  if (!facilityId) {
    return (
      <Layout className="app-layout">
        <div className="loading-screen">
          <Spin size="large" />
          <span style={{ marginTop: 16, color: "var(--text-3)", fontFamily: "var(--font-mono)", fontSize: 12 }}>
            Loading facilities…
          </span>
        </div>
      </Layout>
    );
  }

  return (
    <Layout className="app-layout">
      {/* ── Header ── */}
      <Header className="app-header">
        <div className="header-left">
          <span className="header-brand">
            <span className="header-brand-prefix">cv</span>::plant_monitor
          </span>
          <span className="header-pipe">|</span>
          <Select
            value={facilityId}
            onChange={setFacilityId}
            className="facility-selector"
            variant="borderless"
            popupMatchSelectWidth={false}
            options={facilities.map((f) => ({
              value: f.id,
              label: f.name,
            }))}
          />
        </div>

        <div className="header-right">
          {dashboard && (
            <span className="header-timestamp">
              {new Date(dashboard.last_updated).toLocaleTimeString("en-US", {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
                hour12: false,
                timeZone: "UTC",
              })}{" "}
              UTC
            </span>
          )}
          <span className="header-live">
            <span className="live-dot" />
            live
          </span>
        </div>
      </Header>

      {/* ── Content ── */}
      <Content className="app-content">
        {error && (
          <Alert
            message="Connection Error"
            description={error}
            type="error"
            showIcon
            style={{ marginBottom: 20 }}
          />
        )}

        {loading && !dashboard ? (
          <div className="loading-screen">
            <Spin size="large" />
          </div>
        ) : dashboard ? (
          <>
            {/* Row 1: Status overview + key metrics */}
            <StatusOverview dashboard={dashboard} />
            <MetricCards summaries={dashboard.metric_summaries} />

            {/* Row 2: Time-series chart */}
            <TimeSeriesChart
              facilityId={facilityId}
              metrics={metrics || []}
              assets={dashboard.asset_statuses || []}
            />

            {/* Row 3: Asset status table */}
            <AssetTable assets={dashboard.asset_statuses} />
          </>
        ) : null}
      </Content>
    </Layout>
  );
}
