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
            <div className="section-gap">
              <div className="section-label"><span className="section-label-prefix">&gt; </span>system status</div>
              <StatusOverview dashboard={dashboard} />
            </div>

            <div className="section-gap">
              <div className="section-label"><span className="section-label-prefix">&gt; </span>facility metrics</div>
              <MetricCards summaries={dashboard.metric_summaries} />
            </div>

            <div className="section-gap">
              <div className="section-label"><span className="section-label-prefix">&gt; </span>time series</div>
              <TimeSeriesChart
                facilityId={facilityId}
                metrics={metrics || []}
                assets={dashboard.asset_statuses || []}
              />
            </div>

            <div>
              <div className="section-label"><span className="section-label-prefix">&gt; </span>asset registry</div>
              <AssetTable assets={dashboard.asset_statuses} />
            </div>

            <div className="page-footer">
              <span>cv::plant_monitor v1.0 // fastapi + react + ant design</span>
              <span>polling: 15s // data gen: 30s</span>
            </div>
          </>
        ) : null}
      </Content>
    </Layout>
  );
}
