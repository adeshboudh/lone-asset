class_name UiThemeBuilder
extends RefCounted
## Builds the game's Theme from a UiPalette (pure: no scene access). data/ui/lone_asset_theme.tres is its saved output
## (tools/ui/build_theme.gd) and is the project's default theme, so every Control follows it.
##
## Type variations for the widgets: HeaderLabel, TitleLabel, MutedLabel, SmallLabel, AccentLabel, AccentButton,
## SlotPanel, OverlayPanel, HealthBar, WarningBar, and for glass GlassPanel, GlassButton, GlassButtonAccent.

const FONT_REGULAR: String = "res://content/ui/fonts/Rajdhani-Regular.ttf"
const FONT_MEDIUM: String = "res://content/ui/fonts/Rajdhani-Medium.ttf"
const FONT_SEMIBOLD: String = "res://content/ui/fonts/Rajdhani-SemiBold.ttf"
const FONT_BOLD: String = "res://content/ui/fonts/Rajdhani-Bold.ttf"


static func build(p: UiPalette) -> Theme:
	var theme: Theme = Theme.new()
	var medium: Font = load(FONT_MEDIUM)
	var semibold: Font = load(FONT_SEMIBOLD)
	var bold: Font = load(FONT_BOLD)
	theme.default_font = medium
	theme.default_font_size = p.font_size
	_labels(theme, p, medium, semibold, bold)
	_buttons(theme, p, semibold)
	_panels(theme, p)
	_bars(theme, p)
	_tabs(theme, p, semibold)
	_inputs(theme, p)
	_scrollbars(theme, p)
	_glass(theme, p)
	_icons(theme, p)
	return theme


## A flat box: fill, a border on the chosen sides, no rounding unless the palette asks for it.
static func box(p: UiPalette, fill: Color, line: Color, sides: Array = [1, 1, 1, 1], pad_x: int = -1, pad_y: int = -1) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.border_width_left = p.border_width * int(sides[0])
	style.border_width_top = p.border_width * int(sides[1])
	style.border_width_right = p.border_width * int(sides[2])
	style.border_width_bottom = p.border_width * int(sides[3])
	style.set_corner_radius_all(p.corner_radius)
	style.content_margin_left = p.pad_x if pad_x < 0 else pad_x
	style.content_margin_right = p.pad_x if pad_x < 0 else pad_x
	style.content_margin_top = p.pad_y if pad_y < 0 else pad_y
	style.content_margin_bottom = p.pad_y if pad_y < 0 else pad_y
	return style


static func _labels(theme: Theme, p: UiPalette, medium: Font, semibold: Font, bold: Font) -> void:
	theme.set_color("font_color", "Label", p.text)
	theme.set_font_size("font_size", "Label", p.font_size)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.0))
	_variation(theme, "HeaderLabel", "Label")
	theme.set_font("font", "HeaderLabel", semibold)
	theme.set_font_size("font_size", "HeaderLabel", p.font_size_header)
	_variation(theme, "TitleLabel", "Label")
	theme.set_font("font", "TitleLabel", bold)
	theme.set_font_size("font_size", "TitleLabel", p.font_size_title)
	_variation(theme, "MutedLabel", "Label")
	theme.set_color("font_color", "MutedLabel", p.text_muted)
	_variation(theme, "SmallLabel", "Label")
	theme.set_color("font_color", "SmallLabel", p.text_muted)
	theme.set_font_size("font_size", "SmallLabel", p.font_size_small)
	_variation(theme, "AccentLabel", "Label")
	theme.set_color("font_color", "AccentLabel", p.accent)
	theme.set_font("font", "AccentLabel", medium)


static func _buttons(theme: Theme, p: UiPalette, semibold: Font) -> void:
	for type_name: String in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type_name, box(p, p.slot, p.border))
		theme.set_stylebox("hover", type_name, box(p, p.slot, p.accent_dim))
		theme.set_stylebox("pressed", type_name, box(p, p.accent_wash, p.accent))
		theme.set_stylebox("focus", type_name, box(p, Color(0, 0, 0, 0), p.accent))
		theme.set_stylebox("disabled", type_name, box(p, p.panel, p.border))
		theme.set_color("font_color", type_name, p.text)
		theme.set_color("font_hover_color", type_name, p.text)
		theme.set_color("font_pressed_color", type_name, p.accent)
		theme.set_color("font_focus_color", type_name, p.text)
		theme.set_color("font_disabled_color", type_name, p.text_disabled)
		theme.set_font_size("font_size", type_name, p.font_size)
	_variation(theme, "AccentButton", "Button")
	theme.set_stylebox("normal", "AccentButton", box(p, p.accent_wash, p.accent))
	theme.set_stylebox("hover", "AccentButton", box(p, p.accent_dim, p.accent))
	theme.set_stylebox("pressed", "AccentButton", box(p, p.accent_dim, p.accent))
	theme.set_color("font_color", "AccentButton", p.accent)
	theme.set_color("font_hover_color", "AccentButton", p.text)
	theme.set_font("font", "AccentButton", semibold)
	for type_name: String in ["CheckBox", "CheckButton"]:
		theme.set_color("font_color", type_name, p.text)
		theme.set_color("font_hover_color", type_name, p.text)
		theme.set_color("font_pressed_color", type_name, p.accent)
		theme.set_color("font_focus_color", type_name, p.text)
		theme.set_stylebox("normal", type_name, StyleBoxEmpty.new())
		theme.set_stylebox("hover", type_name, StyleBoxEmpty.new())
		theme.set_stylebox("pressed", type_name, StyleBoxEmpty.new())
		theme.set_stylebox("focus", type_name, box(p, Color(0, 0, 0, 0), p.accent_dim, [1, 1, 1, 1], 2, 2))


static func _panels(theme: Theme, p: UiPalette) -> void:
	for type_name: String in ["Panel", "PanelContainer", "PopupPanel", "TooltipPanel"]:
		theme.set_stylebox("panel", type_name, box(p, p.panel, p.border))
	theme.set_color("font_color", "TooltipLabel", p.text)
	_variation(theme, "SlotPanel", "PanelContainer")
	theme.set_stylebox("panel", "SlotPanel", box(p, p.slot, p.border, [1, 1, 1, 1], 10, 10))
	_variation(theme, "OverlayPanel", "PanelContainer")
	theme.set_stylebox("panel", "OverlayPanel", box(p, p.overlay, p.border))
	theme.set_stylebox("separator", "HSeparator", box(p, p.border, p.border, [0, 0, 0, 0], 0, 0))
	theme.set_stylebox("separator", "VSeparator", box(p, p.border, p.border, [0, 0, 0, 0], 0, 0))
	theme.set_constant("separation", "HSeparator", 13)
	theme.set_constant("separation", "VSeparator", 13)


static func _bars(theme: Theme, p: UiPalette) -> void:
	theme.set_stylebox("background", "ProgressBar", box(p, p.slot, p.border, [1, 1, 1, 1], 0, 0))
	theme.set_stylebox("fill", "ProgressBar", box(p, p.accent, p.accent, [0, 0, 0, 0], 0, 0))
	theme.set_color("font_color", "ProgressBar", p.text)
	_variation(theme, "HealthBar", "ProgressBar")
	theme.set_stylebox("fill", "HealthBar", box(p, p.accent, p.accent, [0, 0, 0, 0], 0, 0))
	_variation(theme, "WarningBar", "ProgressBar")
	theme.set_stylebox("fill", "WarningBar", box(p, p.warning, p.warning, [0, 0, 0, 0], 0, 0))


static func _tabs(theme: Theme, p: UiPalette, semibold: Font) -> void:
	for type_name: String in ["TabContainer", "TabBar"]:
		theme.set_stylebox("tab_selected", type_name, box(p, p.accent_wash, p.accent, [0, 0, 0, 3], 27, 13))
		theme.set_stylebox("tab_unselected", type_name, box(p, Color(0, 0, 0, 0), p.border, [0, 0, 0, 1], 16, 8))
		theme.set_stylebox("tab_hovered", type_name, box(p, Color(0, 0, 0, 0), p.accent_dim, [0, 0, 0, 3], 27, 13))
		theme.set_stylebox("tab_disabled", type_name, box(p, Color(0, 0, 0, 0), p.border, [0, 0, 0, 1], 16, 8))
		theme.set_color("font_selected_color", type_name, p.text)
		theme.set_color("font_unselected_color", type_name, p.text_muted)
		theme.set_color("font_hovered_color", type_name, p.text)
		theme.set_color("font_disabled_color", type_name, p.text_disabled)
		theme.set_font("font", type_name, semibold)
	theme.set_stylebox("panel", "TabContainer", box(p, p.panel, p.border))


static func _inputs(theme: Theme, p: UiPalette) -> void:
	theme.set_stylebox("normal", "LineEdit", box(p, p.slot, p.border))
	theme.set_stylebox("focus", "LineEdit", box(p, p.slot, p.accent))
	theme.set_stylebox("read_only", "LineEdit", box(p, p.panel, p.border))
	theme.set_color("font_color", "LineEdit", p.text)
	theme.set_color("caret_color", "LineEdit", p.accent)
	theme.set_color("selection_color", "LineEdit", p.accent_dim)
	theme.set_stylebox("slider", "HSlider", box(p, p.slot, p.border, [1, 1, 1, 1], 0, 3))
	theme.set_stylebox("grabber_area", "HSlider", box(p, p.accent_dim, p.accent_dim, [0, 0, 0, 0], 0, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", box(p, p.accent, p.accent, [0, 0, 0, 0], 0, 3))


static func _scrollbars(theme: Theme, p: UiPalette) -> void:
	for type_name: String in ["HScrollBar", "VScrollBar"]:
		theme.set_stylebox("scroll", type_name, box(p, p.slot, p.slot, [0, 0, 0, 0], 0, 0))
		theme.set_stylebox("grabber", type_name, box(p, p.border_strong, p.border_strong, [0, 0, 0, 0], 0, 0))
		theme.set_stylebox("grabber_highlight", type_name, box(p, p.accent_dim, p.accent_dim, [0, 0, 0, 0], 0, 0))
		theme.set_stylebox("grabber_pressed", type_name, box(p, p.accent, p.accent, [0, 0, 0, 0], 0, 0))


## Glass windows and buttons: the fill is nearly transparent (alpha above zero so it is drawn) and the glass shader turns
## it into blurred background; borders and washes keep their colour over it.
static func _glass(theme: Theme, p: UiPalette) -> void:
	var clear: Color = Color(0.0, 0.0, 0.0, 0.004)
	_variation(theme, "GlassPanel", "PanelContainer")
	theme.set_stylebox("panel", "GlassPanel", box(p, clear, p.glass_border, [1, 1, 1, 1], p.glass_pad, p.glass_pad))
	for variation: StringName in [&"GlassButton", &"GlassButtonAccent"]:
		_variation(theme, variation, "Button")
		theme.set_stylebox("focus", variation, box(p, Color(0, 0, 0, 0), p.accent))
		theme.set_color("font_color", variation, p.text)
		theme.set_color("font_hover_color", variation, p.text)
	theme.set_stylebox("normal", "GlassButton", box(p, clear, p.glass_border))
	theme.set_stylebox("hover", "GlassButton", box(p, p.accent_wash, p.accent_dim))
	theme.set_stylebox("pressed", "GlassButton", box(p, Color(p.accent.r, p.accent.g, p.accent.b, 0.22), p.accent))
	theme.set_stylebox("disabled", "GlassButton", box(p, Color(0, 0, 0, 0.3), p.border))
	theme.set_stylebox("normal", "GlassButtonAccent", box(p, p.accent_wash, p.accent))
	theme.set_stylebox("hover", "GlassButtonAccent", box(p, Color(p.accent.r, p.accent.g, p.accent.b, 0.2), p.accent))
	theme.set_stylebox("pressed", "GlassButtonAccent", box(p, Color(p.accent.r, p.accent.g, p.accent.b, 0.3), p.accent))
	theme.set_stylebox("disabled", "GlassButtonAccent", box(p, Color(0, 0, 0, 0.3), p.border))


## Check boxes and slider grabbers drawn here (the default icons are white and vanish on a dark panel).
static func _icons(theme: Theme, p: UiPalette) -> void:
	var off: Texture2D = _square(33, p.slot, p.border_strong, Color(0, 0, 0, 0))
	var on: Texture2D = _square(33, p.slot, p.accent, p.accent)
	for type_name: String in ["CheckBox", "CheckButton"]:
		theme.set_icon("unchecked", type_name, off)
		theme.set_icon("checked", type_name, on)
		theme.set_icon("unchecked_disabled", type_name, off)
		theme.set_icon("checked_disabled", type_name, on)
		theme.set_constant("h_separation", type_name, 17)
	var grabber: Texture2D = _square(16, p.accent, p.accent, Color(0, 0, 0, 0))
	var grabber_hot: Texture2D = _square(16, p.text, p.accent, Color(0, 0, 0, 0))
	theme.set_icon("grabber", "HSlider", grabber)
	theme.set_icon("grabber_highlight", "HSlider", grabber_hot)
	theme.set_icon("grabber_disabled", "HSlider", _square(16, p.border_strong, p.border_strong, Color(0, 0, 0, 0)))


## A square icon: filled, with a 3 px border; `mark` fills the inner square when its alpha is above zero.
static func _square(size: int, fill: Color, line: Color, mark: Color) -> ImageTexture:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(fill)
	for i: int in size:
		for t: int in 3:
			image.set_pixel(i, t, line)
			image.set_pixel(i, size - 1 - t, line)
			image.set_pixel(t, i, line)
			image.set_pixel(size - 1 - t, i, line)
	if mark.a > 0.0:
		for x: int in range(8, size - 8):
			for y: int in range(8, size - 8):
				image.set_pixel(x, y, mark)
	return ImageTexture.create_from_image(image)


static func _variation(theme: Theme, variation: StringName, base: StringName) -> void:
	theme.set_type_variation(variation, base)
