import { useState, useEffect, useRef, useCallback } from "react";

/**
 * Custom hook that polls a data-fetching function at a fixed interval.
 *
 * @param {Function} fetchFn - Async function that returns data
 * @param {number} intervalMs - Polling interval in milliseconds (default: 15s)
 * @param {Array} deps - Dependencies that trigger a re-fetch when changed
 * @returns {{ data, loading, error, refetch }}
 */
export function usePolling(fetchFn, intervalMs = 15000, deps = []) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const intervalRef = useRef(null);
  const mountedRef = useRef(true);

  const refetch = useCallback(async () => {
    try {
      const result = await fetchFn();
      if (mountedRef.current) {
        setData(result);
        setError(null);
      }
    } catch (err) {
      if (mountedRef.current) {
        setError(err.message);
      }
    } finally {
      if (mountedRef.current) {
        setLoading(false);
      }
    }
  }, [fetchFn]);

  useEffect(() => {
    mountedRef.current = true;
    setLoading(true);
    refetch();

    intervalRef.current = setInterval(refetch, intervalMs);

    return () => {
      mountedRef.current = false;
      clearInterval(intervalRef.current);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [intervalMs, ...deps]);

  return { data, loading, error, refetch };
}
