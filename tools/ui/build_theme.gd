# SPDX-FileCopyrightText: 2026 Lone Asset contributors
# SPDX-License-Identifier: MIT
extends SceneTree
## Rebuilds data/ui/lone_asset_theme.tres from data/ui/palette.tres:
##   godot --headless --path . -s res://tools/ui/build_theme.gd

const PALETTE_PATH: String = "res://data/ui/palette.tres"
const THEME_PATH: String = "res://data/ui/lone_asset_theme.tres"


func _init() -> void:
	var palette: UiPalette = load(PALETTE_PATH) as UiPalette
	var theme: Theme = UiThemeBuilder.build(palette)
	var error: Error = ResourceSaver.save(theme, THEME_PATH)
	print("THEME ", THEME_PATH, " -> ", error_string(error))
	quit(0 if error == OK else 1)
