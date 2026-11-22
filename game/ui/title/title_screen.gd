extends Control
## Title screen: the cover picture with frosted-glass menu buttons (Continue when a checkpoint exists, New game,
## Settings, Exit), a mission card and a tip line. Built in code from the UI theme (data/ui/lone_asset_theme.tres).

const COVER: Texture2D = preload("res://content/ui/menu/menu_cover.jpg")
const MISSION: MissionDefinition = preload("res://data/missions/m1_prototype.tres")
const TIPS: PackedStringArray = [
	"Use cover and the dark: guards react to light, noise and what they see.",
	"Crouch to move quietly. Doors and walls muffle sound.",
	"Tab opens the inventory. Fill magazines from loose ammo before you move out.",
	"A tactical reload keeps the round in the chamber.",
	"Binoculars tag guards so you can follow them through walls.",
]

static var _benchmark_started: bool = false

var _continue_button: GlassButton
var _play_button: GlassButton
var _settings_button: GlassButton


func _ready() -> void:
	_build()
	_continue_button.visible = Saves.has_checkpoint()
	_play_button.set_meta(UiSounds.META, &"ui_start")
	_continue_button.set_meta(UiSounds.META, &"ui_start")
	var settings: SettingsPanel = SettingsPanel.new()
	add_child(settings)
	_settings_button.pressed.connect(settings.open)
	settings.closed.connect(_settings_button.grab_focus)
	settings.closed.connect(func() -> void: _continue_button.visible = Saves.has_checkpoint())
	(_continue_button if _continue_button.visible else _play_button).grab_focus()
	# After the first focus, so opening the screen is silent. Before the actions, so a click sounds even when the
	# action leaves the screen.
	UiSounds.wire(self)
	_play_button.pressed.connect(Game.start_game)
	_continue_button.pressed.connect(Game.continue_game)
	Game.enter_title()
	if OS.get_cmdline_user_args().has("--benchmark") and not _benchmark_started:
		_benchmark_started = true
		Game.start_benchmark.call_deferred()
	Platform.mark_ready()


func _build() -> void:
	var cover: TextureRect = TextureRect.new()
	cover.texture = COVER
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The dark theme: the picture is dimmed and cooled a little.
	cover.modulate = Color(0.78, 0.84, 0.88)
	add_child(cover)
	add_child(_shade())
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)
	row.add_child(_left_column())
	var gap: Control = Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	row.add_child(_right_column())
	var tip: Label = Label.new()
	tip.theme_type_variation = &"MutedLabel"
	tip.text = "Tip: " + TIPS[randi() % TIPS.size()]
	tip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	tip.position = Vector2(48.0, -44.0)
	add_child(tip)
	var version: Label = Label.new()
	version.theme_type_variation = &"SmallLabel"
	version.text = "build %s" % ProjectSettings.get_setting("application/config/version")
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.position = Vector2(-48.0, -40.0)
	add_child(version)


## Darker toward the left and the bottom, so the menu and the tip stay readable on any picture.
func _shade() -> Control:
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02, 0.03, 0.04, 0.88), Color(0.02, 0.03, 0.04, 0.35), Color(0.02, 0.03, 0.04, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.75])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var shade: TextureRect = TextureRect.new()
	shade.texture = texture
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade


func _left_column() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_theme_constant_override("separation", 10)
	var title: Label = Label.new()
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", 64)
	title.text = "LONE ASSET"
	column.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.theme_type_variation = &"AccentLabel"
	subtitle.text = "TACTICAL STEALTH  -  PROTOTYPE"
	column.add_child(subtitle)
	var space: Control = Control.new()
	space.custom_minimum_size = Vector2(0.0, 36.0)
	column.add_child(space)
	_continue_button = _menu_button("Continue", "Resume from the last checkpoint", true)
	_play_button = _menu_button("New game", "Start the mission from the beginning", false)
	_settings_button = _menu_button("Settings", "Graphics, audio and controls", false)
	var exit_button: GlassButton = _menu_button("Exit", "Quit the game", false)
	exit_button.pressed.connect(func() -> void: get_tree().quit())
	for button: GlassButton in [_continue_button, _play_button, _settings_button, exit_button]:
		column.add_child(button)
	return column


func _menu_button(title: String, subtitle: String, highlighted: bool) -> GlassButton:
	var button: GlassButton = GlassButton.new()
	button.title = title
	button.subtitle = subtitle
	button.highlighted = highlighted
	return button


func _right_column() -> Control:
	var card: GlassPanel = GlassPanel.new()
	card.custom_minimum_size = Vector2(340.0, 0.0)
	card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	var marker: ColorRect = ColorRect.new()
	marker.custom_minimum_size = Vector2(10.0, 10.0)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.color = Color("3ddc5f")
	heading.add_child(marker)
	var heading_label: Label = Label.new()
	heading_label.theme_type_variation = &"HeaderLabel"
	heading_label.text = "CURRENT MISSION"
	heading.add_child(heading_label)
	box.add_child(heading)
	box.add_child(HSeparator.new())
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"HeaderLabel"
	name_label.text = MISSION.display_name
	box.add_child(name_label)
	for objective: ObjectiveDefinition in MISSION.objectives:
		var line: Label = Label.new()
		line.theme_type_variation = &"MutedLabel"
		line.text = "-  " + objective.text
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(line)
	return card
