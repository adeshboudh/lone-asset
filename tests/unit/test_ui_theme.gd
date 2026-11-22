extends GdUnitTestSuite
## The UI theme: built from the palette, saved as the project theme, and in sync with its builder.

const PALETTE: UiPalette = preload("res://data/ui/palette.tres")
const SAVED: Theme = preload("res://data/ui/lone_asset_theme.tres")


func test_the_theme_uses_rajdhani_and_the_palette() -> void:
	var theme: Theme = UiThemeBuilder.build(PALETTE)
	assert_str(theme.default_font.resource_path).contains("Rajdhani")
	assert_bool(theme.get_color("font_color", "Label").is_equal_approx(PALETTE.text)).is_true()
	assert_bool(theme.get_color("font_color", "AccentLabel").is_equal_approx(PALETTE.accent)).is_true()
	var normal: StyleBoxFlat = theme.get_stylebox("normal", "Button") as StyleBoxFlat
	assert_bool(normal.bg_color.is_equal_approx(PALETTE.slot)).is_true()
	assert_bool(normal.border_color.is_equal_approx(PALETTE.border)).is_true()


func test_the_widget_variations_exist() -> void:
	var theme: Theme = UiThemeBuilder.build(PALETTE)
	for variation: StringName in [&"HeaderLabel", &"TitleLabel", &"MutedLabel", &"SmallLabel", &"AccentLabel",
			&"AccentButton", &"SlotPanel", &"OverlayPanel", &"HealthBar", &"WarningBar", &"GlassPanel", &"GlassButton", &"GlassButtonAccent"]:
		assert_str(String(theme.get_type_variation_base(variation))).override_failure_message("no variation %s" % variation).is_not_empty()


func test_accent_outlines_mark_focus_and_selection() -> void:
	var theme: Theme = UiThemeBuilder.build(PALETTE)
	assert_bool((theme.get_stylebox("focus", "Button") as StyleBoxFlat).border_color.is_equal_approx(PALETTE.accent)).is_true()
	assert_bool((theme.get_stylebox("tab_selected", "TabBar") as StyleBoxFlat).border_color.is_equal_approx(PALETTE.accent)).is_true()


func test_the_saved_theme_matches_the_palette() -> void:
	# Fails after a palette edit until tools/ui/build_theme.gd is run again.
	assert_bool(SAVED.get_color("font_color", "Label").is_equal_approx(PALETTE.text)).is_true()
	assert_bool((SAVED.get_stylebox("normal", "Button") as StyleBoxFlat).bg_color.is_equal_approx(PALETTE.slot)).is_true()
	assert_bool((SAVED.get_stylebox("pressed", "AccentButton") as StyleBoxFlat).border_color.is_equal_approx(PALETTE.accent)).is_true()
	assert_int(SAVED.default_font_size).is_equal(PALETTE.font_size)


func test_the_project_uses_the_theme_by_default() -> void:
	assert_str(String(ProjectSettings.get_setting("gui/theme/custom"))).is_equal("res://data/ui/lone_asset_theme.tres")


func test_the_font_files_are_there() -> void:
	for path: String in [UiThemeBuilder.FONT_REGULAR, UiThemeBuilder.FONT_MEDIUM, UiThemeBuilder.FONT_SEMIBOLD, UiThemeBuilder.FONT_BOLD]:
		assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func test_glass_is_a_shader_over_a_nearly_transparent_fill() -> void:
	var material: ShaderMaterial = preload("res://data/ui/glass_material.tres")
	assert_object(material.shader).is_not_null()
	var panel: StyleBoxFlat = SAVED.get_stylebox("panel", "GlassPanel") as StyleBoxFlat
	assert_float(panel.bg_color.a).is_between(0.001, 0.02)
	assert_bool(panel.border_color.is_equal_approx(PALETTE.glass_border)).is_true()
	assert_bool((SAVED.get_stylebox("hover", "GlassButton") as StyleBoxFlat).border_color.is_equal_approx(PALETTE.accent_dim)).is_true()
	assert_bool((SAVED.get_stylebox("normal", "GlassButtonAccent") as StyleBoxFlat).border_color.is_equal_approx(PALETTE.accent)).is_true()


func test_glass_widgets_use_the_glass_material_and_variations() -> void:
	var panel: GlassPanel = auto_free(GlassPanel.new())
	assert_object(panel.material).is_not_null()
	assert_str(String(panel.theme_type_variation)).is_equal("GlassPanel")
	var button: GlassButton = auto_free(GlassButton.new())
	button.title = "Play"
	button.subtitle = "Start"
	assert_object(button.material).is_not_null()
	button.highlighted = true
	assert_str(String(button.theme_type_variation)).is_equal("GlassButtonAccent")
