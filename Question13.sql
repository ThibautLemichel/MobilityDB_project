WITH trip_period AS (
  SELECT
    t.vehicleid,
    p.periodid,
    p.period,
    startTimestamp(t.trip) AS trip_start,
    endTimestamp(t.trip) AS trip_end,
    -- Determine overlapping interval between the trip and the period:
    GREATEST(startTimestamp(t.trip), lower(p.period)) AS overlap_start,
    LEAST(endTimestamp(t.trip), upper(p.period)) AS overlap_end,
    -- Compute total trip distance in meters: reproject the trajectory to 4326 before computing geography distance
    ST_Length(ST_Transform(trajectory(t.trip), 4326)::geography) AS total_distance,
    -- Compute durations in seconds:
    EXTRACT(epoch FROM (endTimestamp(t.trip) - startTimestamp(t.trip))) AS trip_duration,
    EXTRACT(epoch FROM (LEAST(endTimestamp(t.trip), upper(p.period)) 
                       - GREATEST(startTimestamp(t.trip), lower(p.period)))) AS overlap_duration
  FROM trips t
  JOIN periods p
    ON getTime(t.trip) && p.period
)
SELECT
  vehicleid,
  periodid,
  period,
  SUM(total_distance * (overlap_duration / NULLIF(trip_duration, 0))) AS distance
FROM trip_period
GROUP BY vehicleid, periodid, period
ORDER BY distance DESC;