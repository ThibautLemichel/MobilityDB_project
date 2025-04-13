SELECT DISTINCT
  t.vehicleid,
  p.periodid,
  r.regionid
FROM
  trips t
JOIN regions r
  ON trajectory(t.trip) && r.geom
 AND eintersects(t.trip, r.geom)
JOIN periods p
  ON getTime(t.trip) && p.period 
WHERE t.trip IS NOT NULL;