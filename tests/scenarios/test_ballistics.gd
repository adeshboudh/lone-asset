extends GdUnitTestSuite
## BallisticsSystem: hits, hit zones, shooter exclusion, gravity drop, cleanup.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")
const ZONES: HitZoneTable = preload("res://data/damage/hit_zones.tres")
const SURFACES: SurfaceTable = preload("res://data/surfaces/surface_table.tres")
const DUMMY: PackedScene = preload("res://game/targets/target_dummy.tscn")

var _arena: Node3D
var _ballistics: BallisticsSystem


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_ballistics = BallisticsSystem.new()
	_ballistics.hit_zones = ZONES
	_arena.add_child(_ballistics)
	await _ticks(2)


func test_torso_hit_applies_base_damage() -> void:
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -10.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(5)
	assert_float(HealthComponent.of(dummy).health).is_equal_approx(100.0 - RIFLE.damage, 0.01)


func test_headshot_kills() -> void:
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -10.0))
	await _ticks(2)
	var hits: Array[StringName] = []
	EventBus.damage_applied.connect(func(_t: Node, info: DamageInfo, _k: bool) -> void: hits.append(info.hit_zone))
	_ballistics.fire(Vector3(0.0, 1.62, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(5)
	assert_bool(HealthComponent.of(dummy).is_dead).is_true()
	assert_array(hits).contains([&"head"])


func test_limb_hit_reduced() -> void:
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -10.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 0.4, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(5)
	assert_float(HealthComponent.of(dummy).health).is_equal_approx(100.0 - RIFLE.damage * 0.6, 0.01)


func test_shooter_is_not_hit() -> void:
	var shooter: TargetDummy = _dummy(Vector3.ZERO)
	await _ticks(2)
	# Fired from inside the shooter's own torso.
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, shooter)
	await _ticks(5)
	assert_float(HealthComponent.of(shooter).health).is_equal(100.0)


func test_gravity_drops_bullet_over_distance() -> void:
	var wall: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 20.0, 1.0)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0.0, 0.0, -300.0)
	_arena.add_child(wall)
	await _ticks(2)
	var hit_y: Array[float] = []
	_ballistics.fire(Vector3.ZERO, Vector3.FORWARD, RIFLE, null)
	await _ticks(60)
	# The impact mark sits where the bullet hit.
	for mark: Node in wall.get_children():
		if mark is MeshInstance3D:
			hit_y.append((mark as MeshInstance3D).global_position.y)
	assert_array(hit_y).has_size(1)
	# Drop = ½·g·scale·t², with t the flight time to the wall face.
	var flight_s: float = 299.5 / RIFLE.muzzle_velocity
	var expected: float = -0.5 * 9.8 * RIFLE.gravity_scale * flight_s * flight_s
	assert_float(hit_y[0]).is_between(expected * 1.08, expected * 0.92)


func test_projectile_removed_after_max_range() -> void:
	_ballistics.fire(Vector3(0.0, 100.0, 0.0), Vector3.FORWARD, RIFLE, null)
	assert_int(_ballistics.active_count).is_equal(1)
	await _ticks(60)
	assert_int(_ballistics.active_count).is_equal(0)


func _dummy(position: Vector3) -> TargetDummy:
	var dummy: TargetDummy = DUMMY.instantiate()
	dummy.position = position
	_arena.add_child(dummy)
	return dummy


func _ticks(count: int) -> void:
	for i: int in count:
		await get_tree().physics_frame


func test_impact_mark_on_csg_geometry_stays_out_of_the_csg_node() -> void:
	var wall: CSGBox3D = auto_free(CSGBox3D.new())
	wall.use_collision = true
	wall.size = Vector3(4.0, 4.0, 0.5)
	wall.position = Vector3(0.0, 1.0, -10.0)
	_arena.add_child(wall)
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.0, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(5)
	assert_int(wall.get_child_count()).is_equal(0)


func test_tracer_appears_after_start_distance_and_ends_with_the_bullet() -> void:
	var weapon: WeaponDefinition = RIFLE.duplicate()
	weapon.tracer_enabled = true
	weapon.tracer_start_m = 3.0
	_ballistics.fire(Vector3(0.0, 100.0, 0.0), Vector3.FORWARD, weapon, null)
	assert_int(_ballistics.tracer_count).is_equal(0)
	await _ticks(3)
	assert_int(_ballistics.tracer_count).is_equal(1)
	await _ticks(60)
	assert_int(_ballistics.active_count).is_equal(0)
	assert_int(_ballistics.tracer_count).is_equal(0)


func test_tracer_every_nth_shot() -> void:
	var weapon: WeaponDefinition = RIFLE.duplicate()
	weapon.tracer_enabled = true
	weapon.tracer_every_n = 3
	weapon.tracer_start_m = 0.0
	for i: int in 6:
		_ballistics.fire(Vector3(float(i), 100.0, 0.0), Vector3.FORWARD, weapon, null)
	await _ticks(2)
	assert_int(_ballistics.tracer_count).is_equal(2)


func test_no_tracer_when_disabled() -> void:
	var weapon: WeaponDefinition = RIFLE.duplicate()
	weapon.tracer_enabled = false
	weapon.tracer_start_m = 0.0
	_ballistics.fire(Vector3(0.0, 100.0, 0.0), Vector3.FORWARD, weapon, null)
	await _ticks(2)
	assert_int(_ballistics.tracer_count).is_equal(0)


func test_bullet_goes_through_thin_wood_and_loses_damage() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"wood")
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -12.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	# 0.1 m of wood costs 25 of the rifle's 100 power: 75 % of the damage gets through.
	assert_float(HealthComponent.of(dummy).health).is_equal_approx(100.0 - RIFLE.damage * 0.75, 0.05)


func test_concrete_stops_the_bullet() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"concrete")
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -12.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_float(HealthComponent.of(dummy).health).is_equal(100.0)


func test_thick_wood_stops_the_bullet() -> void:
	_ballistics.surfaces = SURFACES
	# 0.5 m of wood costs 125, more than the rifle's 100 power.
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.5), &"wood")
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -12.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_float(HealthComponent.of(dummy).health).is_equal(100.0)


func test_no_penetration_without_a_surface_table() -> void:
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"wood")
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -12.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_float(HealthComponent.of(dummy).health).is_equal(100.0)


func test_shallow_hit_on_metal_ricochets_and_keeps_flying() -> void:
	_ballistics.surfaces = SURFACES
	# A steel floor; the bullet meets it at about 6 degrees.
	_wall(Vector3(0.0, -0.5, -20.0), Vector3(20.0, 1.0, 60.0), &"metal")
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -0.1, -1.0), RIFLE, null)
	await _ticks(8)
	assert_int(_ballistics.active_count).is_equal(1)


func test_steep_hit_on_concrete_ends_the_bullet() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, -0.5, -20.0), Vector3(20.0, 1.0, 60.0), &"concrete")
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.0, 0.0), Vector3(0.0, -1.0, -1.0), RIFLE, null)
	await _ticks(8)
	assert_int(_ballistics.active_count).is_equal(0)


func _wall(position: Vector3, size: Vector3, surface: StringName) -> StaticBody3D:
	var wall: StaticBody3D = auto_free(StaticBody3D.new())
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	wall.add_child(shape)
	wall.position = position
	wall.set_meta(&"surface", surface)
	_arena.add_child(wall)
	return wall


func test_hit_on_a_surface_with_a_flipbook_starts_a_puff() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"concrete")
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_int(_ballistics.puff_count).is_equal(1)


func test_hit_on_a_surface_without_a_flipbook_starts_no_puff() -> void:
	_ballistics.surfaces = SURFACES
	_wall(Vector3(0.0, 1.0, -10.0), Vector3(4.0, 4.0, 0.1), &"water")
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	assert_int(_ballistics.puff_count).is_equal(0)


func test_hit_on_a_body_splashes_blood_and_leaves_no_mark_on_it() -> void:
	_ballistics.surfaces = SURFACES
	var dummy: TargetDummy = _dummy(Vector3(0.0, 0.0, -10.0))
	await _ticks(2)
	_ballistics.fire(Vector3(0.0, 1.19, 0.0), Vector3.FORWARD, RIFLE, null)
	await _ticks(10)
	# The blood splat floats free for a moment (one puff); no decal is stuck to the body, where it would hang in the air once the body falls.
	assert_int(_ballistics.puff_count).is_equal(1)
	assert_int(dummy.find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool: return (n as MeshInstance3D).mesh is QuadMesh).size()).is_equal(0)
