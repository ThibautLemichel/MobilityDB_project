WITH vehicle_counts AS (
  SELECT
    p.periodid,
    p.period,
    (
      SELECT COUNT(DISTINCT t.vehicleid)
      FROM trips t
      WHERE getTime(t.trip) && p.period
    ) AS count_value
  FROM periods p
)
SELECT
  periodid AS regionid,
  (
    '[' ||
    count_value::text || '@' || lower(period)::text || ',' ||
    count_value::text || '@' || upper(period)::text ||
    ']'
  )::tint AS wcount
FROM vehicle_counts;