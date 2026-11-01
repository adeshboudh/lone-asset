class_name BallisticsSystem
extends Node3D
## Simulates bullets as pooled data records advanced by stepped raycasts (design §5.3) — no physics
## body per bullet. One per level; weapons find it through the "ballistics" group.

const GROUP: StringName = &"ballistics"
const MAX_LIFETIME_S: float = 2.0
const MAX_IMPACT_MARKS: int = 64


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


@export var hit_zones: HitZoneTable
@export_flags_3d_physics var collision_mask: int = 1

var active_count: int:
	get:
		return _active.size()

var _active: Array[Projectile] = []
var _pool: Array[Projectile] = []
var _gravity: Vector3 = Vector3.DOWN * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _marks: Array[MeshInstance3D] = []
var _next_mark: int = 0


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
	_active.append(projectile)


func _physics_process(delta: float) -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	for i: int in range(_active.size() - 1, -1, -1):
		if not _advance(_active[i], delta, space):
			_pool.append(_active[i])
			_active.remove_at(i)


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

	var health: HealthComponent = HealthComponent.of(collider)
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
	var new_parent: Node3D = parent if parent != null else self
	if mark.get_parent() != new_parent:
		mark.reparent(new_parent, false)
	var up_hint: Vector3 = Vector3.FORWARD if absf(normal.y) > 0.99 else Vector3.UP
	mark.global_transform = Transform3D(Basis.looking_at(-normal, up_hint), position + normal * 0.005)
	mark.visible = true
