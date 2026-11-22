class_name InventoryScreen
extends CanvasLayer
## The inventory: magazine pouches, loose ammo and the guns in hand (docs/superpowers/specs/2026-11-22-inventory-magazines-design.md).
## It does not pause the game: the world keeps running, the mouse is released for the screen and the weapon sees no
## input (Player). Filling and unloading run in real time, one round per MagazineOperation step; only magazines in the
## pouches can be changed.

signal opened
signal closed

const SETTINGS: InventorySettings = preload("res://data/inventory/inventory_settings.tres")
const ROUND_SOUND: StringName = &"round_load"
const ICON_SIZE: int = 40

var is_open: bool = false

var _player: Player
var _selected: int = -1
var _operation: MagazineOperation
var _magazine_list: VBoxContainer
var _loose_list: VBoxContainer
var _gun_list: VBoxContainer
var _actions: VBoxContainer
var _progress: ProgressBar
var _progress_label: Label
var _root: Control


func _ready() -> void:
	layer = 20
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


func _process(_delta: float) -> void:
	if not is_open or _operation == null:
		return
	var moved: int = _operation.advance(_delta, _player.inventory, SETTINGS)
	if moved > 0:
		Audio.play_2d(ROUND_SOUND, &"SFX", 0.0, randf_range(0.95, 1.05))
	if _operation.is_finished(_player.inventory):
		_operation = null
		_refresh()
	elif moved > 0:
		_refresh()
	if _operation != null:
		_progress.value = _operation.fraction(SETTINGS)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(960.0, 520.0)
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title: Label = Label.new()
	title.text = "INVENTORY   (Tab or Esc to close)"
	column.add_child(title)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(columns)
	_magazine_list = _section(columns, "MAGAZINES")
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	columns.add_child(right)
	_loose_list = _section(right, "LOOSE AMMO")
	_gun_list = _section(right, "IN HAND")
	_actions = VBoxContainer.new()
	column.add_child(_actions)
	_progress_label = Label.new()
	column.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	column.add_child(_progress)


func _section(parent: Control, heading: String) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var label: Label = Label.new()
	label.text = heading
	box.add_child(label)
	var list: VBoxContainer = VBoxContainer.new()
	box.add_child(list)
	return list


func _refresh() -> void:
	var inventory: AmmoInventory = _player.inventory
	_clear(_magazine_list)
	for i: int in inventory.pouch_count:
		_magazine_list.add_child(_pouch_row(i, inventory))
	_clear(_loose_list)
	var catalog: InventoryCatalog = InventoryCatalog.default()
	var any_loose: bool = false
	for ammo: AmmoType in catalog.ammo:
		var count: int = inventory.loose_count(ammo.id)
		if count > 0:
			any_loose = true
			var label: Label = Label.new()
			label.text = "%s   x %d" % [ammo.display_name, count]
			_loose_list.add_child(label)
	if not any_loose:
		var none: Label = Label.new()
		none.text = "none"
		_loose_list.add_child(none)
	_clear(_gun_list)
	for weapon: Weapon in _player.loadout:
		if weapon.definition.melee:
			continue
		var gun: Label = Label.new()
		gun.text = _gun_text(weapon)
		_gun_list.add_child(gun)
	_refresh_actions()


func _pouch_row(index: int, inventory: AmmoInventory) -> Button:
	var button: Button = Button.new()
	button.toggle_mode = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", ICON_SIZE)
	if index >= inventory.pouches.size():
		button.text = "empty slot"
		button.disabled = true
		return button
	var magazine: Magazine = inventory.pouches[index]
	var ammo: AmmoType = InventoryCatalog.default().find_ammo(magazine.top())
	button.icon = magazine.type.icon
	button.text = "%s   %d / %d   %s" % [magazine.type.display_name, magazine.count(), magazine.type.capacity,
			ammo.display_name if ammo != null else "empty"]
	button.set_pressed_no_signal(index == _selected)
	button.pressed.connect(_select.bind(index))
	return button


func _gun_text(weapon: Weapon) -> String:
	var logic: WeaponLogic = weapon.logic
	var in_gun: String = "no magazine"
	if logic.inserted != null:
		var ammo: AmmoType = InventoryCatalog.default().find_ammo(logic.inserted.top() if not logic.inserted.is_empty() else logic.chambered)
		in_gun = "%s %d%s" % [logic.inserted.type.display_name, logic.inserted.count(), ", " + ammo.display_name if ammo != null else ""]
	return "%s:  %d rounds  (%s, chamber %s)" % [weapon.definition.display_name, logic.magazine, in_gun, "loaded" if logic.chambered != &"" else "empty"]


func _refresh_actions() -> void:
	_clear(_actions)
	_progress.visible = _operation != null
	_progress_label.visible = _operation != null
	var inventory: AmmoInventory = _player.inventory
	if _selected < 0 or _selected >= inventory.pouches.size():
		var hint: Label = Label.new()
		hint.text = "Select a magazine to fill or unload it. The game keeps running."
		_actions.add_child(hint)
		return
	var magazine: Magazine = inventory.pouches[_selected]
	if _operation != null:
		_progress_label.text = "%s: %s" % ["Loading" if _operation.kind == MagazineOperation.Kind.FILL else "Unloading", magazine.type.display_name]
		var stop: Button = Button.new()
		stop.text = "Stop"
		stop.pressed.connect(_stop)
		_actions.add_child(stop)
		return
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		if inventory.loose_count(ammo.id) > 0 and MagazineRules.can_load(magazine, ammo):
			var fill: Button = Button.new()
			fill.text = "Fill with %s  (%d loose)" % [ammo.display_name, inventory.loose_count(ammo.id)]
			fill.pressed.connect(_start.bind(MagazineOperation.Kind.FILL, ammo))
			_actions.add_child(fill)
	if not magazine.is_empty():
		var unload: Button = Button.new()
		unload.text = "Unload"
		unload.pressed.connect(_start.bind(MagazineOperation.Kind.UNLOAD, null))
		_actions.add_child(unload)


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
