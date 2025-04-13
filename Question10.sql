SELECT DISTINCT ON (t.vehicleid, p.pointid)
  t.vehicleid,
  p.pointid,
  getTimestamp(i.inst) AS instance
FROM
  trips t
JOIN points p
  ON eintersects(t.trip, p.geom)
CROSS JOIN LATERAL (
  SELECT unnest(instants(atGeometry(t.trip, p.geom))) AS inst
) AS i
WHERE getTimestamp(i.inst) IS NOT NULL
ORDER BY t.vehicleid, p.pointid, instance;