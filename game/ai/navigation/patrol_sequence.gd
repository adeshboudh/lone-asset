class_name PatrolSequence
extends RefCounted
## Which patrol point comes next (design §7.4). Pure logic, unit-tested.

enum Mode { LOOP, PING_PONG }

var count: int
var mode: Mode
var index: int = 0

var _direction: int = 1


func _init(point_count: int, patrol_mode: Mode = Mode.LOOP, start_index: int = 0) -> void:
	count = point_count
	mode = patrol_mode
	index = clampi(start_index, 0, maxi(count - 1, 0))


## Moves to the next point and returns its index.
func advance() -> int:
	if count <= 1:
		return index
	var next: int = index + _direction
	if mode == Mode.LOOP:
		next = posmod(next, count)
	elif next >= count or next < 0:
		_direction = -_direction
		next = index + _direction
	index = next
	return index
