class_name BallisticsSystem
extends Node3D
## Simulates bullets as pooled data records advanced by stepped raycasts (design §5.3) — no physics
## body per bullet. One per level; weapons find it through the "ballistics" group.

const GROUP: StringName = &"ballistics"
const MAX_LIFETIME_S: float = 2.0
const MAX_IMPACT_MARKS: int = 64
const MAX_TRACERS: int = 128
## Smallest apparent width of a tracer (radians), so it stays visible far away instead of shrinking to a sub-pixel dot.
const TRACER_MIN_ANGULAR_WIDTH: float = 0.003


class Projectile:
	var position: Vector3
	var velocity: Vector3
	var travelled: float
	var age: float
	var damage: float
	var max_range: float
	var steps: int
	var gravity_scale: float
	var source: Node
	var exclude: Array[RID]
	var tracer: bool
	var tracer_color: Color
	var tracer_length: float
	var tracer_width: float
	var tracer_start: float


@export var hit_zones: HitZoneTable
## World (1) and characters/targets (2).
@export_flags_3d_physics var collision_mask: int = 3

var active_count: int:
	get:
		return _active.size()

var tracer_count: int:
	get:
		return _tracers.visible_instance_count

var _active: Array[Projectile] = []
var _pool: Array[Projectile] = []
var _gravity: Vector3 = Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _marks: Array[MeshInstance3D] = []
var _next_mark: int = 0
var _tracers: MultiMesh
## Shots fired so far per shooter (instance id), for the every-nth tracer rule.
var _shot_counts: Dictionary = {}


func _enter_tree() -> void:
	# Registered on entering the tree, before any _ready, so weapons can find it regardless of node order.
	add_to_group(GROUP)


func _ready() -> void:
	var mark_mesh: QuadMesh = QuadMesh.new()
	mark_mesh.size = Vector2(0.05, 0.05)
	var mark_material: StandardMaterial3D = StandardMaterial3D.new()
	mark_material.albedo_color = Color(0.05, 0.05, 0.05)
	mark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mark_mesh.material = mark_material
	for i: int in MAX_IMPACT_MARKS:
		var mark: MeshInstance3D = MeshInstance3D.new()
		mark.mesh = mark_mesh
		mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mark.visible = false
		add_child(mark)
		_marks.append(mark)
	_build_tracers()


## shooter is excluded from the bullet's collisions.
func fire(origin: Vector3, direction: Vector3, weapon: WeaponDefinition, shooter: CollisionObject3D) -> void:
	var projectile: Projectile = _pool.pop_back() if not _pool.is_empty() else Projectile.new()
	projectile.position = origin
	projectile.velocity = direction.normalized() * weapon.muzzle_velocity
	projectile.travelled = 0.0
	projectile.age = 0.0
	projectile.damage = weapon.damage
	projectile.max_range = weapon.max_range
	projectile.steps = maxi(weapon.projectile_steps_per_tick, 1)
	projectile.gravity_scale = weapon.gravity_scale
	projectile.source = shooter
	projectile.exclude.clear()
	if shooter != null:
		projectile.exclude.append(shooter.get_rid())
	var key: int = shooter.get_instance_id() if shooter != null else 0
	var shot_index: int = _shot_counts.get(key, 0)
	_shot_counts[key] = shot_index + 1
	projectile.tracer = weapon.tracer_enabled and TracerRules.shows_tracer(shot_index, weapon.tracer_every_n)
	projectile.tracer_color = Color(weapon.tracer_color.r * weapon.tracer_glow, weapon.tracer_color.g * weapon.tracer_glow,
		weapon.tracer_color.b * weapon.tracer_glow)
	projectile.tracer_length = weapon.tracer_length_m
	projectile.tracer_width = weapon.tracer_width_m
	projectile.tracer_start = weapon.tracer_start_m
	_active.append(projectile)


func _physics_process(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for i: int in range(_active.size() - 1, -1, -1):
		if not _advance(_active[i], delta, space):
			_pool.append(_active[i])
			_active.remove_at(i)
	_update_tracers()


## Returns false when the projectile is finished (hit, out of range or too old).
func _advance(projectile: Projectile, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	projectile.age += delta
	var step: float = delta / projectile.steps
	for s: int in projectile.steps:
		projectile.velocity += _gravity * projectile.gravity_scale * step
		var next: Vector3 = projectile.position + projectile.velocity * step
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			projectile.position, next, collision_mask, projectile.exclude)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty():
			_resolve_hit(projectile, hit)
			return false
		projectile.travelled += projectile.position.distance_to(next)
		projectile.position = next
		if projectile.travelled >= projectile.max_range:
			return false
	return projectile.age < MAX_LIFETIME_S


func _resolve_hit(projectile: Projectile, hit: Dictionary) -> void:
	var collider: Object = hit["collider"]
	var position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	_place_mark(collider as Node3D, position, normal)
	NoiseSystem.emit_noise(NoiseEvent.IMPACT, position, NoiseSystem.profiles.impact_m, projectile.source)

	var health: HealthComponent = HealthComponent.of(collider)
	Audio.play_3d(&"impact_world" if health == null else &"impact_body", position, &"Weapons", -2.0, projectile.source)
	if health == null:
		return
	var zone: StringName = HitZoneTable.zone_of(collider, hit["shape"])
	var info: DamageInfo = DamageInfo.new()
	info.type = &"ballistic"
	info.source = projectile.source
	info.hit_position = position
	info.hit_normal = normal
	info.direction = projectile.velocity.normalized()
	info.hit_zone = zone
	info.amount = projectile.damage * (hit_zones.multiplier(zone) if hit_zones != null else 1.0)
	health.apply_damage(info)


func _place_mark(parent: Node3D, position: Vector3, normal: Vector3) -> void:
	var mark: MeshInstance3D = _marks[_next_mark]
	_next_mark = (_next_mark + 1) % _marks.size()
	# Marks follow what they hit (e.g. a falling target).
	# Not under CSG geometry: any child change makes a CSG node rebuild its mesh and collision, a 20 ms hitch.
	var new_parent: Node3D = self if parent == null or parent is CSGShape3D else parent
	if mark.get_parent() != new_parent:
		mark.reparent(new_parent, false)
	var up_hint: Vector3 = Vector3.FORWARD if absf(normal.y) > 0.99 else Vector3.UP
	mark.global_transform = Transform3D(Basis.looking_at(-normal, up_hint), position + normal * 0.005)
	mark.visible = true


func _build_tracers() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	_tracers = MultiMesh.new()
	_tracers.transform_format = MultiMesh.TRANSFORM_3D
	_tracers.use_colors = true
	_tracers.mesh = mesh
	_tracers.instance_count = MAX_TRACERS
	_tracers.visible_instance_count = 0
	var instance: MultiMeshInstance3D = MultiMeshInstance3D.new()
	instance.multimesh = _tracers
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The streaks move every tick; their bounds are not worth recomputing.
	instance.custom_aabb = AABB(Vector3(-2000.0, -2000.0, -2000.0), Vector3(4000.0, 4000.0, 4000.0))
	# World space regardless of where the system sits in the level.
	instance.top_level = true
	add_child(instance)


## Draws one stretched glowing box per live tracer bullet, from its head back along its velocity.
func _update_tracers() -> void:
	var count: int = 0
	var camera: Camera3D = get_viewport().get_camera_3d()
	var tick_s: float = 1.0 / float(Engine.physics_ticks_per_second)
	for projectile: Projectile in _active:
		if count >= MAX_TRACERS:
			break
		if not projectile.tracer:
			continue
		# At least the distance flown per tick, so the streak is a continuous line and not a dash every few metres.
		var full_length: float = maxf(projectile.tracer_length, projectile.velocity.length() * tick_s)
		var length: float = TracerRules.visible_length(projectile.travelled, projectile.tracer_start, full_length)
		if length <= 0.0:
			continue
		var width: float = projectile.tracer_width
		if camera != null:
			# Measured at the nearest end: a streak from the gun to far away would otherwise be a fat wedge.
			var tail: Vector3 = projectile.position - projectile.velocity.normalized() * length
			width = maxf(width, camera.global_position.distance_to(tail) * TRACER_MIN_ANGULAR_WIDTH)
		var direction: Vector3 = projectile.velocity.normalized()
		var up_hint: Vector3 = Vector3.FORWARD if absf(direction.y) > 0.99 else Vector3.UP
		var basis: Basis = Basis.looking_at(direction, up_hint).scaled_local(
			Vector3(width, width, length))
		_tracers.set_instance_transform(count, Transform3D(basis, projectile.position - direction * (length * 0.5)))
		_tracers.set_instance_color(count, projectile.tracer_color)
		count += 1
	_tracers.visible_instance_count = count
