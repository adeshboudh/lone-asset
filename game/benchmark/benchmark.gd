class_name Benchmark
extends Node
## Remote benchmark (design §18.4.1): moves the player along a fixed route through the course for 60 s
## at the minimum-tier settings while the guards react, then reports frame times and system costs.
## Results are saved under user://benchmarks/ and can be copied to the clipboard.

const COURSE_SCENE: PackedScene = preload("res://game/levels/graybox/movement_course.tscn")
const DURATION_S: float = 60.0
const WARMUP_S: float = 2.0
const SAMPLE_INTERVAL_S: float = 0.5
const OUTPUT_DIR: String = "user://benchmarks"
## Minimum-tier settings (design §19.1).
const BENCH_QUALITY: int = SettingsRules.Quality.MEDIUM
const BENCH_RENDER_SCALE: float = 0.75
## Route through the course, x / z at floor level: spawn, compound, north yard, tunnel, range, extraction.
const ROUTE: Array[Vector2] = [
	Vector2(0, 14), Vector2(-8, 10), Vector2(-16, -12), Vector2(-23.8, -17), Vector2(-23.8, -22),
	Vector2(-25, -25), Vector2(-21, -27), Vector2(-23.8, -22), Vector2(-23.8, -17), Vector2(0, -16),
	Vector2(10, -11), Vector2(10, -1), Vector2(18, 4), Vector2(24, 10), Vector2(25, 22), Vector2(6, 22),
	Vector2(0, 14),
]

## Emitted with the report once the run ends.
signal finished(report: Dictionary)

var report: Dictionary = {}
## Run length; tests shorten it.
var duration_s: float = DURATION_S

var _course: Node3D
var _player: Player
var _path: PackedVector3Array = PackedVector3Array()
var _speed: float = 0.0
var _elapsed: float = 0.0
var _frame_ms: PackedFloat32Array = PackedFloat32Array()
var _sample_timer: float = 0.0
var _samples: Dictionary = {"draw_calls": [], "primitives": [], "process_ms": [], "physics_ms": [], "perception_ms": []}
var _static_mem_peak: float = 0.0
var _video_mem_peak: float = 0.0
var _saved_quality: int
var _saved_render_scale: float
var _done: bool = false
var _results: BenchmarkResults


func _ready() -> void:
	# Also when the scene is opened directly (editor, tests): no checkpoints during a run.
	Game.is_benchmark = true
	_saved_quality = Settings.quality
	_saved_render_scale = Settings.render_scale
	Settings.quality = BENCH_QUALITY
	Settings.render_scale = BENCH_RENDER_SCALE
	for point: Vector2 in ROUTE:
		_path.append(Vector3(point.x, 0.05, point.y))
	_speed = BenchmarkStats.path_length(_path) / duration_s
	_course = COURSE_SCENE.instantiate()
	add_child(_course)
	Settings.apply_graphics()
	_player = _course.get_node("Player")
	# The benchmark measures performance, not survival.
	_player.health.max_health = 1.0e9
	_player.health.reset()
	_player.set_scripted_intent(InputIntent.new())
	_results = get_node("Results") as BenchmarkResults
	_results.back_requested.connect(Game.go_to_title)
	Log.info(&"benchmark", "Started: %.0f m route at %.1f m/s" % [BenchmarkStats.path_length(_path), _speed])


func _exit_tree() -> void:
	Settings.quality = _saved_quality
	Settings.render_scale = _saved_render_scale
	Settings.apply_graphics()


func _physics_process(_delta: float) -> void:
	if _done or _player == null:
		return
	var along: Array = BenchmarkStats.point_along(_path, _elapsed * _speed)
	var direction: Vector3 = along[1]
	_player.global_position = along[0]
	_player.velocity = Vector3.ZERO
	if Vector2(direction.x, direction.z).length() > 0.01:
		_player.rotation.y = lerp_angle(_player.rotation.y, atan2(-direction.x, -direction.z), 0.08)


func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed < WARMUP_S:
		return
	_frame_ms.append(delta * 1000.0)
	_sample_timer += delta
	if _sample_timer >= SAMPLE_INTERVAL_S:
		_sample_timer = 0.0
		_sample()
	if _elapsed >= duration_s + WARMUP_S:
		_finish()


func _sample() -> void:
	_samples["draw_calls"].append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_samples["primitives"].append(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	_samples["process_ms"].append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_samples["physics_ms"].append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_samples["perception_ms"].append(PerceptionScheduler.average_ms)
	_static_mem_peak = maxf(_static_mem_peak, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
	_video_mem_peak = maxf(_video_mem_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)


func _finish() -> void:
	_done = true
	var average: float = BenchmarkStats.average_fps(_frame_ms)
	var low: float = BenchmarkStats.low_fps(_frame_ms)
	var window: Vector2i = get_window().size
	report = {
		"build_id": str(ProjectSettings.get_setting("application/config/version")),
		"date_utc": Time.get_datetime_string_from_system(true),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"graphics_api": RenderingServer.get_video_adapter_api_version(),
		"renderer": "%s (%s)" % [RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_driver_name()],
		"resolution": "%dx%d" % [window.x, window.y],
		"settings": {"quality": ["low", "medium", "high"][BENCH_QUALITY], "render_scale": BENCH_RENDER_SCALE},
		"duration_s": duration_s,
		"frames": _frame_ms.size(),
		"average_fps": snappedf(average, 0.1),
		"low_1pct_fps": snappedf(low, 0.1),
		"frame_ms": {
			"p50": snappedf(BenchmarkStats.percentile_ms(_frame_ms, 0.5), 0.01),
			"p95": snappedf(BenchmarkStats.percentile_ms(_frame_ms, 0.95), 0.01),
			"p99": snappedf(BenchmarkStats.percentile_ms(_frame_ms, 0.99), 0.01),
		},
		"histogram": {
			"edges_ms": BenchmarkStats.BUCKET_EDGES_MS,
			"counts": Array(BenchmarkStats.histogram(_frame_ms)),
		},
		"draw_calls": _summary(_samples["draw_calls"]),
		"primitives": _summary(_samples["primitives"]),
		"process_ms": _summary(_samples["process_ms"]),
		"physics_ms": _summary(_samples["physics_ms"]),
		"perception_ms": _summary(_samples["perception_ms"]),
		"static_memory_peak_mb": snappedf(_static_mem_peak, 0.1),
		"video_memory_peak_mb": snappedf(_video_mem_peak, 0.1),
		"passes_minimum_tier": BenchmarkStats.passes(average, low),
	}
	_save()
	Log.info(&"benchmark", "Finished: %.1f FPS average, %.1f FPS 1%% low" % [average, low])
	finished.emit(report)
	Game.end_benchmark()
	_results.show_report(report, report_text())
	if OS.get_cmdline_user_args().has("--quit-when-done"):
		print(report_text())
		get_tree().quit()


func report_text() -> String:
	return JSON.stringify(report, "  ")


func _summary(values: Array) -> Dictionary:
	if values.is_empty():
		return {"avg": 0.0, "max": 0.0}
	var total: float = 0.0
	var most: float = 0.0
	for value: float in values:
		total += value
		most = maxf(most, value)
	return {"avg": snappedf(total / values.size(), 0.01), "max": snappedf(most, 0.01)}


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var stamp: String = Time.get_datetime_string_from_system(true).replace(":", "-")
	var file: FileAccess = FileAccess.open("%s/benchmark_%s.json" % [OUTPUT_DIR, stamp], FileAccess.WRITE)
	if file != null:
		file.store_string(report_text())
