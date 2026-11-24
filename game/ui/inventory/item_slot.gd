class_name ItemSlot
extends GlassButton
## One square cell of the inventory: the item's picture, a count in the corner and, for text-only cells, a short
## caption. Everything else about the item is in the hover box (`tooltip_text`). A cell can be dragged from and
## dropped on. It holds no rules: the screen sets `payload` (what dragging it carries; empty for an empty cell) and
## `target` (what a drop on it means) and the two callables, and the screen asks InventoryMoves.

## Side of a cell in 1920x1080 pixels.
const CELL: float = 72.0
const ICON_MAX: int = 56

## What dragging this slot carries, see InventoryScreen.drop. Empty: nothing to drag.
var payload: Dictionary = {}
## What dropping on this slot means, see InventoryScreen.drop.
var target: Dictionary = {}
## func(payload: Dictionary, target: Dictionary) -> bool
var can_drop: Callable
## func(payload: Dictionary, target: Dictionary) -> void
var on_drop: Callable

var _count: Label
var _caption: Label


func _init() -> void:
	custom_minimum_size = Vector2(CELL, CELL)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_constant_override("icon_max_width", ICON_MAX)
	_caption = Label.new()
	_caption.theme_type_variation = &"SmallLabel"
	_caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_count = Label.new()
	_count.theme_type_variation = &"AccentLabel"
	_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_count.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_count.offset_right = -6.0
	_count.offset_bottom = -2.0
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count)


## Sets what the cell shows: a picture, a count in the corner, a short caption, and the hover text.
func set_cell(picture: Texture2D, count_text: String, caption: String, tip: String) -> void:
	icon = picture
	_count.text = count_text
	_caption.text = caption
	tooltip_text = tip


## The hover box.
static func make_tip(text: String) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.04, 0.96)
	style.border_color = Color(0.45, 0.5, 0.5, 0.9)
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"SmallLabel"
	panel.add_child(label)
	return panel


func _make_custom_tooltip(for_text: String) -> Object:
	return make_tip(for_text)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if payload.is_empty():
		return null
	if icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = icon
		picture.custom_minimum_size = Vector2(CELL, CELL)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		set_drag_preview(picture)
	else:
		var tile: Label = Label.new()
		tile.theme_type_variation = &"AccentLabel"
		tile.text = _caption.text if not _caption.text.is_empty() else tooltip_text.get_slice("\n", 0)
		set_drag_preview(tile)
	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and can_drop.is_valid() and bool(can_drop.call(data, target))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if on_drop.is_valid():
		on_drop.call(data, target)
