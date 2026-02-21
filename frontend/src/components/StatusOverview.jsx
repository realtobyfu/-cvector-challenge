import React from "react";

/**
 * Horizontal status pills: Operational | Warning | Critical | Offline
 * Quick at-a-glance plant health indicator.
 */
export default function StatusOverview({ dashboard }) {
  const statuses = [
    { key: "operational", count: dashboard.assets_operational, label: "Operational" },
    { key: "warning", count: dashboard.assets_warning, label: "Warning" },
    { key: "critical", count: dashboard.assets_critical, label: "Critical" },
    { key: "offline", count: dashboard.assets_offline, label: "Offline" },
  ];

  return (
    <div className="status-overview">
      <div className="status-pill">
        <span className="count">{dashboard.total_assets}</span>
        <span className="label">Total</span>
      </div>

      {statuses.map((s) => (
        <div key={s.key} className={`status-pill ${s.key}`}>
          <span className="count">{s.count}</span>
          <span className="label">{s.label}</span>
        </div>
      ))}
    </div>
  );
}
