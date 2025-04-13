select t1.vehicleId,
       duration(t1.trip) as duration,
	   t1.trajectory
from trips t1
join (
    select vehicleId, MAX(length(trip)) as max_length
    from trips
    group by vehicleId
) t2 on t1.vehicleId = t2.vehicleId and length(t1.trip) = t2.max_length;