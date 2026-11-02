extends GdUnitTestSuite
## The benchmark scene: follows its route, keeps the player alive, writes a complete report and
## restores the player's graphics settings. Headless runs have no GPU, so only the plumbing is checked.

const BENCHMARK_SCENE: PackedScene = preload("res://game/benchmark/benchmark.tscn")

var _bench: Benchmark


func after_test() -> void:
	if is_instance_valid(_bench):
		_bench.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	Game.is_benchmark = false
	Saves.delete_checkpoint()


func before_test() -> void:
	Saves.delete_checkpoint()


func test_a_short_run_produces_a_full_report() -> void:
	var quality: int = Settings.quality
	var render_scale: float = Settings.render_scale
	_bench = BENCHMARK_SCENE.instantiate()
	_bench.duration_s = 3.0
	add_child(_bench)
	assert_int(Settings.quality).is_equal(Benchmark.BENCH_QUALITY)
	var player: Player = _bench.get_node("MovementCourse/Player")
	var start: Vector3 = player.global_position
	var reports: Array[Dictionary] = []
	_bench.finished.connect(func(report: Dictionary) -> void: reports.append(report))
	var farthest: float = 0.0
	for i: int in 150:
		await get_tree().create_timer(0.1).timeout
		farthest = maxf(farthest, player.global_position.distance_to(start))
		if not reports.is_empty():
			break
	assert_int(reports.size()).is_equal(1)
	var report: Dictionary = reports[0]
	for key: String in ["build_id", "gpu", "renderer", "average_fps", "low_1pct_fps", "frame_ms", "histogram",
			"draw_calls", "physics_ms", "perception_ms", "passes_minimum_tier"]:
		assert_bool(report.has(key)).override_failure_message("report lacks %s" % key).is_true()
	assert_int(int(report["frames"])).is_greater(10)
	# The route is a loop, so measure the farthest point reached.
	assert_float(farthest).is_greater(10.0)
	assert_bool(player.health.is_dead).is_false()
	assert_bool(Saves.has_checkpoint()).is_false()
	_bench.queue_free()
	await get_tree().process_frame
	assert_int(Settings.quality).is_equal(quality)
	assert_float(Settings.render_scale).is_equal(render_scale)
