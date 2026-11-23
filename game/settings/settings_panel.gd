class_name SettingsPanel
extends CanvasLayer
## Tabbed settings screen shared by the title and pause menus. Build once, then open() / close().

signal closed

var _rows: VBoxContainer
var _tabs: TabContainer
var _tab: VBoxContainer
var _back: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	visible = false
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	# A frosted-glass window over whatever is behind (the title cover, the paused game).
	var window: GlassPanel = GlassPanel.new()
	window.custom_minimum_size = Vector2(933.0, 0.0)
	center.add_child(window)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override(&"separation", 17)
	window.add_child(_rows)
	var title: Label = Label.new()
	title.text = "SETTINGS"
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override(&"font_size", 39)
	_rows.add_child(title)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(0.0, 500.0)
	# The glass shows through the tab page.
	_tabs.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	_rows.add_child(_tabs)

	_begin_tab("Controls")
	_add_slider("Mouse sensitivity", SettingsRules.SENSITIVITY_MIN, SettingsRules.SENSITIVITY_MAX, 0.05,
		func() -> float: return Settings.mouse_sensitivity_scale,
		func(v: float) -> void: Settings.mouse_sensitivity_scale = v)
	_add_check("Invert vertical look",
		func() -> bool: return Settings.invert_y,
		func(v: bool) -> void: Settings.invert_y = v)
	_begin_tab("Video")
	_add_option("Graphics quality", ["Low", "Medium", "High"],
		func() -> int: return Settings.quality,
		func(v: int) -> void: Settings.quality = v)
	_add_slider("Render scale", SettingsRules.RENDER_SCALE_MIN, SettingsRules.RENDER_SCALE_MAX, 0.05,
		func() -> float: return Settings.render_scale,
		func(v: float) -> void: Settings.render_scale = v)
	_add_check("Head bob",
		func() -> bool: return Settings.head_bob,
		func(v: bool) -> void: Settings.head_bob = v)
	_begin_tab("Audio")
	_add_slider("Master volume", 0.0, 1.0, 0.05,
		func() -> float: return Settings.master_volume,
		func(v: float) -> void: Settings.master_volume = v)
	_add_slider("Music volume", 0.0, 1.0, 0.05,
		func() -> float: return Settings.music_volume,
		func(v: float) -> void: Settings.music_volume = v)
	_add_slider("Effects volume", 0.0, 1.0, 0.05,
		func() -> float: return Settings.sfx_volume,
		func(v: float) -> void: Settings.sfx_volume = v)

	_begin_tab("Developer")
	var benchmark_button: Button = Button.new()
	benchmark_button.text = "Run benchmark (60 s)"
	benchmark_button.pressed.connect(func() -> void:
		close()
		Game.start_benchmark())
	_tab.add_child(benchmark_button)

	var folder_button: Button = Button.new()
	folder_button.text = "Open save folder"
	folder_button.pressed.connect(Saves.open_save_folder)
	_tab.add_child(folder_button)

	var back: GlassButton = GlassButton.new()
	back.title = "Back"
	back.custom_minimum_size = Vector2(0.0, 80.0)
	back.highlighted = true
	_back = back
	_back.pressed.connect(close)
	_rows.add_child(_back)
	UiSounds.wire(self)


func open() -> void:
	visible = true
	_tabs.current_tab = 0
	_back.grab_focus()


func close() -> void:
	if visible:
		visible = false
		closed.emit()


func _begin_tab(tab_name: String) -> void:
	_tab = VBoxContainer.new()
	_tab.name = tab_name
	_tab.add_theme_constant_override(&"separation", 17)
	_tabs.add_child(_tab)


func _add_slider(label_text: String, low: float, high: float, step: float, getter: Callable, setter: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(333.0, 0.0)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = getter.call()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(300.0, 40.0)
	row.add_child(slider)
	var readout: Label = Label.new()
	readout.custom_minimum_size = Vector2(93.0, 0.0)
	readout.text = _format(slider.value, high)
	row.add_child(readout)
	slider.value_changed.connect(func(v: float) -> void:
		setter.call(v)
		readout.text = _format(v, high)
		Settings.commit())
	_tab.add_child(row)


func _add_option(label_text: String, choices: Array[String], getter: Callable, setter: Callable) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(333.0, 0.0)
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
	_tab.add_child(row)


func _add_check(label_text: String, getter: Callable, setter: Callable) -> void:
	var box: CheckBox = CheckBox.new()
	box.text = label_text
	box.button_pressed = getter.call()
	box.toggled.connect(func(on: bool) -> void:
		setter.call(on)
		Settings.commit())
	_tab.add_child(box)


func _format(value: float, high: float) -> String:
	return "%d%%" % roundi(value * 100.0) if high <= 1.0 else "%.2f" % value if high < 10.0 else "%d" % roundi(value)
