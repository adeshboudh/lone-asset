class_name GlassButton
extends Button
## A frosted-glass button with a title and an optional second line (a hint under the title). The accent outline marks
## hover, focus and press; `highlighted` keeps it outlined (the default choice of a menu).

const GLASS: ShaderMaterial = preload("res://data/ui/glass_material.tres")

@export var title: String = "":
	set(value):
		title = value
		_refresh()
@export var subtitle: String = "":
	set(value):
		subtitle = value
		_refresh()
@export var highlighted: bool = false:
	set(value):
		highlighted = value
		theme_type_variation = &"GlassButtonAccent" if value else &"GlassButton"

## Space left of the text (room for an icon).
@export var inset_left: float = 37.0:
	set(value):
		inset_left = value
		if _column != null:
			_column.offset_left = value

var _column: VBoxContainer
var _title_label: Label
var _subtitle_label: Label


func _init() -> void:
	theme_type_variation = &"GlassButton"
	material = GLASS
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	custom_minimum_size = Vector2(0.0, 107.0)
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	var column: VBoxContainer = VBoxContainer.new()
	_column = column
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = inset_left
	column.offset_right = -20.0
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -3)
	add_child(column)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_title_label)
	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = &"MutedLabel"
	_subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_subtitle_label)
	_refresh()


func _refresh() -> void:
	if _title_label == null:
		return
	_title_label.text = title.to_upper()
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
