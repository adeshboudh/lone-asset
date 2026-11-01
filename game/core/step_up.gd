class_name StepUp
extends RefCounted
## Walking up small ledges without jumping (design §4.1), shared by the player and guards.

## Minimum forward distance when stepping up. A single tick moves only a few centimetres, which would
## leave the body balanced on the very edge of the step.
const MIN_FORWARD: float = 0.1


## Moves the body up and over a ledge of at most step_height that blocks horizontal_motion (this tick's
## displacement). Returns true if the body was moved; the caller then skips its own move_and_slide.
static func try_step(body: CharacterBody3D, horizontal_motion: Vector3, step_height: float) -> bool:
	if horizontal_motion.length_squared() < 0.000001:
		return false

	var start: Transform3D = body.global_transform
	var hit: KinematicCollision3D = KinematicCollision3D.new()
	# Walkable slopes are left to move_and_slide; only steeper faces are treated as steps.
	if not body.test_move(start, horizontal_motion, hit) or hit.get_normal().angle_to(Vector3.UP) <= body.floor_max_angle:
		return false

	var up: Vector3 = Vector3.UP * step_height
	if body.test_move(start, up):
		return false
	var raised: Transform3D = start.translated(up)
	var forward: Vector3 = horizontal_motion.normalized() * maxf(horizontal_motion.length(), MIN_FORWARD)
	if body.test_move(raised, forward):
		return false

	var ground: KinematicCollision3D = KinematicCollision3D.new()
	var over: Transform3D = raised.translated(forward)
	if not body.test_move(over, -up, ground):
		return false
	if ground.get_normal().angle_to(Vector3.UP) > body.floor_max_angle:
		return false

	body.global_position = over.origin + ground.get_travel()
	# Settle on the new floor so is_on_floor() stays true, without moving horizontally twice.
	var velocity: Vector3 = body.velocity
	body.velocity = Vector3.DOWN
	body.move_and_slide()
	body.velocity = Vector3(velocity.x, 0.0, velocity.z)
	return true
