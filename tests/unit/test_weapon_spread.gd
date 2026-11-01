extends GdUnitTestSuite
## WeaponSpread: spread by aim, movement and stance; bloom; cone sampling.

const RIFLE: WeaponDefinition = preload("res://data/weapons/rifle_suppressed.tres")


func test_aiming_is_tighter_than_hip() -> void:
	var spread: WeaponSpread = WeaponSpread.new()
	assert_float(spread.current_deg(RIFLE, true, 0.0, false)).is_less(spread.current_deg(RIFLE, false, 0.0, false))


func test_moving_widens_and_crouching_tightens() -> void:
	var spread: WeaponSpread = WeaponSpread.new()
	var still: float = spread.current_deg(RIFLE, false, 0.0, false)
	assert_float(spread.current_deg(RIFLE, false, 1.0, false)).is_equal_approx(still + RIFLE.spread_move_add_deg, 0.0001)
	assert_float(spread.current_deg(RIFLE, false, 0.0, true)).is_equal_approx(still * RIFLE.spread_crouch_mult, 0.0001)


func test_bloom_caps_and_recovers() -> void:
	var spread: WeaponSpread = WeaponSpread.new()
	for i: int in 100:
		spread.on_shot(RIFLE)
	assert_float(spread.bloom).is_equal(RIFLE.spread_max_bloom_deg)
	spread.update(RIFLE, 10.0)
	assert_float(spread.bloom).is_equal(0.0)


func test_directions_stay_inside_cone() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1234
	var forward: Vector3 = Vector3(0.3, 0.1, -1.0).normalized()
	for i: int in 500:
		var direction: Vector3 = WeaponSpread.random_direction(forward, 3.0, rng)
		assert_float(rad_to_deg(direction.angle_to(forward))).is_less_equal(3.0001)


func test_same_seed_same_directions() -> void:
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 42
	b.seed = 42
	for i: int in 10:
		assert_vector(WeaponSpread.random_direction(Vector3.FORWARD, 2.0, a)) \
			.is_equal(WeaponSpread.random_direction(Vector3.FORWARD, 2.0, b))


func test_zero_spread_is_exact() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_vector(WeaponSpread.random_direction(Vector3.FORWARD, 0.0, rng)).is_equal_approx(Vector3.FORWARD, Vector3.ONE * 0.00001)
