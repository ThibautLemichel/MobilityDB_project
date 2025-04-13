WITH hours AS (
  SELECT 
    ts AS start_time,
    ts + interval '1 hour' AS end_time,
    (
      '[' || ts::text || ',' || (ts + interval '1 hour')::text || ']'
    )::tstzspan AS period
  FROM generate_series(
         '2020-06-03 00:00:00+00'::timestamptz,
         '2020-06-03 23:00:00+00'::timestamptz,
         interval '1 hour'
  ) AS ts
)
SELECT 
  h.period,
  (
    SELECT COUNT(*)
    FROM trips t
    WHERE getTime(t.trip) && h.period
  ) AS count
FROM hours h
ORDER BY h.period;