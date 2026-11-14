extends GdUnitTestSuite

const TABLE: SurfaceTable = preload("res://data/surfaces/surface_table.tres")


func test_known_surfaces_are_found() -> void:
	for id: StringName in [&"concrete", &"metal", &"grass", &"dirt", &"wood", &"water"]:
		assert_str(String(TABLE.lookup(id).id)).is_equal(String(id))


func test_unknown_surface_uses_the_default() -> void:
	assert_object(TABLE.lookup(&"lava")).is_same(TABLE.default_surface)


func test_wood_is_penetrable_and_concrete_is_not() -> void:
	assert_bool(TABLE.lookup(&"wood").penetrable).is_true()
	assert_bool(TABLE.lookup(&"concrete").penetrable).is_false()


func test_new_surface_added_in_code_is_found() -> void:
	var table: SurfaceTable = SurfaceTable.new()
	var snow: SurfaceDefinition = SurfaceDefinition.new()
	snow.id = &"snow"
	table.surfaces.append(snow)
	assert_object(table.lookup(&"snow")).is_same(snow)
