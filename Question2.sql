SELECT
  t.tripid,
  atgeometry(t.trip, ST_Union(m1.municipalitygeo, m2.municipalitygeo)) AS restricted_trip,
  timestamps(atgeometry(t.trip, ST_Union(m1.municipalitygeo, m2.municipalitygeo))) AS intersection_time
FROM
  trips t
JOIN municipalities m1 ON eintersects(t.trip, m1.municipalitygeo)
JOIN municipalities m2 ON eintersects(t.trip, m2.municipalitygeo)
WHERE
  m1.municipalityid < m2.municipalityid
  AND ST_Touches(m1.municipalitygeo, m2.municipalitygeo)
ORDER BY
  startTimestamp(t.trip)
LIMIT 30;