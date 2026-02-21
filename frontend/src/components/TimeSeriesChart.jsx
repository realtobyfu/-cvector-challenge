import React, { useState, useEffect, useCallback, useMemo } from "react";
import { Select, Spin, Empty } from "antd";
import {
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  Area,
  AreaChart,
} from "recharts";
import { fetchReadings } from "../api";

/**
 * Terminal Light chart line styles:
 * - Primary (1st): green, solid
 * - Secondary (2nd): amber, dashed
 * - Tertiary (3rd): blue, solid
 * - Fallback: neutral, solid
 */
const CHART_LINES = [
  { color: "#1a7a4f", dashed: false },
  { color: "#b06e14", dashed: true },
  { color: "#3a6ba5", dashed: false },
  { color: "#908a82", dashed: false },
  { color: "#5c5752", dashed: false },
];

const TIME_RANGES = [
  { label: "1H", value: 1 },
  { label: "2H", value: 2 },
  { label: "6H", value: 6 },
  { label: "12H", value: 12 },
  { label: "24H", value: 24 },
];

function formatMetricName(name) {
  return name.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

/** Custom end-dot: only renders on the very last data point */
function EndDot({ cx, cy, index, dataLength, stroke, fill, dashed }) {
  if (index !== dataLength - 1) return null;
  if (dashed) {
    return (
      <circle cx={cx} cy={cy} r={3.5} fill="none" stroke={stroke} strokeWidth={2} />
    );
  }
  return <circle cx={cx} cy={cy} r={3.5} fill={fill} />;
}

/** Light-themed tooltip */
function ChartTooltip({ active, payload, label }) {
  if (!active || !payload || payload.length === 0) return null;

  return (
    <div className="chart-tooltip">
      <div className="chart-tooltip-time">{label}</div>
      {payload.map((p, i) => (
        <div key={i} className="chart-tooltip-row">
          <span
            className="chart-tooltip-dot"
            style={{ background: p.color }}
          />
          <span className="chart-tooltip-name">{p.name}</span>
          <span className="chart-tooltip-val">
            {typeof p.value === "number" ? p.value.toFixed(1) : p.value}
          </span>
        </div>
      ))}
    </div>
  );
}

export default function TimeSeriesChart({ facilityId, metrics, assets }) {
  const [selectedMetric, setSelectedMetric] = useState(null);
  const [selectedAssets, setSelectedAssets] = useState([]);
  const [timeRange, setTimeRange] = useState(2);
  const [chartData, setChartData] = useState([]);
  const [loading, setLoading] = useState(false);

  // Auto-select first metric
  useEffect(() => {
    if (metrics && metrics.length > 0 && !selectedMetric) {
      const preferred = metrics.find(
        (m) => m.metric_name === "power_output" || m.metric_name === "power_consumption"
      );
      setSelectedMetric(preferred ? preferred.metric_name : metrics[0].metric_name);
    }
  }, [metrics, selectedMetric]);

  // Auto-select first few assets
  useEffect(() => {
    if (assets && assets.length > 0 && selectedAssets.length === 0) {
      const relevant = assets
        .filter((a) =>
          a.latest_readings.some((r) => r.metric_name === selectedMetric)
        )
        .slice(0, 4)
        .map((a) => a.asset_id);
      if (relevant.length > 0) setSelectedAssets(relevant);
    }
  }, [assets, selectedMetric]); // eslint-disable-line

  // Fetch readings when filters change
  useEffect(() => {
    if (!facilityId || !selectedMetric || selectedAssets.length === 0) return;

    let cancelled = false;
    setLoading(true);

    const now = new Date();
    const start = new Date(now.getTime() - timeRange * 60 * 60 * 1000);

    Promise.all(
      selectedAssets.map((assetId) =>
        fetchReadings({
          asset_id: assetId,
          metric_name: selectedMetric,
          start_time: start.toISOString(),
          end_time: now.toISOString(),
          limit: 2000,
        })
      )
    ).then((results) => {
      if (cancelled) return;

      const timeMap = {};
      results.forEach((readings, idx) => {
        const assetId = selectedAssets[idx];
        const assetName =
          assets.find((a) => a.asset_id === assetId)?.asset_name || `Asset ${assetId}`;
        readings.forEach((r) => {
          const ts = new Date(r.timestamp);
          const key = new Date(
            Math.round(ts.getTime() / 60000) * 60000
          ).toISOString();
          if (!timeMap[key]) timeMap[key] = { timestamp: key };
          timeMap[key][assetName] = r.value;
        });
      });

      const sorted = Object.values(timeMap).sort(
        (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
      );
      sorted.forEach((point) => {
        const d = new Date(point.timestamp);
        point.time = d.toLocaleTimeString([], {
          hour: "2-digit",
          minute: "2-digit",
        });
      });

      setChartData(sorted);
      setLoading(false);
    });

    return () => { cancelled = true; };
  }, [facilityId, selectedMetric, selectedAssets, timeRange, assets]);

  // Refresh chart data periodically (every 30 seconds)
  useEffect(() => {
    if (!facilityId || !selectedMetric || selectedAssets.length === 0) return;

    const interval = setInterval(() => {
      const now = new Date();
      const start = new Date(now.getTime() - timeRange * 60 * 60 * 1000);

      Promise.all(
        selectedAssets.map((assetId) =>
          fetchReadings({
            asset_id: assetId,
            metric_name: selectedMetric,
            start_time: start.toISOString(),
            end_time: now.toISOString(),
            limit: 2000,
          })
        )
      ).then((results) => {
        const timeMap = {};
        results.forEach((readings, idx) => {
          const assetId = selectedAssets[idx];
          const assetName =
            assets.find((a) => a.asset_id === assetId)?.asset_name || `Asset ${assetId}`;
          readings.forEach((r) => {
            const ts = new Date(r.timestamp);
            const key = new Date(
              Math.round(ts.getTime() / 60000) * 60000
            ).toISOString();
            if (!timeMap[key]) timeMap[key] = { timestamp: key };
            timeMap[key][assetName] = r.value;
          });
        });
        const sorted = Object.values(timeMap).sort(
          (a, b) => new Date(a.timestamp) - new Date(b.timestamp)
        );
        sorted.forEach((point) => {
          const d = new Date(point.timestamp);
          point.time = d.toLocaleTimeString([], {
            hour: "2-digit",
            minute: "2-digit",
          });
        });
        setChartData(sorted);
      });
    }, 30000);

    return () => clearInterval(interval);
  }, [facilityId, selectedMetric, selectedAssets, timeRange, assets]);

  // Asset names for chart lines
  const assetNames = useMemo(
    () =>
      selectedAssets.map(
        (id) => assets.find((a) => a.asset_id === id)?.asset_name || `Asset ${id}`
      ),
    [selectedAssets, assets]
  );

  // Available assets that report the selected metric
  const availableAssets = useMemo(() => {
    if (!selectedMetric || !assets) return [];
    return assets.filter((a) =>
      a.latest_readings.some((r) => r.metric_name === selectedMetric)
    );
  }, [assets, selectedMetric]);

  const metricUnit = useMemo(() => {
    if (!metrics || !selectedMetric) return "";
    const m = metrics.find((m) => m.metric_name === selectedMetric);
    return m ? m.unit : "";
  }, [metrics, selectedMetric]);

  // Get latest value for each asset (for footer legend)
  const latestValues = useMemo(() => {
    if (chartData.length === 0) return {};
    const last = chartData[chartData.length - 1];
    const vals = {};
    assetNames.forEach((name) => {
      if (last[name] !== undefined) {
        vals[name] = typeof last[name] === "number" ? last[name].toFixed(1) : last[name];
      }
    });
    return vals;
  }, [chartData, assetNames]);

  return (
    <div className="chart-section">
      {/* ── Chart header ── */}
      <div className="chart-top">
        <div className="chart-top-left">
          <span className="ct-label">
            metric: <span className="ct-highlight">{selectedMetric || "—"}</span>
            {metricUnit && <> // {metricUnit}</>}
          </span>
          <Select
            value={selectedMetric}
            onChange={(v) => {
              setSelectedMetric(v);
              setSelectedAssets([]);
            }}
            style={{ width: 180 }}
            size="small"
            className="chart-select"
            options={(metrics || []).map((m) => ({
              value: m.metric_name,
              label: formatMetricName(m.metric_name),
            }))}
            placeholder="Metric"
          />
          <Select
            mode="multiple"
            value={selectedAssets}
            onChange={setSelectedAssets}
            style={{ minWidth: 200, maxWidth: 360 }}
            size="small"
            maxTagCount={2}
            className="chart-select"
            placeholder="Select assets"
            options={availableAssets.map((a) => ({
              value: a.asset_id,
              label: a.asset_name,
            }))}
          />
        </div>
        <div className="time-btns">
          {TIME_RANGES.map((tr) => (
            <button
              key={tr.value}
              className={`t-btn${timeRange === tr.value ? " active" : ""}`}
              onClick={() => setTimeRange(tr.value)}
            >
              {tr.label}
            </button>
          ))}
        </div>
      </div>

      {/* ── Chart body ── */}
      <div className="chart-body">
        {loading ? (
          <div className="chart-placeholder">
            <Spin />
          </div>
        ) : chartData.length === 0 ? (
          <div className="chart-placeholder">
            <Empty description="No data for selected filters" image={Empty.PRESENTED_IMAGE_SIMPLE} />
          </div>
        ) : (
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart data={chartData} margin={{ top: 10, right: 20, left: 10, bottom: 5 }}>
              <defs>
                {assetNames.map((name, i) => {
                  const line = CHART_LINES[i % CHART_LINES.length];
                  if (line.dashed) return null; // no gradient fill for dashed lines
                  return (
                    <linearGradient key={name} id={`grad-${i}`} x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={line.color} stopOpacity={0.08} />
                      <stop offset="100%" stopColor={line.color} stopOpacity={0} />
                    </linearGradient>
                  );
                })}
              </defs>
              <CartesianGrid
                stroke="#f0eeea"
                strokeDasharray="none"
                vertical={false}
              />
              <XAxis
                dataKey="time"
                stroke="#e2dfda"
                tick={{ fill: "#b5afa7", fontSize: 10, fontFamily: "'IBM Plex Mono', monospace", fontWeight: 500 }}
                tickLine={{ stroke: "#e2dfda" }}
                interval="preserveStartEnd"
                minTickGap={60}
              />
              <YAxis
                stroke="#e2dfda"
                tick={{ fill: "#b5afa7", fontSize: 10, fontFamily: "'IBM Plex Mono', monospace", fontWeight: 500 }}
                tickLine={{ stroke: "#e2dfda" }}
                width={55}
              />
              <Tooltip content={<ChartTooltip />} />
              {assetNames.map((name, i) => {
                const line = CHART_LINES[i % CHART_LINES.length];
                return (
                  <Area
                    key={name}
                    type="monotone"
                    dataKey={name}
                    stroke={line.color}
                    strokeWidth={2}
                    strokeDasharray={line.dashed ? "6 4" : undefined}
                    fill={line.dashed ? "none" : `url(#grad-${i})`}
                    dot={(props) => (
                      <EndDot
                        {...props}
                        dataLength={chartData.length}
                        dashed={line.dashed}
                        fill={line.color}
                        stroke={line.color}
                      />
                    )}
                    activeDot={{ r: 4, strokeWidth: 0, fill: line.color }}
                    connectNulls
                  />
                );
              })}
            </AreaChart>
          </ResponsiveContainer>
        )}
      </div>

      {/* ── Chart footer / legend ── */}
      {chartData.length > 0 && assetNames.length > 0 && (
        <div className="chart-footer">
          {assetNames.map((name, i) => {
            const line = CHART_LINES[i % CHART_LINES.length];
            return (
              <div key={name} className="cf-item">
                <div
                  className="cf-line"
                  style={
                    line.dashed
                      ? { background: "none", borderTop: `2px dashed ${line.color}`, height: 0 }
                      : { background: line.color }
                  }
                />
                <span className="cf-name">{name.toLowerCase().replace(/ /g, "_")}</span>
                {latestValues[name] !== undefined && (
                  <span className="cf-val">{latestValues[name]} {metricUnit}</span>
                )}
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
