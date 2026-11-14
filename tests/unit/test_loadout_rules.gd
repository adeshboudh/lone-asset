extends GdUnitTestSuite




func test_attachment_swap_needs_a_variant() -> void:
	assert_bool(LoadoutRules.can_swap_variant(true, false, false)).is_true()
	assert_bool(LoadoutRules.can_swap_variant(false, false, false)).is_false()


func test_attachment_swap_blocked_while_reloading_or_swapping() -> void:
	assert_bool(LoadoutRules.can_swap_variant(true, true, false)).is_false()
	assert_bool(LoadoutRules.can_swap_variant(true, false, true)).is_false()
