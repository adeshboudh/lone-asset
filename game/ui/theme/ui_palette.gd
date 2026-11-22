class_name UiPalette
extends Resource
## The colours and sizes of the dark UI theme (data/ui/palette.tres). Change a colour here, run
## `godot --headless --path . -s res://tools/ui/build_theme.gd` and every screen follows (data/ui/lone_asset_theme.tres).

@export_group("Backgrounds")
@export var screen: Color = Color("0b0d0e")
@export var panel: Color = Color("14181a")
@export var slot: Color = Color("1b2022")
@export var overlay: Color = Color(0.04, 0.05, 0.06, 0.82)

@export_group("Glass")
## The thin light edge of a glass window or button.
@export var glass_border: Color = Color(1.0, 1.0, 1.0, 0.16)
## Padding inside a glass window.
@export var glass_pad: int = 16

@export_group("Lines")
@export var border: Color = Color("2b3235")
@export var border_strong: Color = Color("465156")

@export_group("Text")
@export var text: Color = Color("e6e9ea")
@export var text_muted: Color = Color("8a9396")
@export var text_disabled: Color = Color("565e61")

@export_group("Accent")
## Outlines, selection and highlights.
@export var accent: Color = Color("3ddc5f")
@export var accent_dim: Color = Color("1f6b33")
## A faint wash of the accent behind a selected row or hovered button.
@export var accent_wash: Color = Color(0.24, 0.86, 0.37, 0.12)
@export var warning: Color = Color("e0a82e")
@export var danger: Color = Color("d9453d")

@export_group("Sizes")
@export var font_size: int = 18
@export var font_size_small: int = 14
@export var font_size_header: int = 21
@export var font_size_title: int = 38
@export var border_width: int = 1
@export var corner_radius: int = 0
@export var pad_x: int = 12
@export var pad_y: int = 6
