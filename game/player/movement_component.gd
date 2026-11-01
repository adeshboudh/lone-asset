class_name MovementComponent
extends Node
## Ground and air movement, sprint, jump and step-up (design §4).

## Minimum forward distance when stepping up. A single tick moves only a few centimetres, which would
## leave the body balanced on the very edge of the step.
const MIN_STEP_FORWARD: float = 0.1

var is_sprinting: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func physics_update(body: CharacterBody3D, intent: InputIntent, stance: StanceComponent,
		settings: PlayerMovementSettings, delta: float) -> void:
	var on_floor: bool = body.is_on_floor()
	if on_floor:
		is_sprinting = MovementRules.can_sprint(intent.move, intent.sprint, stance.is_crouched)

	var move: Vector2 = intent.move.limit_length(1.0)
	var wish_direction: Vector3 = body.global_basis.x * move.x - body.global_basis.z * move.y
	var target_speed: float = MovementRules.target_speed(settings, stance.is_crouched, is_sprinting, false)
	var rate: float = MovementRules.acceleration(settings, on_floor, move != Vector2.ZERO)
	var horizontal: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z)
	horizontal = horizontal.move_toward(wish_direction * target_speed, rate * delta)

	var vertical: float = body.velocity.y
	if on_floor:
		vertical = 0.0
		if intent.jump and not stance.is_crouched:
			vertical = settings.jump_velocity
	else:
		vertical -= _gravity * delta

	body.velocity = horizontal + Vector3.UP * vertical
	if on_floor and vertical <= 0.0 and _try_step_up(body, settings, delta):
		return
	body.move_and_slide()


## Climbs ledges up to step_height without jumping. Returns true if the body was moved.
func _try_step_up(body: CharacterBody3D, settings: PlayerMovementSettings, delta: float) -> bool:
	var motion: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
	if motion.length_squared() < 0.000001:
		return false

	var start: Transform3D = body.global_transform
	var hit: KinematicCollision3D = KinematicCollision3D.new()
	# Walkable slopes are left to move_and_slide; only steeper faces are treated as steps.
	if not body.test_move(start, motion, hit) or hit.get_normal().angle_to(Vector3.UP) <= body.floor_max_angle:
		return false

	var up: Vector3 = Vector3.UP * settings.step_height
	if body.test_move(start, up):
		return false
	var raised: Transform3D = start.translated(up)
	var forward: Vector3 = motion.normalized() * maxf(motion.length(), MIN_STEP_FORWARD)
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
