class_name SettingsPanel
extends CanvasLayer
## Settings screen shared by the title and pause menus. Build once, then open() / close().

signal closed

var _rows: VBoxContainer
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_rows = VBoxContainer.new()
	_rows.custom_minimum_size = Vector2(460.0, 0.0)
	_rows.add_theme_constant_override(&"separation", 10)
	center.add_child(_rows)
	var title: Label = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override(&"font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rows.add_child(title)

	_add_slider("Mouse sensitivity", SettingsRules.SENSITIVITY_MIN, SettingsRules.SENSITIVITY_MAX, 0.05,
		func() -> float: return Settings.mouse_sensitivity_scale,
		func(v: float) -> void: Settings.mouse_sensitivity_scale = v)
	_add_check("Invert vertical look",
		func() -> bool: return Settings.invert_y,
		func(v: bool) -> void: Settings.invert_y = v)
	_add_slider("Field of view", SettingsRules.FOV_MIN, SettingsRules.FOV_MAX, 1.0,
		func() -> float: return Settings.fov_deg,
		func(v: float) -> void: Settings.fov_deg = v)
	_add_option("Graphics quality", ["Low", "Medium", "High"],
		func() -> int: return Settings.quality,
		func(v: int) -> void: Settings.quality = v)
	_add_slider("Render scale", SettingsRules.RENDER_SCALE_MIN, SettingsRules.RENDER_SCALE_MAX, 0.05,
		func() -> float: return Settings.render_scale,
		func(v: float) -> void: Settings.render_scale = v)
	_add_check("Head bob",
		func() -> bool: return Settings.head_bob,
		func(v: bool) -> void: Settings.head_bob = v)
	_add_slider("Master volume", 0.0, 1.0, 0.05,
		func() -> float: return Settings.master_volume,
		func(v: float) -> void: Settings.master_volume = v)
	_add_slider("Music volume", 0.0, 1.0, 0.05,
		func() -> float: return Settings.music_volume,
		func(v: float) -> void: Settings.music_volume = v)
	_add_slider("Effects volume", 0.0, 1.0, 0.05,
		func() -> float: return Settings.sfx_volume,
		func(v: float) -> void: Settings.sfx_volume = v)

	var benchmark_button: Button = Button.new()
	benchmark_button.text = "Run benchmark (60 s)"
	benchmark_button.pressed.connect(func() -> void:
		Audio.play_ui(&"ui_click")
		close()
		Game.start_benchmark())
	_rows.add_child(benchmark_button)

	var folder_button: Button = Button.new()
	folder_button.text = "Open save folder"
	folder_button.pressed.connect(Saves.open_save_folder)
	_rows.add_child(folder_button)

	_back = Button.new()
	_back.text = "Back"
	_back.pressed.connect(func() -> void:
		Audio.play_ui(&"ui_click")
		close())
	_rows.add_child(_back)


func open() -> void:
	visible = true
	_back.grab_focus()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _add_slider(label_text: String, low: float, high: float, step: float, getter: Callable, setter: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = getter.call()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(180.0, 24.0)
	row.add_child(slider)
	var readout: Label = Label.new()
	readout.custom_minimum_size = Vector2(56.0, 0.0)
	readout.text = _format(slider.value, high)
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		readout.text = _format(v, high)
		Settings.commit())
	_rows.add_child(row)


func _add_option(label_text: String, choices: Array[String], getter: Callable, setter: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(200.0, 0.0)
	row.add_child(label)
	var option: OptionButton = OptionButton.new()
	for choice: String in choices:
		option.add_item(choice)
	option.selected = getter.call()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(func(index: int) -> void:
		setter.call(index)
		Settings.commit())
	row.add_child(option)
	_rows.add_child(row)


func _add_check(label_text: String, getter: Callable, setter: Callable) -> void:
	var box: CheckBox = CheckBox.new()
	box.text = label_text
	box.button_pressed = getter.call()
	box.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		Settings.commit())
	_rows.add_child(box)


func _format(value: float, high: float) -> String:
	return "%d%%" % roundi(value * 100.0) if high <= 1.0 else "%.2f" % value if high < 10.0 else "%d" % roundi(value)
