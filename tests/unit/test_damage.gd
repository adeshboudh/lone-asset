extends GdUnitTestSuite
## HealthComponent, hit zones and fall damage.

const ZONES: HitZoneTable = preload("res://data/damage/hit_zones.tres")


func _health(max_health: float = 100.0) -> HealthComponent:
	var health: HealthComponent = auto_free(HealthComponent.new())
	health.max_health = max_health
	add_child(health)
	return health


func _damage(amount: float) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.amount = amount
	return info


func test_damage_reduces_health() -> void:
	var health: HealthComponent = _health()
	assert_float(health.apply_damage(_damage(30.0))).is_equal(30.0)
	assert_float(health.health).is_equal(70.0)


func test_death_emitted_once_and_no_damage_after() -> void:
	var health: HealthComponent = _health()
	var deaths: Array[int] = [0]
	health.died.connect(func(_info: DamageInfo) -> void: deaths[0] += 1)
	assert_float(health.apply_damage(_damage(150.0))).is_equal(100.0)
	assert_float(health.apply_damage(_damage(10.0))).is_equal(0.0)
	assert_bool(health.is_dead).is_true()
	assert_int(deaths[0]).is_equal(1)


func test_reset_restores_health() -> void:
	var health: HealthComponent = _health()
	health.apply_damage(_damage(100.0))
	health.reset()
	assert_float(health.health).is_equal(100.0)
	assert_bool(health.is_dead).is_false()


func test_zone_multipliers() -> void:
	assert_float(ZONES.multiplier(&"head")).is_equal(4.0)
	assert_float(ZONES.multiplier(&"torso")).is_equal(1.0)
	assert_float(ZONES.multiplier(&"limb")).is_equal(0.6)
	assert_float(ZONES.multiplier(&"unknown")).is_equal(1.0)


func test_rifle_headshot_kills_guard_torso_does_not() -> void:
	var rifle: WeaponDefinition = load("res://data/weapons/rifle_suppressed.tres")
	assert_float(rifle.damage * ZONES.multiplier(&"head")).is_greater_equal(100.0)
	assert_float(rifle.damage * ZONES.multiplier(&"torso")).is_less(100.0)


func test_fall_damage() -> void:
	assert_float(DamageRules.fall_damage(3.9, 100.0)).is_equal(0.0)
	assert_float(DamageRules.fall_damage(7.0, 100.0)).is_equal_approx(50.0, 0.001)
	assert_float(DamageRules.fall_damage(12.0, 100.0)).is_equal(100.0)
