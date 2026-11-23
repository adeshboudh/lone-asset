extends GdUnitTestSuite
## AudioRules footstep ids (pure logic).


func test_footstep_and_landing_ids_use_the_surface_and_fall_back_to_generic() -> void:
	assert_str(AudioRules.footstep_id(&"metal")).is_equal("footstep_metal")
	assert_str(AudioRules.footstep_id(&"dirt")).is_equal("footstep_dirt")
	assert_str(AudioRules.footstep_id(&"carpet")).is_equal("footstep_generic")
	assert_str(AudioRules.landing_id(&"grass")).is_equal("landing_grass")
	assert_str(AudioRules.landing_id(&"")).is_equal("landing_generic")
