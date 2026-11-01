class_name MovementComponent
extends Node
## Ground and air movement, sprint, jump and step-up (design §4).

## Emitted on touching the ground, with the height fallen from the highest point of the jump or fall.
signal landed(fall_height: float)

var is_sprinting: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _was_on_floor: bool = true
var _air_peak_y: float = 0.0


func physics_update(body: CharacterBody3D, intent: InputIntent, stance: StanceComponent,
		settings: PlayerMovementSettings, delta: float) -> void:
	var on_floor: bool = body.is_on_floor()
	_track_landing(body, on_floor)
	if on_floor:
		# Aiming and firing cancel sprint (design §4.2).
		is_sprinting = MovementRules.can_sprint(intent.move, intent.sprint, stance.is_crouched) \
			and not intent.aim and not intent.fire

	var move: Vector2 = intent.move.limit_length(1.0)
	var wish_direction: Vector3 = body.global_basis.x * move.x - body.global_basis.z * move.y
	var target_speed: float = MovementRules.target_speed(settings, stance.is_crouched, is_sprinting, intent.aim)
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
	var horizontal_motion: Vector3 = Vector3(body.velocity.x, 0.0, body.velocity.z) * delta
	if on_floor and vertical <= 0.0 and StepUp.try_step(body, horizontal_motion, settings.step_height):
		return
	body.move_and_slide()


func _track_landing(body: CharacterBody3D, on_floor: bool) -> void:
	if on_floor and not _was_on_floor:
		landed.emit(maxf(_air_peak_y - body.global_position.y, 0.0))
	if not on_floor:
		_air_peak_y = body.global_position.y if _was_on_floor else maxf(_air_peak_y, body.global_position.y)
	_was_on_floor = on_floor
