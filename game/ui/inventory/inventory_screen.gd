class_name InventoryScreen
extends CanvasLayer
## The inventory in frosted-glass panels over the game. Left: an external container (crate, locker, fallen guard),
## shown only while one is open. Middle: the operative (condition) and the weapons in hand. Right: the tactical rig,
## the backpack and loose ammo. The middle and right panels never move; the container panel has its own reserved
## place. Items are dragged: a rig magazine onto a gun reloads it, loose rounds onto a magazine pack it, magazines
## and rounds move between rig, backpack and container, a magazine onto UNLOAD strips its rounds.
## Spec: docs/superpowers/specs/2026-11-25-inventory-three-panel-design.md. The game is not paused: the mouse is
## released for the screen, the player can still walk, but the weapon, binoculars and weapon keys get no input
## (Player). Packing and unloading run in real time, one round per MagazineOperation step.

signal opened
signal closed
signal container_closed

const SETTINGS: InventorySettings = preload("res://data/inventory/inventory_settings.tres")
const ROUND_SOUND: StringName = &"round_load"
const PANEL_WIDTH: float = 560.0
## Cells per row in every grid: 6 cells of ItemSlot.CELL and the gaps fill a panel.
const GRID_COLUMNS: int = 6
const GRID_GAP: int = 8
const GUN_CARD_HEIGHT: float = 150.0
const MAX_CONTAINER_DISTANCE_M: float = 3.0
const MESSAGE_TIME_S: float = 2.5
const ACCENT: Color = Color("3ddc5f")

var is_open: bool = false

var _player: Player
var _store: LootStore
var _anchor: Node3D
var _operation: MagazineOperation
var _operation_source: LooseAmmoStore
var _message_remaining: float = 0.0
var _root: Control
var _container_panel: Control
var _container_heading: Label
var _container_box: VBoxContainer
var _condition_view: ConditionView
var _gun_list: VBoxContainer
var _rig_label: Label
var _rig_grid: GridContainer
var _backpack_label: Label
var _backpack_grid: GridContainer
var _unload_slot: ItemSlot
var _progress: ProgressBar
var _progress_label: Label
var _message: Label


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
	_operation = null
	visible = true
	Platform.release_mouse()
	_refresh()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	close_container()
	is_open = false
	_operation = null
	visible = false
	Platform.capture_mouse()
	closed.emit()


## Shows the container panel on the left (and opens the screen when it is closed). `anchor` is where the container
## is: walking more than MAX_CONTAINER_DISTANCE_M away closes the panel.
func open_container(store: LootStore, title: String, anchor: Node3D = null) -> void:
	_store = store
	_anchor = anchor
	_container_heading.text = title.to_upper()
	_container_panel.visible = true
	if not is_open:
		open()
	else:
		_refresh()


func close_container() -> void:
	if _store == null:
		return
	# A packing or unloading on the container's own rounds stops with it.
	if _operation_source == _store:
		_operation = null
	_store = null
	_anchor = null
	_container_panel.visible = false
	container_closed.emit()
	if is_open:
		_refresh()


func has_container() -> bool:
	return _store != null


func _unhandled_input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not is_open:
		return
	_condition_view.show_condition(_player.health, _player.condition)
	if _message_remaining > 0.0:
		_message_remaining -= delta
		if _message_remaining <= 0.0:
			_message.text = ""
	if _anchor != null and is_instance_valid(_anchor) \
			and _player.global_position.distance_to(_anchor.global_position) > MAX_CONTAINER_DISTANCE_M:
		close_container()
	if _operation == null:
		return
	var moved: int = _operation.advance(delta, _operation_source, SETTINGS)
	if moved > 0:
		Audio.play_2d(ROUND_SOUND, &"SFX", 0.0, randf_range(0.95, 1.05))
	if _operation.is_finished(_operation_source):
		if _operation.blocked:
			_say("NO ROOM IN THE BACKPACK")
		_operation = null
		_refresh()
	elif moved > 0:
		_refresh()
	if _operation != null:
		_progress.value = _operation.fraction(SETTINGS)


# --- Dropping ---------------------------------------------------------------------------------------------
# A payload is what a slot offers when dragged:
#   {"kind": "magazine", "place": InventoryMoves.Place, "index": int}
#   {"kind": "loose", "place": BACKPACK or CONTAINER, "ammo_id": String}
#   {"kind": "attachment", "weapon": loadout index}
# A target is what a slot or area means when dropped on:
#   {"kind": "slot", "place": Place, "index": int}  (index -1: an empty cell)
#   {"kind": "zone", "place": Place}                (a panel area)
#   {"kind": "gun", "weapon": loadout index}
#   {"kind": "unload"}

## Whether the target takes this kind of item at all. Rule refusals (a full rig, the wrong caliber) are not decided
## here: a drop that is refused shows its reason as a message.
func can_drop(payload: Dictionary, target: Dictionary) -> bool:
	match String(payload.get("kind", "")):
		"magazine":
			return ["slot", "zone", "gun", "unload"].has(String(target.get("kind", "")))
		"loose":
			var on_magazine: bool = String(target.get("kind", "")) == "slot" and int(target.get("index", -1)) >= 0
			return on_magazine or String(target.get("kind", "")) == "zone"
		"attachment":
			return String(target.get("kind", "")) == "gun" and int(target.get("weapon", -1)) == int(payload.get("weapon", -2))
	return false


## Does what dropping `payload` on `target` means, or shows why not.
func drop(payload: Dictionary, target: Dictionary) -> void:
	if _player == null or not can_drop(payload, target):
		return
	var plan: Dictionary = _plan(payload, target)
	if bool(plan["ok"]):
		(plan["apply"] as Callable).call()
		_refresh()
		return
	var text: String = String(plan.get("text", ""))
	if text.is_empty():
		text = InventoryMoves.reason_text(StringName(plan.get("reason", &"")))
	if not text.is_empty():
		_say(text)


## {"ok", "reason", "apply" (a Callable, only when ok), "text" (a message that replaces the reason's)}. Nothing
## changes until `apply` is called.
func _plan(payload: Dictionary, target: Dictionary) -> Dictionary:
	match String(payload["kind"]):
		"magazine":
			return _plan_magazine(payload, target)
		"loose":
			return _plan_loose(payload, target)
		"attachment":
			var weapon: Weapon = _weapon_at(int(payload["weapon"]))
			if weapon == null or not weapon.toggle_variant_allowed():
				return {"ok": false, "reason": &"wrong_fit", "text": "CANNOT CHANGE IT NOW"}
			return {"ok": true, "apply": weapon.toggle_variant}
	return {"ok": false, "reason": &"wrong_fit"}


func _plan_magazine(payload: Dictionary, target: Dictionary) -> Dictionary:
	var place: InventoryMoves.Place = int(payload["place"]) as InventoryMoves.Place
	var index: int = int(payload["index"])
	var magazine: Magazine = _magazine_at(place, index)
	if magazine == null:
		return {"ok": false, "reason": &"empty"}
	match String(target["kind"]):
		"slot", "zone":
			var to_place: InventoryMoves.Place = int(target["place"]) as InventoryMoves.Place
			var check: Dictionary = InventoryMoves.can_move_magazine(_player.inventory, _store, place, index, to_place)
			if not check["ok"]:
				return check
			return {"ok": true, "apply": func() -> void: InventoryMoves.move_magazine(_player.inventory, _store, place, index, to_place)}
		"gun":
			var check: Dictionary = InventoryMoves.can_reload_from(place)
			if not check["ok"]:
				return check
			var weapon: Weapon = _weapon_at(int(target["weapon"]))
			if weapon == null or not weapon.visible or weapon.definition.melee:
				return {"ok": false, "reason": &"wrong_fit", "text": "TAKE THAT GUN IN HAND FIRST"}
			if not MagazineRules.can_insert(weapon.definition, magazine):
				return {"ok": false, "reason": &"wrong_fit"}
			return {"ok": true, "apply": func() -> void:
				if not weapon.request_reload_with(index):
					_say(_reload_refusal(weapon.logic.reload_block))}
		"unload":
			if magazine.is_empty():
				return {"ok": false, "reason": &"empty"}
			if _operation != null:
				return {"ok": false, "reason": &"full", "text": "BUSY"}
			var source: LooseAmmoStore = _store if place == InventoryMoves.Place.CONTAINER else _player.inventory
			return {"ok": true, "apply": func() -> void: _start_operation(MagazineOperation.Kind.UNLOAD, magazine, null, source)}
	return {"ok": false, "reason": &"wrong_fit"}


func _plan_loose(payload: Dictionary, target: Dictionary) -> Dictionary:
	var from_place: InventoryMoves.Place = int(payload["place"]) as InventoryMoves.Place
	var ammo: AmmoType = InventoryCatalog.default().find_ammo(StringName(String(payload["ammo_id"])))
	var source: LooseAmmoStore = _store if from_place == InventoryMoves.Place.CONTAINER else _player.inventory
	if ammo == null or source == null or source.loose_count(ammo.id) < 1:
		return {"ok": false, "reason": &"empty"}
	if String(target["kind"]) == "zone":
		var to_place: InventoryMoves.Place = int(target["place"]) as InventoryMoves.Place
		if to_place == from_place:
			return {"ok": false, "reason": &"same_slot"}
		var amount: int = mini(int(payload.get("count", 1 << 30)), source.loose_count(ammo.id))
		var check: Dictionary = InventoryMoves.can_move_loose(_player.inventory, _store, ammo.id, to_place, amount)
		if not check["ok"]:
			return {"ok": false, "reason": check["reason"], "text": "NO ROOM IN THE BACKPACK" if check["reason"] == &"full" else ""}
		return {"ok": true, "apply": func() -> void: InventoryMoves.move_loose(_player.inventory, _store, ammo.id, amount, to_place)}
	var magazine: Magazine = _magazine_at(int(target["place"]) as InventoryMoves.Place, int(target["index"]))
	if magazine == null:
		return {"ok": false, "reason": &"empty"}
	var pack: Dictionary = InventoryMoves.can_pack(magazine, ammo)
	if not pack["ok"]:
		return pack
	if _operation != null:
		return {"ok": false, "reason": &"full", "text": "BUSY"}
	return {"ok": true, "apply": func() -> void: _start_operation(MagazineOperation.Kind.FILL, magazine, ammo, source)}


func _reload_refusal(reason: StringName) -> String:
	match reason:
		&"full":
			return "THE GUN IS FULL"
		&"wrong_fit":
			return "DOES NOT FIT"
		&"no_magazine":
			return "NO MAGAZINE"
	return "CANNOT RELOAD NOW"


func _start_operation(kind: MagazineOperation.Kind, magazine: Magazine, ammo: AmmoType, source: LooseAmmoStore) -> void:
	_operation = MagazineOperation.new(kind, magazine, ammo)
	_operation_source = source
	_progress.value = 0.0
	_progress_label.text = ("PACKING %s" % ammo.display_name) if kind == MagazineOperation.Kind.FILL else "UNLOADING"


func _magazine_at(place: InventoryMoves.Place, index: int) -> Magazine:
	var list: Array[Magazine] = []
	match place:
		InventoryMoves.Place.RIG:
			list = _player.inventory.pouches
		InventoryMoves.Place.BACKPACK:
			list = _player.inventory.backpack
		InventoryMoves.Place.CONTAINER:
			list = _store.magazines if _store != null else list
	return list[index] if index >= 0 and index < list.size() else null


func _weapon_at(index: int) -> Weapon:
	var guns: Array[Weapon] = _player.loadout
	return guns[index] if index >= 0 and index < guns.size() else null


func _say(text: String) -> void:
	_message.text = text
	_message_remaining = MESSAGE_TIME_S
	EventBus.toast_requested.emit(text)


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
	panels.alignment = BoxContainer.ALIGNMENT_END
	panels.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(panels)
	# The container panel has a place of its own that stays reserved while it is hidden, so the other two never move.
	var reserved: Control = Control.new()
	reserved.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	reserved.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panels.add_child(reserved)
	reserved.add_child(_build_container_panel())
	panels.add_child(_build_operative_panel())
	panels.add_child(_build_rig_panel())
	page.add_child(_build_hints())


func _panel(heading: String) -> Array:
	var panel: GlassPanel = GlassPanel.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 13)
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
	marker.color = ACCENT
	row.add_child(marker)
	var label: Label = Label.new()
	label.theme_type_variation = &"HeaderLabel"
	label.text = text
	row.add_child(label)
	return row


func _muted(text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.text = text
	return label


func _build_container_panel() -> Control:
	var made: Array = _panel("CONTAINER")
	_container_panel = made[0]
	_container_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container_panel.visible = false
	_container_box = made[1]
	_container_heading = ((_container_box.get_child(0) as HBoxContainer).get_child(1)) as Label
	_zone(_container_box, {"kind": "zone", "place": InventoryMoves.Place.CONTAINER})
	return _container_panel


## Top: the primary and secondary gun cards with the knife and binoculars. Bottom: the operative's vitals.
func _build_operative_panel() -> Control:
	var made: Array = _panel("OPERATIVE")
	var box: VBoxContainer = made[1]
	_gun_list = VBoxContainer.new()
	_gun_list.add_theme_constant_override("separation", GRID_GAP)
	box.add_child(_gun_list)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(HSeparator.new())
	box.add_child(_muted("VITALS"))
	_condition_view = ConditionView.new()
	box.add_child(_condition_view)
	return made[0]


func _build_rig_panel() -> Control:
	var made: Array = _panel("BODY AND BACKPACK")
	var box: VBoxContainer = made[1]
	_zone(box, {"kind": "zone", "place": InventoryMoves.Place.BACKPACK})
	_rig_label = _muted("")
	box.add_child(_rig_label)
	_rig_grid = _grid()
	_zone(_rig_grid, {"kind": "zone", "place": InventoryMoves.Place.RIG})
	box.add_child(_rig_grid)
	_backpack_label = _muted("")
	box.add_child(_backpack_label)
	_backpack_grid = _grid()
	box.add_child(_backpack_grid)
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_unload_slot = _slot()
	_unload_slot.custom_minimum_size = Vector2(0.0, 52.0)
	_unload_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unload_slot.set_cell(null, "", "UNLOAD", "Unload\nDrop a magazine here to take its rounds out")
	_unload_slot.target = {"kind": "unload"}
	box.add_child(_unload_slot)
	_progress_label = _muted("")
	box.add_child(_progress_label)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0.0, 13.0)
	box.add_child(_progress)
	return made[0]


func _build_hints() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message = Label.new()
	_message.theme_type_variation = &"AccentLabel"
	_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_message)
	for hint: String in ["Drag  Move, pack and reload", "R  Reloads from the rig only", "TAB / ESC  Close"]:
		var label: Label = Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.text = hint
		row.add_child(label)
	return row


func _grid() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", GRID_GAP)
	grid.add_theme_constant_override("v_separation", GRID_GAP)
	return grid


## Makes an area a drop target for `target`.
func _zone(control: Control, target: Dictionary) -> void:
	control.set_drag_forwarding(Callable(),
			func(_at: Vector2, data: Variant) -> bool: return data is Dictionary and can_drop(data, target),
			func(_at: Vector2, data: Variant) -> void: drop(data, target))


func _slot() -> ItemSlot:
	var slot: ItemSlot = ItemSlot.new()
	slot.can_drop = can_drop
	slot.on_drop = drop
	return slot


# --- Contents ---------------------------------------------------------------------------------------------

func _refresh() -> void:
	var inventory: AmmoInventory = _player.inventory
	_condition_view.show_condition(_player.health, _player.condition)
	_clear(_gun_list)
	var guns: Array[int] = []
	var loadout: Array[Weapon] = _player.loadout
	for i: int in loadout.size():
		if not loadout[i].definition.melee:
			guns.append(i)
	_gun_list.add_child(_gun_card("PRIMARY", guns[0] if guns.size() > 0 else -1))
	var second_row: HBoxContainer = HBoxContainer.new()
	second_row.add_theme_constant_override("separation", GRID_GAP)
	second_row.add_child(_gun_card("SECONDARY", guns[1] if guns.size() > 1 else -1))
	var side: VBoxContainer = VBoxContainer.new()
	side.add_theme_constant_override("separation", GRID_GAP)
	side.add_child(_gear_cell("KNIFE", "Combat knife\nnot carried"))
	side.add_child(_gear_cell("BINOC", "Binoculars\ncarried (B)"))
	second_row.add_child(side)
	_gun_list.add_child(second_row)
	_rig_label.text = "MAGAZINE SLOTS ON THE BODY   %d / %d" % [inventory.pouches.size(), inventory.pouch_count]
	_fill_grid(_rig_grid, InventoryMoves.Place.RIG, inventory.pouches, inventory.pouch_count)
	_backpack_label.text = "BACKPACK   %d / %d SLOTS" % [inventory.slots_used(), inventory.backpack_capacity]
	_fill_backpack(inventory)
	if _store != null:
		_refresh_container()
	_progress.visible = _operation != null
	_progress_label.visible = _operation != null


func _refresh_container() -> void:
	# Keep the heading and its separator; rebuild the rest.
	while _container_box.get_child_count() > 2:
		var child: Node = _container_box.get_child(2)
		_container_box.remove_child(child)
		child.queue_free()
	_container_box.add_child(_muted("MAGAZINES   %d / %d" % [_store.magazines.size(), _store.capacity]))
	var grid: GridContainer = _grid()
	_container_box.add_child(grid)
	_fill_grid(grid, InventoryMoves.Place.CONTAINER, _store.magazines, _store.capacity)
	_container_box.add_child(_muted("LOOSE AMMO AND ITEMS" if not (_store.loose.is_empty() and _store.items.is_empty()) else "LOOSE AMMO AND ITEMS   none"))
	var loose: GridContainer = _grid()
	_container_box.add_child(loose)
	_fill_loose(loose, InventoryMoves.Place.CONTAINER, _store)
	for id: Variant in _store.items:
		var cell: ItemSlot = _slot()
		var name_text: String = String(id).replace("_", " ")
		cell.set_cell(null, str(int(_store.items[id])), name_text.substr(0, 3).to_upper(), "%s\nx %d" % [name_text.capitalize(), int(_store.items[id])])
		loose.add_child(cell)


func _fill_grid(grid: GridContainer, place: InventoryMoves.Place, magazines: Array[Magazine], capacity: int) -> void:
	_clear(grid)
	for i: int in capacity:
		grid.add_child(_magazine_slot(place, i, magazines[i] if i < magazines.size() else null))


func _magazine_slot(place: InventoryMoves.Place, index: int, magazine: Magazine) -> ItemSlot:
	var slot: ItemSlot = _slot()
	if magazine == null:
		slot.set_cell(null, "", "", "Empty slot")
		slot.target = {"kind": "slot", "place": place, "index": -1}
		return slot
	slot.set_cell(magazine.type.icon, str(magazine.count()), "" if magazine.type.icon != null else "MAG", _magazine_tip(magazine))
	slot.payload = {"kind": "magazine", "place": place, "index": index}
	slot.target = {"kind": "slot", "place": place, "index": index}
	return slot


## The hover text of a magazine: its type, how full it is and which rounds are in it, top round first.
func _magazine_tip(magazine: Magazine) -> String:
	var catalog: InventoryCatalog = InventoryCatalog.default()
	var lines: PackedStringArray = [magazine.type.display_name, "%d / %d rounds" % [magazine.count(), magazine.type.capacity]]
	var counts: Dictionary = {}
	var order: Array[StringName] = []
	for i: int in range(magazine.rounds.size() - 1, -1, -1):
		var id: StringName = magazine.rounds[i]
		if not counts.has(id):
			order.append(id)
		counts[id] = int(counts.get(id, 0)) + 1
	for id: StringName in order:
		var ammo: AmmoType = catalog.find_ammo(id)
		lines.append("%s x %d" % [ammo.display_name if ammo != null else String(id), int(counts[id])])
	if order.size() > 1:
		lines.append("Mixed: the top round fires first")
	return "\n".join(lines)


## The backpack's slots: its magazines first, then loose ammo (a cell per started stack, AmmoType.stack_size rounds
## each), then empty cells. Dragging a loose cell carries that cell's rounds.
func _fill_backpack(inventory: AmmoInventory) -> void:
	_clear(_backpack_grid)
	for i: int in inventory.backpack.size():
		_backpack_grid.add_child(_magazine_slot(InventoryMoves.Place.BACKPACK, i, inventory.backpack[i]))
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		var left: int = inventory.loose_count(ammo.id)
		while left > 0 and _backpack_grid.get_child_count() < inventory.backpack_capacity + 6:
			var in_cell: int = mini(left, ammo.stack_size)
			left -= in_cell
			var cell: ItemSlot = _slot()
			cell.set_cell(ammo.icon, str(in_cell), "" if ammo.icon != null else "AMMO",
					"%s\n%d loose rounds in this slot (%d in all)\nDrag onto a magazine to pack it" % [ammo.display_name, in_cell, inventory.loose_count(ammo.id)])
			cell.payload = {"kind": "loose", "place": InventoryMoves.Place.BACKPACK, "ammo_id": String(ammo.id), "count": in_cell}
			_backpack_grid.add_child(cell)
	while _backpack_grid.get_child_count() < inventory.backpack_capacity:
		var empty: ItemSlot = _slot()
		empty.set_cell(null, "", "", "Empty slot")
		empty.target = {"kind": "slot", "place": InventoryMoves.Place.BACKPACK, "index": -1}
		_backpack_grid.add_child(empty)


## One cell per kind of loose ammo (picture and count) in a container.
func _fill_loose(grid: GridContainer, place: InventoryMoves.Place, source: LooseAmmoStore) -> void:
	_clear(grid)
	for ammo: AmmoType in InventoryCatalog.default().ammo:
		var count: int = source.loose_count(ammo.id)
		if count < 1:
			continue
		var cell: ItemSlot = _slot()
		cell.set_cell(ammo.icon, str(count), "" if ammo.icon != null else "AMMO", "%s\n%d loose rounds\nDrag onto a magazine to pack it" % [ammo.display_name, count])
		cell.payload = {"kind": "loose", "place": place, "ammo_id": String(ammo.id)}
		grid.add_child(cell)


## A gun card: its picture, rounds as "in magazine + chambered" and the attachment cell. `index` is the loadout index,
## -1 for an empty slot. Everything but the role is in the hover box.
func _gun_card(role: String, index: int) -> Control:
	var weapon: Weapon = _weapon_at(index)
	var card: TipPanel = TipPanel.new()
	card.theme_type_variation = &"SlotPanel"
	card.custom_minimum_size = Vector2(0.0, GUN_CARD_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var role_label: Label = Label.new()
	role_label.theme_type_variation = &"MutedLabel"
	role_label.text = role
	role_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	role_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if weapon == null:
		card.tooltip_text = "%s slot\nempty" % role.capitalize()
		card.add_child(role_label)
		return card
	var logic: WeaponLogic = weapon.logic
	_zone(card, {"kind": "gun", "weapon": index})
	card.tooltip_text = "%s\n%s\n%s\nDrag a rig magazine here to reload" % [weapon.definition.display_name,
			"Suppressed" if weapon.definition.suppressed else "Loud", _gun_detail(logic)]
	if weapon.definition.icon != null:
		var picture: TextureRect = TextureRect.new()
		picture.texture = weapon.definition.icon
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var margin: MarginContainer = MarginContainer.new()
		for side: String in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 24)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(picture)
		card.add_child(margin)
	card.add_child(role_label)
	var rounds: Label = Label.new()
	rounds.theme_type_variation = &"AccentLabel"
	rounds.text = "%d + %d" % [logic.inserted.count() if logic.inserted != null else 0, 1 if logic.chambered != &"" else 0]
	rounds.size_flags_horizontal = Control.SIZE_SHRINK_END
	rounds.size_flags_vertical = Control.SIZE_SHRINK_END
	rounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rounds)
	if weapon.definition.alt_variant != null or weapon.variant_index > 0:
		var tile: ItemSlot = _slot()
		var fitted: bool = weapon.definition.suppressed
		tile.custom_minimum_size = Vector2(64.0, 40.0)
		tile.size_flags_horizontal = Control.SIZE_SHRINK_END
		tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		tile.set_cell(null, "", "SUP" if fitted else "BRK",
				"%s fitted\nClick, or drag onto the gun, to fit the %s" % ["Suppressor" if fitted else "Muzzle brake", "muzzle brake" if fitted else "suppressor"])
		tile.payload = {"kind": "attachment", "weapon": index}
		tile.pressed.connect(func() -> void: drop(tile.payload, {"kind": "gun", "weapon": index}))
		card.add_child(tile)
	return card


func _gun_detail(logic: WeaponLogic) -> String:
	if logic.inserted == null:
		return "No magazine"
	var ammo: AmmoType = InventoryCatalog.default().find_ammo(logic.inserted.top() if not logic.inserted.is_empty() else logic.chambered)
	return "%s, %s%s" % [logic.inserted.type.display_name, ammo.display_name if ammo != null else "empty",
			", +1 chambered" if logic.chambered != &"" else ""]


## A cell of gear that is only shown (knife, binoculars).
func _gear_cell(caption: String, tip: String) -> Control:
	var cell: ItemSlot = _slot()
	cell.set_cell(null, "", caption, tip)
	return cell


func _clear(container: Control) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
