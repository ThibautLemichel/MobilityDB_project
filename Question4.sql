WITH time_bounds AS (
  SELECT 
    MIN(startTimestamp(trip)) AS t1,
    MAX(endTimestamp(trip)) AS t2
  FROM trips
),
middle_point AS (
  SELECT 
    t1,
    t2,
    t1 + ((t2 - t1) / 2) AS t
  FROM time_bounds
),
classified AS (
  SELECT
    CASE 
      WHEN startTimestamp(trip) >= t1 AND endTimestamp(trip) < t THEN 'the first half of trips'
      WHEN startTimestamp(trip) >= t AND endTimestamp(trip) <= t2 THEN 'the second half of trips'
      WHEN startTimestamp(trip) < t AND endTimestamp(trip) >= t THEN 'trips that crossed t'
    END AS category
  FROM trips, middle_point
)
SELECT
  COUNT(*) FILTER (WHERE category = 'the first half of trips') AS first_half,
  COUNT(*) FILTER (WHERE category = 'the second half of trips') AS second_half,
  COUNT(*) FILTER (WHERE category = 'trips that crossed t') AS crossing
FROM classified;