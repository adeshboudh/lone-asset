class_name ArmIkRules
extends RefCounted
## Two-bone arm solver for the player's body (design §4). Pure functions, unit-tested.


## Elbow position for an arm that reaches from the shoulder toward the target. The hand lands on the
## target when it is within reach, and as close as the arm can get when it is not. pole is the direction
## the elbow bends toward (any vector not parallel to the reach).
static func elbow(shoulder: Vector3, target: Vector3, upper_length: float, fore_length: float, pole: Vector3) -> Vector3:
	var to_target: Vector3 = target - shoulder
	var reach: float = clampf(to_target.length(), absf(upper_length - fore_length) + 0.001, upper_length + fore_length - 0.001)
	var axis: Vector3 = to_target.normalized() if to_target.length() > 0.0001 else Vector3.FORWARD
	var along: float = (upper_length * upper_length - fore_length * fore_length + reach * reach) / (2.0 * reach)
	var height: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var bend: Vector3 = pole - axis * pole.dot(axis)
	if bend.length() < 0.0001:
		bend = axis.cross(Vector3.UP) if absf(axis.dot(Vector3.UP)) < 0.99 else axis.cross(Vector3.RIGHT)
	return shoulder + axis * along + bend.normalized() * height


## Rotation that turns the bone's rest direction onto the new one.
static func aim(rest_direction: Vector3, new_direction: Vector3) -> Quaternion:
	var from: Vector3 = rest_direction.normalized()
	var to: Vector3 = new_direction.normalized()
	if from.dot(to) < -0.9999:
		var side: Vector3 = from.cross(Vector3.UP) if absf(from.dot(Vector3.UP)) < 0.99 else from.cross(Vector3.RIGHT)
		return Quaternion(side.normalized(), PI)
	return Quaternion(from, to)
