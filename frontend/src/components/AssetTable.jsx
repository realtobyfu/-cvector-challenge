import React from "react";

/** Map snake_case metric names to full display names */
const METRIC_DISPLAY_NAMES = {
  temperature: "Temperature",
  power_output: "Power Output",
  power_consumption: "Power Consumption",
  pressure: "Pressure",
  flow_rate: "Flow Rate",
  vibration: "Vibration",
  steam_flow: "Steam Flow",
  voltage: "Voltage",
  current: "Current",
  efficiency: "Efficiency",
  rpm: "RPM",
};

function formatMetricName(name) {
  if (METRIC_DISPLAY_NAMES[name]) return METRIC_DISPLAY_NAMES[name];
  return name.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

function formatValue(value) {
  if (typeof value !== "number") return value;
  if (value >= 1000) return value.toLocaleString("en-US", { maximumFractionDigits: 1 });
  return value.toFixed(1);
}

const STATUS_COLORS = {
  operational: "var(--green)",
  warning: "var(--amber)",
  critical: "var(--red)",
  offline: "var(--text-4)",
};

export default function AssetTable({ assets }) {
  if (!assets || assets.length === 0) return null;

  return (
    <div className="asset-table-wrap">
      <table className="asset-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Type</th>
            <th>Status</th>
            <th>Readings</th>
          </tr>
        </thead>
        <tbody>
          {assets.map((asset) => (
            <tr key={asset.asset_id}>
              <td className="a-name">{asset.asset_name}</td>
              <td>
                <span className="a-type">{asset.asset_type}</span>
              </td>
              <td>
                <span
                  className="a-status"
                  style={{ color: STATUS_COLORS[asset.status] || "var(--text-3)" }}
                >
                  <span
                    className="a-dot"
                    style={{ background: STATUS_COLORS[asset.status] || "var(--text-4)" }}
                  />
                  {asset.status.charAt(0).toUpperCase() + asset.status.slice(1)}
                </span>
              </td>
              <td>
                <div className="readings">
                  {asset.latest_readings.map((r) => (
                    <span key={r.id} className="r-item">
                      <span className="r-label">{formatMetricName(r.metric_name)}</span>
                      <span className="r-val">{formatValue(r.value)}</span>
                      {r.unit && <span className="r-unit">{r.unit}</span>}
                    </span>
                  ))}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
