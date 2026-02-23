/**
 * API client for the plant monitoring backend.
 * All functions return parsed JSON; errors throw.
 */

const BASE = "/api";

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`API error: ${res.status} ${res.statusText}`);
  return res.json();
}

export function fetchFacilities() {
  return fetchJSON(`${BASE}/facilities`);
}

export function fetchFacility(id) {
  return fetchJSON(`${BASE}/facilities/${id}`);
}

export function fetchDashboard(facilityId) {
  return fetchJSON(`${BASE}/facilities/${facilityId}/dashboard`);
}

export function fetchMetrics(facilityId) {
  return fetchJSON(`${BASE}/facilities/${facilityId}/metrics`);
}

/**
 * Fetch sensor readings with flexible filters.
 * @param {Object} params - Query parameters
 * @param {number} [params.facility_id]
 * @param {number} [params.asset_id]
 * @param {string} [params.metric_name]
 * @param {string} [params.start_time] - ISO 8601
 * @param {string} [params.end_time] - ISO 8601
 * @param {number} [params.limit]
 */
export function fetchReadings(params = {}) {
  const query = new URLSearchParams();
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== "") {
      query.append(k, v);
    }
  });
  return fetchJSON(`${BASE}/readings?${query.toString()}`);
}

export function fetchAsset(assetId) {
  return fetchJSON(`${BASE}/assets/${assetId}`);
}
