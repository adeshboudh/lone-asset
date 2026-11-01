class_name ScanRules
extends RefCounted
## Where a guard looks while scanning an area (investigating, searching). Pure logic, unit-tested.

## Looking order as multiples of the scan angle: straight ahead, left, right, further left, further right.
const OFFSETS: Array[float] = [0.0, 1.0, -1.0, 2.0, -2.0]


## The direction to look `elapsed` seconds into a scan that started facing `base`.
static func direction_at(base: Vector3, elapsed: float, step_s: float, angle_deg: float) -> Vector3:
	var index: int = int(elapsed / maxf(step_s, 0.01)) % OFFSETS.size()
	return base.rotated(Vector3.UP, deg_to_rad(OFFSETS[index] * angle_deg))
