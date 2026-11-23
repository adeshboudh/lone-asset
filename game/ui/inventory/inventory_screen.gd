class_name InventoryScreen
extends CanvasLayer
## The inventory in three frosted-glass panels over the game: EQUIPMENT (the guns in hand and the magazine pouches),
## CHARACTER (portrait, health, free pouch slots) and INVENTORY (loose ammo and the fill / unload actions).
## Spec: docs/superpowers/specs/2026-11-22-inventory-magazines-design.md. It does not pause the game: the world keeps
## running, the mouse is released for the screen and the weapon sees no input (Player). Filling and unloading run in
## real time, one round per MagazineOperation step; only magazines in the pouches can be changed.

signal opened
signal closed

const SETTINGS: InventorySettings = preload("res://data/inventory/inventory_settings.tres")
const PORTRAIT: Texture2D = preload("res://content/ui/portraits/agent_portrait.png")
const ROUND_SOUND: StringName = &"round_load"
const ICON_SIZE: int = 60
const POUCH_COLUMNS: int = 2

var is_open: bool = false

var _player: Player
var _selected: int = -1
var _operation: MagazineOperation
var _gun_list: VBoxContainer
var _pouch_grid: GridContainer
var _pouch_label: Label
var _loose_list: VBoxContainer
var _actions: VBoxContainer
var _progress: ProgressBar
var _progress_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _free_label: Label
var _root: Control


func _ready() -> void:
	# Below the pause menu (layer 10) and the death screen (11): pausing must cover the inventory.
	layer = 5
	visible = false
	_build()
	UiSounds.wire(self)
	Platform.mouse_captured.connect(close)
	EventBus.player_died.connect(close)


func setup(player: Player) -> void:
	_player = player


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or _player == null:
		return
	is_open = true
	_selected = -1
	_operation = null
	visible = true
	Platform.release_mouse()
	_refresh()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_operation = null
	visible = false
	Platform.capture_mouse()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not is_open:
		return
	_health_bar.max_value = _player.health.max_health
	_health_bar.value = _player.health.health
	_health_label.text = "%d / %d" % [ceili(_player.health.health), ceili(_player.health.max_health)]
	if _operation == null:
		return
	var moved: int = _operation.advance(delta, _player.inventory, SETTINGS)
	if moved > 0:
		Audio.play_2d(ROUND_SOUND, &"SFX", 0.0, randf_range(0.95, 1.05))
	if _operation.is_finished(_player.inventory):
		_operation = null
		_refresh()
	elif moved > 0:
		_refresh()
	if _operation != null:
		_progress.value = _operation.fraction(SETTINGS)


# --- Layout -----------------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 67)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margin)
	var page: VBoxContainer = VBoxContainer.new()
	page.add_theme_constant_override("separation", 20)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(page)
	var panels: HBoxContainer = HBoxContainer.new()
	panels.add_theme_constant_override("separation", 33)
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(panels)
	panels.add_child(_equipment_panel())
	panels.add_child(_character_panel())
	panels.add_child(_inventory_panel())
	page.add_child(_key_hints())


func _panel(heading: String, width: float) -> Array:
	var panel: GlassPanel = GlassPanel.new()
	# Wide screens give the panels their ratio; narrow ones shrink them to this minimum.
	panel.custom_minimum_size = Vector2(500.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = width
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 17)
	panel.add_child(box)
	box.add_child(_heading(heading))
	box.add_child(HSeparator.new())
	return [panel, box]


func _heading(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	var marker: ColorRect = ColorRect.new()
	marker.custom_minimum_size = Vector2(17.0, 17.0)
	marker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	marker.color = Color("3ddc5f")
	row.add_child(marker)
	var label: Label = Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.text = text
	row.add_child(label)
	return row


func _equipment_panel() -> Control:
	var made: Array = _panel("EQUIPMENT", 470.0)
	var box: VBoxContainer = made[1]
	var guns_label: Label = Label.new()
	guns_label.theme_type_variation = &"MutedLabel"
	guns_label.text = "IN HAND"
	box.add_child(guns_label)
	_gun_list = VBoxContainer.new()
	_gun_list.add_theme_constant_override("separation", 10)
	box.add_child(_gun_list)
	_pouch_label = Label.new()
	_pouch_label.theme_type_variation = &"MutedLabel"
	box.add_child(_pouch_label)
	_pouch_grid = GridContainer.new()
	_pouch_grid.columns = POUCH_COLUMNS
	_pouch_grid.add_theme_constant_override("h_separation", 13)
	_pouch_grid.add_theme_constant_override("v_separation", 13)
	box.add_child(_pouch_grid)
	return made[0]


func _character_panel() -> Control:
	var made: Array = _panel("CHARACTER", 360.0)
	var box: VBoxContainer = made[1]
	var portrait: TextureRect = TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.custom_minimum_size = Vector2(0.0, 433.0)
	box.add_child(portrait)
	var health_row: HBoxContainer = HBoxContainer.new()
	var health_name: Label = Label.new()
	health_name.theme_type_variation = &"MutedLabel"
	health_name.text = "HEALTH"
	health_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(health_name)
	_health_label = Label.new()
	_health_label.theme_type_variation = &"AccentLabel"
	health_row.add_child(_health_label)
	box.add_child(health_row)
	_health_bar = ProgressBar.new()
	_health_bar.theme_type_variation = &"HealthBar"
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(0.0, 17.0)
	box.add_child(_health_bar)
	_free_label = Label.new()
	_free_label.theme_type_variation = &"MutedLabel"
	box.add_child(_free_label)
	return made[0]


func _inventory_panel() -> Control:
	var made: Array = _panel("INVENTORY", 470.0)
	var box: VBoxContainer = made[1]
	var loose_label: Label = Label.new()
	loose_label.theme_type_variation = &"MutedLabel"
	loose_label.text = "LOOSE AMMO"
	box.add_child(loose_label)
	_loose_list = VBoxContainer.new()
	_loose_list.add_theme_constant_override("separation", 10)
	box.add_child(_loose_list)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(HSeparator.new())
	var actions_label: Label = Label.new()
	actions_label.theme_type_variation = &"MutedLabel"
	actions_label.text = "MAGAZINE"
	box.add_child(actions_label)
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override("separation", 10)
	box.add_child(_actions)
	_progress_label = Label.new()
	box.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0.0, 17.0)
	box.add_child(_progress)
	return made[0]


func _key_hints() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hint: String in ["Click  Select a magazine", "TAB / ESC  Close"]:
		var label: Label = Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = hint
		row.add_child(label)
	return row


# --- Contents ---------------------------------------------------------------------------------------------

func _refresh() -> void:
	var inventory: AmmoInventory = _player.inventory
	_clear(_gun_list)
	for weapon: Weapon in _player.loadout:
		if not weapon.definition.melee:
			_gun_list.add_child(_gun_row(weapon))
	_pouch_label.text = "MAGAZINE POUCHES   %d / %d" % [inventory.pouches.size(), inventory.pouch_count]
	_clear(_pouch_grid)
	for i: int in inventory.pouch_count:
		_pouch_grid.add_child(_pouch_slot(i, inventory))
	_free_label.text = "FREE POUCH SLOTS   %d" % (inventory.pouch_count - inventory.pouches.size())
	_clear(_loose_list)
	var any_loose: bool = false
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		var count: int = inventory.loose_count(ammo.id)
		if count > 0:
			any_loose = true
			_loose_list.add_child(_loose_row(ammo, count))
	if not any_loose:
		var none: Label = Label.new()
		none.theme_type_variation = &"MutedLabel"
		none.text = "No loose ammo"
		_loose_list.add_child(none)
	_refresh_actions()


func _gun_row(weapon: Weapon) -> Control:
	var logic: WeaponLogic = weapon.logic
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"SlotPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	if weapon.definition.icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = weapon.definition.icon
		picture.custom_minimum_size = Vector2(183.0, 73.0)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(picture)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -3)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"HeaderLabel"
	name_label.text = weapon.definition.display_name
	text.add_child(name_label)
	var detail: Label = Label.new()
	detail.theme_type_variation = &"MutedLabel"
	detail.text = _gun_detail(logic)
	text.add_child(detail)
	row.add_child(text)
	var rounds: Label = Label.new()
	rounds.theme_type_variation = &"AccentLabel"
	rounds.text = "%d" % logic.magazine
	row.add_child(rounds)
	return panel


func _gun_detail(logic: WeaponLogic) -> String:
	if logic.inserted == null:
		return "No magazine"
	var ammo: AmmoType = InventoryCatalog.default().find_ammo(logic.inserted.top() if not logic.inserted.is_empty() else logic.chambered)
	return "%s  -  %s%s" % [logic.inserted.type.display_name, ammo.display_name if ammo != null else "empty",
			"  -  chambered" if logic.chambered != &"" else ""]


func _pouch_slot(index: int, inventory: AmmoInventory) -> Control:
	var button: GlassButton = GlassButton.new()
	button.custom_minimum_size = Vector2(0.0, 107.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	if index >= inventory.pouches.size():
		button.title = "Empty"
		button.disabled = true
		return button
	var magazine: Magazine = inventory.pouches[index]
	var ammo: AmmoType = InventoryCatalog.default().find_ammo(magazine.top())
	button.title = "%d / %d" % [magazine.count(), magazine.type.capacity]
	button.subtitle = ammo.display_name if ammo != null else "empty"
	button.icon = magazine.type.icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	button.inset_left = 90.0
	button.set_pressed_no_signal(index == _selected)
	button.pressed.connect(_select.bind(index))
	return button


func _loose_row(ammo: AmmoType, count: int) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.theme_type_variation = &"SlotPanel"
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	panel.add_child(row)
	if ammo.icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = ammo.icon
		picture.custom_minimum_size = Vector2(93.0, 73.0)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(picture)
	var label: Label = Label.new()
	label.text = ammo.display_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var amount: Label = Label.new()
	amount.theme_type_variation = &"AccentLabel"
	amount.text = "x %d" % count
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(amount)
	return panel


func _refresh_actions() -> void:
	_clear(_actions)
	_progress.visible = _operation != null
	_progress_label.visible = _operation != null
	var inventory: AmmoInventory = _player.inventory
	if _selected < 0 or _selected >= inventory.pouches.size():
		var hint: Label = Label.new()
		hint.theme_type_variation = &"MutedLabel"
		hint.text = "Select a magazine to fill or unload it. The game keeps running."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_actions.add_child(hint)
		return
	var magazine: Magazine = inventory.pouches[_selected]
	if _operation != null:
		_progress_label.text = "%s  %s" % ["LOADING" if _operation.kind == MagazineOperation.Kind.FILL else "UNLOADING", magazine.type.display_name]
		_actions.add_child(_action_button("Stop", "", _stop, false))
		return
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		if inventory.loose_count(ammo.id) > 0 and MagazineRules.can_load(magazine, ammo):
			_actions.add_child(_action_button("Fill with %s" % ammo.display_name, "%d loose" % inventory.loose_count(ammo.id),
					_start.bind(MagazineOperation.Kind.FILL, ammo), true))
	if not magazine.is_empty():
		_actions.add_child(_action_button("Unload", "Return the rounds to loose ammo", _start.bind(MagazineOperation.Kind.UNLOAD, null), false))


func _action_button(title: String, subtitle: String, callback: Callable, highlighted: bool) -> GlassButton:
	var button: GlassButton = GlassButton.new()
	button.title = title
	button.subtitle = subtitle
	button.highlighted = highlighted
	button.custom_minimum_size = Vector2(0.0, 87.0 if subtitle.is_empty() else 100.0)
	button.pressed.connect(callback)
	return button


func _select(index: int) -> void:
	_operation = null
	_selected = index
	_refresh()


func _start(kind: MagazineOperation.Kind, ammo: AmmoType) -> void:
	var inventory: AmmoInventory = _player.inventory
	if _selected < 0 or _selected >= inventory.pouches.size():
		return
	_operation = MagazineOperation.new(kind, inventory.pouches[_selected], ammo)
	_progress.value = 0.0
	_refresh()


func _stop() -> void:
	_operation = null
	_refresh()


func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
