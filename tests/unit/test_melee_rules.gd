extends GdUnitTestSuite
## MeleeRules and LoadoutRules.


func test_behind_the_target_counts() -> void:
	# The target looks along -Z; the attacker stands at +Z.
	assert_bool(MeleeRules.is_from_behind(Vector3.FORWARD, Vector3.BACK, 60.0)).is_true()


func test_in_front_does_not_count() -> void:
	assert_bool(MeleeRules.is_from_behind(Vector3.FORWARD, Vector3.FORWARD, 60.0)).is_false()


func test_side_is_outside_a_narrow_arc() -> void:
	assert_bool(MeleeRules.is_from_behind(Vector3.FORWARD, Vector3.RIGHT, 60.0)).is_false()
	assert_bool(MeleeRules.is_from_behind(Vector3.FORWARD, Vector3.RIGHT, 100.0)).is_true()


func test_height_is_ignored() -> void:
	assert_bool(MeleeRules.is_from_behind(Vector3.FORWARD, Vector3(0.0, 2.0, 1.0), 60.0)).is_true()


func test_zero_vectors_are_not_behind() -> void:
	assert_bool(MeleeRules.is_from_behind(Vector3.ZERO, Vector3.BACK, 60.0)).is_false()
	assert_bool(MeleeRules.is_from_behind(Vector3.FORWARD, Vector3.ZERO, 60.0)).is_false()


func test_backstab_hits_harder() -> void:
	var knife: WeaponDefinition = WeaponDefinition.new()
	assert_float(MeleeRules.damage_for(knife, true)).is_greater(MeleeRules.damage_for(knife, false))


func test_heavy_attack_hits_harder_than_the_quick_one_from_the_front() -> void:
	var knife: WeaponDefinition = WeaponDefinition.new()
	assert_float(MeleeRules.damage_for(knife, false, true)).is_greater(MeleeRules.damage_for(knife, false, false))


func test_takedown_damage_is_the_same_for_both_attacks() -> void:
	var knife: WeaponDefinition = WeaponDefinition.new()
	assert_float(MeleeRules.damage_for(knife, true, true)).is_equal(MeleeRules.damage_for(knife, true, false))


func test_slot_request_lands_on_that_slot() -> void:
	assert_int(LoadoutRules.slot_after(2, 0, 3, true)).is_equal(1)


func test_no_request_keeps_the_slot() -> void:
	assert_int(LoadoutRules.slot_after(0, 2, 3, true)).is_equal(2)


func test_missing_slot_is_ignored() -> void:
	assert_int(LoadoutRules.slot_after(4, 1, 3, true)).is_equal(1)


func test_blocked_switch_keeps_the_slot() -> void:
	assert_int(LoadoutRules.slot_after(3, 0, 3, false)).is_equal(0)
