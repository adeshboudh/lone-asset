extends GdUnitTestSuite
## AudioRules footstep ids (pure logic).


func test_footstep_id_uses_the_surface_and_falls_back_to_concrete() -> void:
	assert_str(AudioRules.footstep_id(&"metal")).is_equal("footstep_metal")
	assert_str(AudioRules.footstep_id(&"carpet")).is_equal("footstep_concrete")


func test_footstep_id_names_the_foot_only_for_per_foot_sounds() -> void:
	assert_str(AudioRules.footstep_id(&"grass", true, true)).is_equal("footstep_grass_left")
	assert_str(AudioRules.footstep_id(&"grass", false, true)).is_equal("footstep_grass_right")
	assert_str(AudioRules.footstep_id(&"grass", true)).is_equal("footstep_grass")
