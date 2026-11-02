class_name BenchmarkResults
extends CanvasLayer
## Result screen of the benchmark: pass / fail, the key numbers and buttons to copy the report.

signal back_requested

var _summary: Label
var _status: Label
var _copy_button: Button
var _report_text: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 13
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(520.0, 0.0)
	box.add_theme_constant_override(&"separation", 10)
	center.add_child(box)
	_status = Label.new()
	_status.add_theme_font_size_override(&"font_size", 32)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	_summary = Label.new()
	box.add_child(_summary)
	_copy_button = Button.new()
	_copy_button.text = "Copy results"
	_copy_button.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_report_text)
		_copy_button.text = "Copied - paste it into a message")
	box.add_child(_copy_button)
	var folder: Button = Button.new()
	folder.text = "Open results folder"
	folder.pressed.connect(func() -> void:
		DirAccess.make_dir_recursive_absolute(Benchmark.OUTPUT_DIR)
		OS.shell_open(ProjectSettings.globalize_path(Benchmark.OUTPUT_DIR)))
	box.add_child(folder)
	var back: Button = Button.new()
	back.text = "Back to title"
	back.pressed.connect(back_requested.emit)
	box.add_child(back)


func show_report(report: Dictionary, text: String) -> void:
	_report_text = text
	var passed: bool = report["passes_minimum_tier"]
	_status.text = "PASS" if passed else "BELOW TARGET"
	_status.modulate = Color(0.4, 1.0, 0.5) if passed else Color(1.0, 0.6, 0.4)
	_summary.text = "\n".join(PackedStringArray([
		"GPU: %s (%s)" % [report["gpu"], report["renderer"]],
		"Resolution: %s, render scale %d%%, %s quality" % [report["resolution"], roundi(report["settings"]["render_scale"] * 100.0), report["settings"]["quality"]],
		"Average: %.1f FPS   (target 60)" % report["average_fps"],
		"1%% low: %.1f FPS   (target 45)" % report["low_1pct_fps"],
		"Frame time p50 / p99: %.1f / %.1f ms" % [report["frame_ms"]["p50"], report["frame_ms"]["p99"]],
		"Draw calls (max): %d" % roundi(report["draw_calls"]["max"]),
	]))
	visible = true
