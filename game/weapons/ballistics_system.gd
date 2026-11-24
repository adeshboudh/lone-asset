class_name BallisticsSystem
extends Node3D
## Simulates bullets as pooled data records advanced by stepped raycasts (design §5.3) — no physics
## body per bullet. One per level; weapons find it through the "ballistics" group.

const GROUP: StringName = &"ballistics"
const MAX_LIFETIME_S: float = 2.0
const MAX_IMPACT_MARKS: int = 64
const MAX_TRACERS: int = 128
const MAX_RICOCHETS: int = 1
## Thickest layer a bullet can pass through; thicker objects stop it however much power it has.
const MAX_PENETRATION_THICKNESS_M: float = 1.0
const MAX_IMPACT_FX: int = 12
const MAX_IMPACT_PUFFS: int = 12
const BULLET_HOLE: Texture2D = preload("res://content/effects/impacts/bullet_hole.png")
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
	var power: float
	var ricochets: int
	var impacts: int
	## Distance flown when the bullet last changed course; the tracer trail does not reach back past it.
	var trail_from: float


@export var hit_zones: HitZoneTable
## Per-surface impact effects, ricochet and penetration. Null = every surface behaves as plain stopping geometry.
@export var surfaces: SurfaceTable
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
var puff_count: int:
	get:
		var playing: int = 0
		for puff: CPUParticles3D in _puffs:
			if puff.emitting:
				playing += 1
		return playing

var _tracers: MultiMesh
var _fx: Array[CPUParticles3D] = []
var _next_fx: int = 0
var _puffs: Array[CPUParticles3D] = []
var _next_puff: int = 0
## One quad per sheet, so a puff swaps meshes and not materials.
var _puff_meshes: Dictionary = {}
## Shots fired so far per shooter (instance id), for the every-nth tracer rule.
var _shot_counts: Dictionary = {}


func _enter_tree() -> void:
	# Registered on entering the tree, before any _ready, so weapons can find it regardless of node order.
	add_to_group(GROUP)


func _ready() -> void:
	var mark_mesh: QuadMesh = QuadMesh.new()
	mark_mesh.size = Vector2(0.08, 0.08)
	var mark_material: StandardMaterial3D = StandardMaterial3D.new()
	mark_material.albedo_texture = BULLET_HOLE
	mark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
	_build_impact_fx()
	_build_impact_puffs()


## shooter is excluded from the bullet's collisions.
## `profile` is what the fired round changes about the shot (ShotProfile); null is a plain round.
func fire(origin: Vector3, direction: Vector3, weapon: WeaponDefinition, shooter: CollisionObject3D, profile: ShotProfile = null) -> void:
	var projectile: Projectile = _pool.pop_back() if not _pool.is_empty() else Projectile.new()
	projectile.position = origin
	projectile.velocity = direction.normalized() * weapon.muzzle_velocity * (profile.velocity_mult if profile != null else 1.0)
	projectile.travelled = 0.0
	projectile.age = 0.0
	projectile.damage = weapon.damage * (profile.damage_mult if profile != null else 1.0)
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
	projectile.tracer = (weapon.tracer_enabled and TracerRules.shows_tracer(shot_index, weapon.tracer_every_n)) or (profile != null and profile.tracer)
	projectile.tracer_color = Color(weapon.tracer_color.r * weapon.tracer_glow, weapon.tracer_color.g * weapon.tracer_glow,
		weapon.tracer_color.b * weapon.tracer_glow, weapon.tracer_color.a)
	projectile.tracer_length = weapon.tracer_length_m
	projectile.tracer_width = weapon.tracer_width_m
	projectile.tracer_start = weapon.tracer_start_m
	projectile.power = weapon.penetration_power * (profile.penetration_mult if profile != null else 1.0)
	projectile.ricochets = 0
	projectile.impacts = 0
	projectile.trail_from = 0.0
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
			projectile.travelled += projectile.position.distance_to(hit["position"])
			if _resolve_hit(projectile, hit):
				return projectile.age < MAX_LIFETIME_S
			return false
		projectile.travelled += projectile.position.distance_to(next)
		projectile.position = next
		if projectile.travelled >= projectile.max_range:
			return false
	return projectile.age < MAX_LIFETIME_S


## Returns true when the bullet carries on (it ricocheted or went through), false when it is finished.
func _resolve_hit(projectile: Projectile, hit: Dictionary) -> bool:
	var collider: Object = hit["collider"]
	var position: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var surface: SurfaceDefinition = _surface_of(collider)
	_place_mark(collider as Node3D, position, normal)
	_spawn_impact_fx(surface, position, normal)
	_spawn_impact_puff(surface, position, normal)
	# One noise per bullet, however many surfaces it passes.
	if projectile.impacts == 0:
		NoiseSystem.emit_noise(NoiseEvent.IMPACT, position, NoiseSystem.profiles.impact_m, projectile.source)
	projectile.impacts += 1

	var health: HealthComponent = HealthComponent.of(collider)
	var sound: StringName = &"impact_world"
	if health != null:
		sound = &"impact_body"
	elif surface != null and surface.impact_sound != &"" and Audio.bank.has_sound(surface.impact_sound):
		sound = surface.impact_sound
	Audio.play_3d(sound, position, &"Weapons", -2.0, projectile.source)
	if health == null:
		return _bounce_or_pass(projectile, surface, collider, position, normal)
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
	return false


## World hit: skip off at a shallow angle, else punch through thin material if the bullet has the power.
func _bounce_or_pass(projectile: Projectile, surface: SurfaceDefinition, collider: Object, position: Vector3,
		normal: Vector3) -> bool:
	if surface == null:
		return false
	var direction: Vector3 = projectile.velocity.normalized()
	var grazing: float = ImpactRules.grazing_angle_deg(direction, normal)
	if ImpactRules.ricochets(surface.ricochet_max_angle_deg, grazing, projectile.ricochets, MAX_RICOCHETS):
		projectile.ricochets += 1
		projectile.velocity = ImpactRules.reflect(direction, normal) * projectile.velocity.length() * surface.ricochet_speed_keep
		projectile.damage *= surface.ricochet_damage_keep
		projectile.position = position + normal * 0.02
		projectile.trail_from = projectile.travelled
		return true
	if not surface.penetrable or projectile.power <= 0.0:
		return false
	# The far side of the same object: a ray from beyond it back to the hit point meets the exit face first.
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		position + direction * MAX_PENETRATION_THICKNESS_M, position, collision_mask, projectile.exclude)
	var exit: Dictionary = space.intersect_ray(query)
	if exit.is_empty() or exit["collider"] != collider:
		return false
	var exit_position: Vector3 = exit["position"]
	var left: float = ImpactRules.remaining_power(projectile.power, position.distance_to(exit_position),
		surface.penetration_cost_per_m)
	if left <= 0.0:
		return false
	projectile.damage *= left / projectile.power
	projectile.power = left
	_place_mark(collider as Node3D, exit_position, exit["normal"])
	_spawn_impact_fx(surface, exit_position, exit["normal"])
	_spawn_impact_puff(surface, exit_position, exit["normal"])
	projectile.position = exit_position + direction * 0.02
	projectile.trail_from = projectile.travelled
	return true


## The surface definition for what the bullet hit: the `surface` metadata on the collider or a parent.
func _surface_of(collider: Object) -> SurfaceDefinition:
	if surfaces == null:
		return null
	var node: Node = collider as Node
	for i: int in 3:
		if node == null:
			break
		if node.has_meta(&"surface"):
			return surfaces.lookup(node.get_meta(&"surface"))
		node = node.get_parent()
	return surfaces.default_surface


func _place_mark(parent: Node3D, position: Vector3, normal: Vector3) -> void:
	var mark: MeshInstance3D = _marks[_next_mark]
	_next_mark = (_next_mark + 1) % _marks.size()
	# Marks follow what they hit (e.g. a falling target).
	# Not under CSG geometry: any child change makes a CSG node rebuild its mesh and collision, a 20 ms hitch.
	var new_parent: Node3D = self if parent == null or parent is CSGShape3D else parent
	if mark.get_parent() != new_parent:
		mark.reparent(new_parent, false)
	var up_hint: Vector3 = Vector3.FORWARD if absf(normal.y) > 0.99 else Vector3.UP
	var facing: Basis = Basis.looking_at(-normal, up_hint)
	mark.global_transform = Transform3D(facing.rotated(normal, randf() * TAU), position + normal * 0.005)
	mark.visible = true


func _build_tracers() -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
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
		var length: float = TracerRules.visible_length(
			projectile.travelled - projectile.trail_from, projectile.tracer_start if projectile.trail_from == 0.0 else 0.0, full_length)
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


func _build_impact_fx() -> void:
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2.ONE
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# Without this the billboard ignores the particle scale and every spark is a metre wide.
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = material
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	for i: int in MAX_IMPACT_FX:
		var particles: CPUParticles3D = CPUParticles3D.new()
		particles.mesh = quad
		particles.one_shot = true
		particles.emitting = false
		particles.explosiveness = 1.0
		particles.spread = 55.0
		particles.gravity = Vector3(0.0, -6.0, 0.0)
		particles.color_ramp = fade
		particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		particles.top_level = true
		add_child(particles)
		_fx.append(particles)


## Sparks, dust or splash at the hit point, thrown out along the surface normal.
func _spawn_impact_fx(surface: SurfaceDefinition, position: Vector3, normal: Vector3) -> void:
	if surface == null:
		return
	var particles: CPUParticles3D = _fx[_next_fx]
	_next_fx = (_next_fx + 1) % _fx.size()
	particles.emitting = false
	particles.global_position = position + normal * 0.02
	particles.direction = normal
	particles.amount = surface.fx_count
	particles.lifetime = surface.fx_lifetime_s
	particles.initial_velocity_min = surface.fx_speed_m * 0.5
	particles.initial_velocity_max = surface.fx_speed_m
	particles.scale_amount_min = surface.fx_size_m
	particles.scale_amount_max = surface.fx_size_m * 1.6
	particles.color = surface.fx_color
	particles.restart()
	particles.emitting = true


func _build_impact_puffs() -> void:
	for i: int in MAX_IMPACT_PUFFS:
		var puff: CPUParticles3D = CPUParticles3D.new()
		puff.one_shot = true
		puff.emitting = false
		puff.amount = 1
		puff.explosiveness = 1.0
		puff.gravity = Vector3.ZERO
		puff.initial_velocity_max = 0.0
		puff.anim_speed_min = 1.0
		puff.anim_speed_max = 1.0
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puff.top_level = true
		add_child(puff)
		_puffs.append(puff)


func _puff_mesh(sheet: Texture2D) -> QuadMesh:
	if not _puff_meshes.has(sheet):
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		material.vertex_color_use_as_albedo = true
		material.albedo_texture = sheet
		material.particles_anim_h_frames = 4
		material.particles_anim_v_frames = 4
		material.particles_anim_loop = false
		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2.ONE
		quad.material = material
		_puff_meshes[sheet] = quad
	return _puff_meshes[sheet]


## Plays the surface's flipbook once at the hit point. The sheet has 16 frames, so the particle lives 16 / fps seconds.
func _spawn_impact_puff(surface: SurfaceDefinition, position: Vector3, normal: Vector3) -> void:
	if surface == null or surface.flipbook == null:
		return
	var puff: CPUParticles3D = _puffs[_next_puff]
	_next_puff = (_next_puff + 1) % _puffs.size()
	puff.emitting = false
	puff.mesh = _puff_mesh(surface.flipbook)
	puff.global_position = position + normal * 0.05
	puff.lifetime = 16.0 / surface.flipbook_fps
	puff.scale_amount_min = surface.flipbook_size_m
	puff.scale_amount_max = surface.flipbook_size_m
	puff.color = surface.flipbook_tint
	puff.restart()
	puff.emitting = true
