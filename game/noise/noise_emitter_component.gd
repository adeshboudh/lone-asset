class_name NoiseEmitterComponent
extends Node
## Makes the player's gameplay noise (design §8.2): footsteps by stride, landings, shots.

## A footstep happened (also when too quiet for AI to matter). Audio listens to this.
signal stepped(type: StringName, surface: StringName)

## Falls shorter than this make no landing noise (stairs, small steps).
const LANDING_MIN_FALL_M: float = 0.3
## Footstep surface check: a ray this far below the feet.
const SURFACE_RAY_UP: float = 0.2
const SURFACE_RAY_DOWN: float = 0.5

var _stride_progress: float = 0.0


func physics_update(body: CharacterBody3D, on_floor: bool, speed: float, crouched: bool, sprinting: bool, delta: float) -> void:
	if not on_floor or speed < NoiseRules.MIN_STEP_SPEED:
		return
	var profiles: NoiseProfiles = NoiseSystem.profiles
	var type: StringName = NoiseRules.footstep_type(crouched, sprinting)
	_stride_progress += speed * delta
	var stride: float = profiles.stride(type)
	if _stride_progress < stride:
		return
	_stride_progress = fmod(_stride_progress, stride)
	var surface: StringName = _surface_of(body)
	var radius: float = profiles.footstep_radius(type) * profiles.surface_multiplier(surface)
	NoiseSystem.emit_noise(type, body.global_position, radius, body)
	stepped.emit(type, surface)


func on_landed(body: CharacterBody3D, fall_height: float) -> void:
	if fall_height >= LANDING_MIN_FALL_M:
		NoiseSystem.emit_noise(NoiseEvent.LANDING, body.global_position, NoiseSystem.profiles.landing_m, body)


func emit_shot(body: CharacterBody3D, weapon: WeaponDefinition) -> void:
	var type: StringName = NoiseEvent.SHOT_SUPPRESSED if weapon.suppressed else NoiseEvent.SHOT
	NoiseSystem.emit_noise(type, body.global_position, weapon.noise_radius_m, body)


## The "surface" metadata of the floor under the body, or &"" for the default surface.
func _surface_of(body: CharacterBody3D) -> StringName:
	var from: Vector3 = body.global_position + Vector3.UP * SURFACE_RAY_UP
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * (SURFACE_RAY_UP + SURFACE_RAY_DOWN), NoiseSystem.WORLD_MASK, [body.get_rid()])
	var hit: Dictionary = body.get_world_3d().direct_space_state.intersect_ray(query)
	var floor_node: Node = hit.get("collider") as Node
	if floor_node != null and floor_node.has_meta(&"surface"):
		return floor_node.get_meta(&"surface")
	return &""
