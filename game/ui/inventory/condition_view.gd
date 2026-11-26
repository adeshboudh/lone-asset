class_name ConditionView
extends VBoxContainer
## The operative's vital HP, bleeding, injuries and stress at the bottom of the operative panel, as short stat
## blocks like the reference. Display only. The hover box says what each block means.

const INJURY_NAMES: Array[String] = ["NONE", "LIGHT", "SEVERE"]
const INJURY_SHORT: Array[String] = ["OK", "LIGHT", "SEVERE"]
const OK_COLOR: Color = Color("3ddc5f")
const WARN_COLOR: Color = Color("e0b030")
const BAD_COLOR: Color = Color("e04b3c")

var _health_bar: ProgressBar
var _values: Dictionary = {}


func _init() -> void:
	add_theme_constant_override("separation", 8)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for key: String in ["hp", "bleed", "arms", "legs", "stress"]:
		row.add_child(_block(key))
	_health_bar = ProgressBar.new()
	_health_bar.theme_type_variation = &"HealthBar"
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0.0, 13.0)
	add_child(_health_bar)


## Shows the current values.
func show_condition(health: HealthComponent, condition: OperativeCondition) -> void:
	_health_bar.max_value = health.max_health
	_health_bar.value = health.health
	var fraction: float = health.health / maxf(health.max_health, 1.0)
	_show("hp", str(ceili(health.health)), BAD_COLOR if fraction < 0.35 else (WARN_COLOR if fraction < 0.7 else OK_COLOR),
			"Vital HP\n%d / %d" % [ceili(health.health), ceili(health.max_health)])
	_show("bleed", "YES" if condition.bleeding else "NO", BAD_COLOR if condition.bleeding else OK_COLOR,
			"Bleeding\n%s" % ("active" if condition.bleeding else "none"))
	_show("arms", INJURY_SHORT[condition.upper_injury], _injury_color(condition.upper_injury),
			"Upper body and arms\n%s" % INJURY_NAMES[condition.upper_injury].to_lower())
	_show("legs", INJURY_SHORT[condition.lower_injury], _injury_color(condition.lower_injury),
			"Legs\n%s" % INJURY_NAMES[condition.lower_injury].to_lower())
	_show("stress", str(roundi(condition.stress)), BAD_COLOR if condition.stress >= 70.0 else (WARN_COLOR if condition.stress >= 35.0 else OK_COLOR),
			"Mental stress\n%d / 100" % roundi(condition.stress))


func _injury_color(level: int) -> Color:
	return [OK_COLOR, WARN_COLOR, BAD_COLOR][level]


func _block(key: String) -> Control:
	var block: TipPanel = TipPanel.new()
	block.theme_type_variation = &"SlotPanel"
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.custom_minimum_size = Vector2(0.0, 78.0)
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", -2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(column)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SmallLabel"
	name_label.text = key.to_upper()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)
	var value: Label = Label.new()
	value.theme_type_variation = &"HeaderLabel"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(value)
	_values[key] = [block, value]
	return block


func _show(key: String, text: String, color: Color, tip: String) -> void:
	var parts: Array = _values[key]
	(parts[1] as Label).text = text
	(parts[1] as Label).add_theme_color_override("font_color", color)
	(parts[0] as Control).tooltip_text = tip
