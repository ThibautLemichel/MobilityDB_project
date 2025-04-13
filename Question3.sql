SELECT
  t1.vehicleid AS vehicle1,
  t2.vehicleid AS vehicle2,
  tdwithin(t1.trip, t2.trip, 50.0::float8, TRUE) AS proximity_times,
  nearestApproachInstant(t1.trip, t2.trip) AS closest_moment,
  getValue(nearestApproachInstant(t1.trip, t2.trip)) AS closest_point,
  nearestApproachDistance(t1.trip, t2.trip) AS min_distance
FROM
  trips t1
JOIN trips t2
  ON t1.vehicleid < t2.vehicleid
WHERE
  tdwithin(t1.trip, t2.trip, 50.0::float8, TRUE) IS NOT NULL
LIMIT 20;