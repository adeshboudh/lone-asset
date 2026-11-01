class_name PerceptionComponent
extends Node
## A guard's eyes (design §8.1). Checks whether the player is in its vision cones and in line of sight,
## and feeds the result into the guard's suspicion. Checks are run by PerceptionScheduler, which spreads
## them over frames; this component registers through a group so it needs no reference to the scheduler.

const GROUP: StringName = &"perception_components"
## A sighting never covers more than this much time, so a long gap cannot cause a jump in suspicion.
const MAX_SIGHTING_S: float = 1.0
const MIN_SIGHTING_S: float = 0.02

## Scheduler clock time (seconds) at which the next check is due.
var next_check_time: float = 0.0
## Fraction (0–1) of the target's sample points that were visible at the last check.
var last_visibility: float = 0.0
var last_cone: PerceptionRules.Cone = PerceptionRules.Cone.NONE
var last_distance: float = INF
var checks_done: int = 0

var _guard: Guard
var _last_check_time: float = -1.0
var _debug_cones: Array[MeshInstance3D] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	_guard = get_parent() as Guard
	_build_debug_cones()


func is_active() -> bool:
	return _guard != null and not _guard.is_dead


## One vision check against the player. Returns how many rays it cast.
func check(player: Player, now: float) -> int:
	var profile: GuardProfile = _guard.profile
	var points: PackedVector3Array = player.perception_points()
	var eye: Vector3 = _guard.eye_position()
	var to_target: Vector3 = points[1] - eye  # the chest stands for the whole body
	var distance: float = to_target.length()
	var cone: PerceptionRules.Cone = PerceptionRules.classify(profile,
		PerceptionRules.horizontal_angle_deg(_guard.facing(), to_target),
		PerceptionRules.vertical_angle_deg(to_target), distance)

	var sighting_s: float = clampf(now - _last_check_time, MIN_SIGHTING_S, MAX_SIGHTING_S) if _last_check_time >= 0.0 \
		else PerceptionRules.update_interval(distance, false)
	_last_check_time = now
	checks_done += 1
	last_cone = cone
	last_distance = distance
	last_visibility = 0.0

	var rays: int = 0
	if cone != PerceptionRules.Cone.NONE:
		last_visibility = visibility_of(points, eye)
		rays = PerceptionRules.RAYS_PER_CHECK
	if last_visibility > 0.0:
		_guard.on_player_seen(player, last_visibility, distance, cone, sighting_s)

	next_check_time = now + PerceptionRules.update_interval(distance, _guard.brain.current_name == GuardState.COMBAT)
	return rays


## Fraction of the sample points with a clear line of sight from the eye.
func visibility_of(points: PackedVector3Array, eye: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = _guard.get_world_3d().direct_space_state
	var clear: int = 0
	for point: Vector3 in points:
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(eye, point, PerceptionRules.LOS_MASK)
		if space.intersect_ray(query).is_empty():
			clear += 1
	return float(clear) / float(points.size())


func on_guard_died() -> void:
	for cone: MeshInstance3D in _debug_cones:
		cone.queue_free()
	_debug_cones.clear()


## Flat fans on the ground showing the vision cones (F3 debug views).
func _build_debug_cones() -> void:
	var profile: GuardProfile = _guard.profile
	_debug_cones.append(_make_fan(profile.primary_fov_deg, profile.primary_range_m, Color(1.0, 0.9, 0.2, 0.18)))
	_debug_cones.append(_make_fan(profile.peripheral_fov_deg, profile.peripheral_range_m, Color(1.0, 0.5, 0.1, 0.22)))
	for cone: MeshInstance3D in _debug_cones:
		_guard.add_child.call_deferred(cone)


func _make_fan(fov_deg: float, radius: float, color: Color) -> MeshInstance3D:
	var vertices: PackedVector3Array = PackedVector3Array([Vector3.ZERO])
	var segments: int = 24
	for i: int in segments + 1:
		var angle: float = deg_to_rad(lerpf(-fov_deg * 0.5, fov_deg * 0.5, float(i) / segments))
		vertices.append(Vector3(sin(angle), 0.0, -cos(angle)) * radius)
	var indices: PackedInt32Array = PackedInt32Array()
	for i: int in segments:
		indices.append_array([0, i + 2, i + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	mesh.surface_set_material(0, material)
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.position.y = 0.06
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.visible = bool(get_tree().get_meta(&"debug_views_enabled", false))
	instance.add_to_group(&"debug_view_nodes")
	return instance
