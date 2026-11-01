extends GdUnitTestSuite
## BallisticsSystem: hits, hit zones, shooter exclusion, gravity drop, cleanup.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")
const ZONES: HitZoneTable = preload("res://data/damage/hit_zones.tres")
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
	await _ticks(40)
	# The impact mark sits where the bullet hit.
	for mark: Node in wall.get_children():
		if mark is MeshInstance3D:
			hit_y.append((mark as MeshInstance3D).global_position.y)
	assert_array(hit_y).has_size(1)
	# Drop ≈ ½·g·t², t = 299.5 / 880 s → about 0.57 m.
	assert_float(hit_y[0]).is_between(-0.65, -0.5)


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
