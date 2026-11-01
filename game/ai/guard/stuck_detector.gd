class_name StuckDetector
extends RefCounted
## Notices a guard that is trying to move but is not getting anywhere.

var _reference: Vector3 = Vector3.ZERO
var _time: float = 0.0


func reset(position: Vector3) -> void:
	_reference = position
	_time = 0.0


## Call every tick while travelling. True once less than min_progress metres were covered in timeout seconds.
func update(position: Vector3, delta: float, min_progress: float, timeout: float) -> bool:
	_time += delta
	if position.distance_to(_reference) >= min_progress:
		reset(position)
		return false
	return _time >= timeout
