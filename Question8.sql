SELECT
  t.tripid,
  ST_Transform(trajectory(t.trip), 4326) AS geom,  -- convert to WGS84 
  ST_Length(ST_Transform(trajectory(t.trip), 4326)::geography) AS length_meters
FROM trips t
WHERE t.trip IS NOT NULL
ORDER BY length_meters DESC
LIMIT 1;