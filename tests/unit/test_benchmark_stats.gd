extends GdUnitTestSuite
## BenchmarkStats and the quality presets (pure logic).


func test_average_fps_from_frame_times() -> void:
	var frames: PackedFloat32Array = PackedFloat32Array([10.0, 20.0, 30.0])
	assert_float(BenchmarkStats.average_fps(frames)).is_equal_approx(50.0, 0.001)


func test_one_percent_low_uses_the_slowest_frames() -> void:
	var frames: PackedFloat32Array = PackedFloat32Array()
	for i: int in 99:
		frames.append(10.0)
	frames.append(50.0)
	# 100 frames: the 99th-percentile frame is still 10 ms; add another slow one to move it.
	assert_float(BenchmarkStats.low_fps(frames)).is_equal_approx(100.0, 0.01)
	frames.append(50.0)
	assert_float(BenchmarkStats.low_fps(frames)).is_equal_approx(20.0, 0.01)


func test_histogram_counts_each_frame_once() -> void:
	var frames: PackedFloat32Array = PackedFloat32Array([5.0, 10.0, 16.0, 20.0, 30.0, 40.0, 100.0])
	var counts: PackedInt32Array = BenchmarkStats.histogram(frames)
	assert_array(Array(counts)).is_equal([1, 1, 1, 1, 1, 2])


func test_pass_needs_both_targets() -> void:
	assert_bool(BenchmarkStats.passes(60.0, 45.0)).is_true()
	assert_bool(BenchmarkStats.passes(59.9, 50.0)).is_false()
	assert_bool(BenchmarkStats.passes(90.0, 44.0)).is_false()


func test_empty_runs_report_zero() -> void:
	var none: PackedFloat32Array = PackedFloat32Array()
	assert_float(BenchmarkStats.average_fps(none)).is_equal(0.0)
	assert_float(BenchmarkStats.low_fps(none)).is_equal(0.0)


func test_route_positions_follow_the_path() -> void:
	var path: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)])
	assert_float(BenchmarkStats.path_length(path)).is_equal(20.0)
	var middle: Array = BenchmarkStats.point_along(path, 15.0)
	assert_vector(middle[0]).is_equal_approx(Vector3(10, 0, 5), Vector3(0.001, 0.001, 0.001))
	assert_vector(middle[1]).is_equal_approx(Vector3(0, 0, 1), Vector3(0.001, 0.001, 0.001))
	var past_end: Array = BenchmarkStats.point_along(path, 99.0)
	assert_vector(past_end[0]).is_equal_approx(Vector3(10, 0, 10), Vector3(0.001, 0.001, 0.001))


func test_presets_get_more_expensive_from_low_to_high() -> void:
	var low: Dictionary = SettingsRules.preset(SettingsRules.Quality.LOW)
	var high: Dictionary = SettingsRules.preset(SettingsRules.Quality.HIGH)
	assert_int(int(low["shadow_size"])).is_less(int(high["shadow_size"]))
	assert_bool(low["ssao"]).is_false()
	assert_bool(high["ssao"]).is_true()
	assert_dict(SettingsRules.preset(99)).is_equal(high)


func test_render_scale_is_clamped() -> void:
	assert_float(SettingsRules.clamp_render_scale(0.1)).is_equal(0.5)
	assert_float(SettingsRules.clamp_render_scale(2.0)).is_equal(1.0)
