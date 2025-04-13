WITH classified_trips AS (
  SELECT
    t.tripid,
    CASE
      -- Home to work
      WHEN ST_Intersects(ST_StartPoint(trajectory(t.trip)), hr.geom)
        AND ST_Intersects(ST_EndPoint(trajectory(t.trip)), wr.geom)
      THEN 'home_work'

      -- Work to home
      WHEN ST_Intersects(ST_StartPoint(trajectory(t.trip)), wr.geom)
        AND ST_Intersects(ST_EndPoint(trajectory(t.trip)), hr.geom)
      THEN 'work_home'

      -- Leisure weekday
      WHEN lt.vehicleid IS NOT NULL AND EXTRACT(DOW FROM t.startdate) BETWEEN 1 AND 5
      THEN 'leisure_weekday'

      -- Leisure weekend
      WHEN lt.vehicleid IS NOT NULL AND EXTRACT(DOW FROM t.startdate) IN (0, 6)
      THEN 'leisure_weekend'
    END AS trip_type,
    endTimestamp(t.trip) - startTimestamp(t.trip) AS duration
  FROM trips t
  LEFT JOIN LeisureTrips lt 
    ON t.vehicleid = lt.vehicleid AND t.startdate = lt.startdate AND t.seqno = lt.seqno
  LEFT JOIN HomeRegions hr 
    ON hr.id = t.vehicleid
  LEFT JOIN WorkRegions wr 
    ON wr.id = t.vehicleid
  WHERE t.trip IS NOT NULL
)
SELECT
  trip_type,
  COUNT(*) AS total_trips,
  MIN(duration) AS min_duration,
  MAX(duration) AS max_duration,
  AVG(duration) AS avg_duration
FROM classified_trips
WHERE trip_type IS NOT NULL
GROUP BY trip_type;