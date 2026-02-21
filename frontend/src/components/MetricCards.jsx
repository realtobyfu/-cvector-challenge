import React from "react";

/**
 * Pretty-print metric names: "power_consumption" → "Power Consumption"
 */
function formatMetricName(name) {
  return name
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Format large numbers nicely: 1234.56 → "1,234.6"
 */
function formatValue(value) {
  if (Math.abs(value) >= 1000) {
    return value.toLocaleString(undefined, { maximumFractionDigits: 1 });
  }
  return value.toFixed(1);
}

/**
 * Map metric names to accent colors for the top border line.
 */
function getAccentColor(metricName) {
  if (metricName.includes("power") || metricName.includes("output")) return "var(--green)";
  if (metricName.includes("consumption") || metricName.includes("efficiency")) return "var(--blue)";
  if (metricName.includes("steam") || metricName.includes("temperature")) return "var(--amber)";
  return "var(--border)";
}

const ADDITIVE_METRICS = new Set([
  "power_output",
  "power_consumption",
  "steam_flow",
  "flow_rate",
  "fuel_flow",
]);

export default function MetricCards({ summaries }) {
  if (!summaries || summaries.length === 0) return null;

  const sorted = [...summaries].sort((a, b) => {
    const order = ["power_output", "power_consumption", "steam_flow", "temperature", "pressure"];
    const ai = order.indexOf(a.metric_name);
    const bi = order.indexOf(b.metric_name);
    if (ai !== -1 && bi !== -1) return ai - bi;
    if (ai !== -1) return -1;
    if (bi !== -1) return 1;
    return a.metric_name.localeCompare(b.metric_name);
  });

  return (
    <div className="metric-cards">
      {sorted.map((m) => {
        const isAdditive = ADDITIVE_METRICS.has(m.metric_name);
        const displayValue = isAdditive ? m.total_value : m.avg_value;

        return (
          <div
            key={m.metric_name}
            className="metric-card"
            style={{ "--accent": getAccentColor(m.metric_name) }}
          >
            <div className="metric-label">{formatMetricName(m.metric_name)}</div>
            <div className="metric-value">
              {formatValue(displayValue)}
              <span className="metric-unit">{m.unit}</span>
            </div>
            <div className="metric-detail">
              {isAdditive ? (
                <>
                  <span className="metric-detail-highlight">{m.asset_count}</span> assets // avg{" "}
                  <span className="metric-detail-highlight">{formatValue(m.avg_value)}</span>
                </>
              ) : (
                <>
                  <span className="metric-detail-highlight">{m.asset_count}</span> assets // range{" "}
                  <span className="metric-detail-highlight">{formatValue(m.min_value)}</span>–
                  <span className="metric-detail-highlight">{formatValue(m.max_value)}</span>
                </>
              )}
            </div>
          </div>
        );
      })}
    </div>
  );
}
