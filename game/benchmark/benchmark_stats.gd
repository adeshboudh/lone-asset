class_name BenchmarkStats
extends RefCounted
## Frame-time statistics for the benchmark (design §18.4). Pure logic.

## Upper edges (ms) of the frame-time histogram buckets: 120, 90, 60, 45 and 30 FPS; the last bucket is open.
const BUCKET_EDGES_MS: Array[float] = [8.33, 11.11, 16.67, 22.22, 33.33]
## Minimum tier (design §19.1).
const TARGET_AVERAGE_FPS: float = 60.0
const TARGET_LOW_FPS: float = 45.0


## Frame time (ms) below which `fraction` of the frames fall (nearest rank).
static func percentile_ms(frame_ms: PackedFloat32Array, fraction: float) -> float:
	if frame_ms.is_empty():
		return 0.0
	var sorted: Array = Array(frame_ms)
	sorted.sort()
	var index: int = clampi(ceili(fraction * sorted.size()) - 1, 0, sorted.size() - 1)
	return float(sorted[index])


static func average_fps(frame_ms: PackedFloat32Array) -> float:
	var total: float = 0.0
	for ms: float in frame_ms:
		total += ms
	return 0.0 if total <= 0.0 else frame_ms.size() * 1000.0 / total


## "1 % low": the frame rate of the slowest 1 % of frames (99th-percentile frame time).
static func low_fps(frame_ms: PackedFloat32Array) -> float:
	var worst: float = percentile_ms(frame_ms, 0.99)
	return 0.0 if worst <= 0.0 else 1000.0 / worst


## Frames per bucket, one more bucket than there are edges.
static func histogram(frame_ms: PackedFloat32Array) -> PackedInt32Array:
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(BUCKET_EDGES_MS.size() + 1)
	for ms: float in frame_ms:
		var bucket: int = BUCKET_EDGES_MS.size()
		for i: int in BUCKET_EDGES_MS.size():
			if ms < BUCKET_EDGES_MS[i]:
				bucket = i
				break
		counts[bucket] += 1
	return counts


static func passes(average: float, low: float) -> bool:
	return average >= TARGET_AVERAGE_FPS and low >= TARGET_LOW_FPS


## Position and travel direction at `distance` metres along a polyline (clamped to its ends).
static func point_along(path: PackedVector3Array, distance: float) -> Array:
	var remaining: float = maxf(distance, 0.0)
	for i: int in path.size() - 1:
		var leg: Vector3 = path[i + 1] - path[i]
		var length: float = leg.length()
		if remaining <= length or i == path.size() - 2:
			var t: float = clampf(remaining / maxf(length, 0.001), 0.0, 1.0)
			return [path[i].lerp(path[i + 1], t), leg.normalized()]
		remaining -= length
	return [path[0], Vector3.FORWARD]


static func path_length(path: PackedVector3Array) -> float:
	var total: float = 0.0
	for i: int in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total
