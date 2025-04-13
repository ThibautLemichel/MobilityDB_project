DROP TABLE IF EXISTS HeatMap;

CREATE TABLE HeatMap (
    edge_id   INTEGER,
    trip_count INTEGER,
    geom      geometry(LineString, 4326)
);

WITH transformed_trips AS (
  SELECT
    t.tripid,
    ST_Transform(trajectory(t.trip), 4326) AS traj_geom
  FROM trips t
  WHERE t.trip IS NOT NULL
  limit 500
)
INSERT INTO HeatMap (edge_id, trip_count, geom)
SELECT
  w.gid AS edge_id,
  COUNT(DISTINCT t.tripid) AS trip_count,
  w.the_geom
FROM ways w
JOIN transformed_trips t
  ON w.the_geom && t.traj_geom            
 AND ST_Intersects(w.the_geom, t.traj_geom)
GROUP BY w.gid, w.the_geom
LIMIT 1000;