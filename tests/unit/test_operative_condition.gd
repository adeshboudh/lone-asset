extends GdUnitTestSuite
## The display-only operative condition.


func test_values_are_clamped() -> void:
	var condition: OperativeCondition = OperativeCondition.new()
	condition.upper_injury = 5
	condition.lower_injury = -1
	condition.stress = 140.0
	assert_int(condition.upper_injury).is_equal(2)
	assert_int(condition.lower_injury).is_equal(0)
	assert_float(condition.stress).is_equal(100.0)


func test_condition_round_trips() -> void:
	var condition: OperativeCondition = OperativeCondition.new()
	condition.bleeding = true
	condition.lower_injury = 1
	condition.stress = 35.0
	var loaded: OperativeCondition = OperativeCondition.from_dict(condition.to_dict())
	assert_bool(loaded.bleeding).is_true()
	assert_int(loaded.lower_injury).is_equal(1)
	assert_float(loaded.stress).is_equal(35.0)


func test_missing_data_gives_the_default_condition() -> void:
	for source: Variant in [{}, null, "junk"]:
		var loaded: OperativeCondition = OperativeCondition.from_dict(source)
		assert_bool(loaded.bleeding).is_false()
		assert_int(loaded.upper_injury).is_equal(0)
		assert_float(loaded.stress).is_equal(0.0)
