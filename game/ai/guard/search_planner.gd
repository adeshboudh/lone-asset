class_name SearchPlanner
extends RefCounted
## Picking where a searching guard looks (design §7.4). The geometry helpers are pure; plan() needs a
## navigation map to keep the points on walkable ground.

## A random point whose navigation-mesh position is further than this from where it was asked for is
## off the mesh (inside a wall, say) and rejected.
const MAX_SNAP_DISTANCE_M: float = 2.0
const ATTEMPTS_PER_POINT: int = 8


## True if `point` is at least `min_separation` (on the ground plane) from every point in `existing`.
static func far_enough(point: Vector3, existing: Array[Vector3], min_separation: float) -> bool:
	for other: Vector3 in existing:
		if Vector2(point.x - other.x, point.z - other.z).length() < min_separation:
			return false
	return true


## Orders points so each is the nearest unvisited one to the previous (a cheap tour).
static func order_nearest_first(start: Vector3, points: Array[Vector3]) -> Array[Vector3]:
	var remaining: Array[Vector3] = points.duplicate()
	var ordered: Array[Vector3] = []
	var here: Vector3 = start
	while not remaining.is_empty():
		var best: int = 0
		for i: int in range(1, remaining.size()):
			if here.distance_squared_to(remaining[i]) < here.distance_squared_to(remaining[best]):
				best = i
		here = remaining.pop_at(best)
		ordered.append(here)
	return ordered


## The search tour: the centre first, then random walkable points within the search radius, kept apart.
static func plan(map: RID, start: Vector3, center: Vector3, profile: GuardProfile, rng: RandomNumberGenerator) -> Array[Vector3]:
	var wanted: int = rng.randi_range(profile.search_points_min, profile.search_points_max)
	var points: Array[Vector3] = [NavigationServer3D.map_get_closest_point(map, center)]
	var attempts: int = wanted * ATTEMPTS_PER_POINT
	while points.size() < wanted and attempts > 0:
		attempts -= 1
		var angle: float = rng.randf() * TAU
		var distance: float = sqrt(rng.randf()) * profile.search_radius_m
		var desired: Vector3 = center + Vector3(cos(angle), 0.0, sin(angle)) * distance
		var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, desired)
		if Vector2(snapped.x - desired.x, snapped.z - desired.z).length() > MAX_SNAP_DISTANCE_M:
			continue
		if far_enough(snapped, points, profile.search_min_separation_m):
			points.append(snapped)
	var rest: Array[Vector3] = points.slice(1)
	var tour: Array[Vector3] = [points[0]]
	tour.append_array(order_nearest_first(points[0], rest))
	return tour
