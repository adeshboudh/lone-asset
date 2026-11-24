class_name AmmoPickup
extends Node3D
## Loose ammo or a magazine lying in the level (docs/superpowers/specs/2026-11-22-inventory-magazines-design.md).
## The player takes it with the interact key. Loose ammo and magazines need free slots; what does not fit stays
## where it is. A taken pickup is saved with the checkpoint.

enum Kind { LOOSE_AMMO, MAGAZINE }

## One shared box mesh: surface "Ammo_Label" (front and back) takes the ammo's label, the rest is the cardboard.
const AMMO_BOX_MODEL: PackedScene = preload("res://content/weapons/common/ammo_boxes/ammo_box.glb")
const AMMO_BOX_LABEL_SURFACE: String = "Label"
## Size of the box mesh as modelled; the model is scaled to `AmmoType.box_size_m`.
const AMMO_BOX_MODEL_SIZE_M: Vector3 = Vector3(0.19, 0.1, 0.07)
## A magazine lies on its side, thin side up (half its thickness above the table).
const MAGAZINE_LYING_DEG: float = 90.0
const MAGAZINE_REST_HEIGHT_M: float = 0.012

## Stable id for saves (a guard's drop uses "drop_" plus the guard's id).
@export var pickup_id: StringName
@export var kind: Kind = Kind.LOOSE_AMMO
@export var ammo: AmmoType
## Loose rounds, or the rounds in the magazine.
@export var count: int = 30
## The magazine type (MAGAZINE only).
@export var magazine_type: MagazineType

var is_taken: bool = false

@onready var _interactable: Interactable = %Interactable
@onready var _box: MeshInstance3D = %Box
@onready var _icon: Sprite3D = %Icon
@onready var _label: Label3D = %Label


func _ready() -> void:
	add_to_group(&"pickups")
	_interactable.interactable_id = pickup_id
	_interactable.prompt_text = "Take %s" % description()
	_interactable.completed.connect(_on_completed)
	_label.text = description()
	# The name shows only while the crosshair is on the pickup.
	_label.visible = false
	_interactable.focus_changed.connect(func(focused: bool) -> void: _label.visible = focused)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.6, 0.2) if kind == Kind.LOOSE_AMMO else Color(0.2, 0.22, 0.25)
	_box.material_override = material
	if kind == Kind.MAGAZINE:
		_box.scale = Vector3(0.5, 1.4, 1.0)
	var model: Node3D = _make_model()
	if model != null:
		add_child(model)
		_box.visible = false
		return
	# No 3D model: the ammo or magazine picture when there is one; the box is the fallback.
	var picture: Texture2D = ammo.icon if kind == Kind.LOOSE_AMMO and ammo != null else (magazine_type.icon if magazine_type != null else null)
	if picture != null:
		_icon.texture = picture
		_icon.pixel_size = 0.24 / float(maxi(picture.get_width(), picture.get_height()))
		_icon.visible = true
		_box.visible = false


## The 3D model of the box or magazine, or null when the ammo or magazine type has none.
func _make_model() -> Node3D:
	if kind == Kind.LOOSE_AMMO:
		if ammo == null or ammo.box_label == null:
			return null
		var box: Node3D = AMMO_BOX_MODEL.instantiate()
		box.scale = ammo.box_size_m / AMMO_BOX_MODEL_SIZE_M
		# Lying on its biggest face, label up (the model stands on its bottom edge; its origin is bottom centre).
		box.rotation_degrees.x = -90.0
		box.position.y = ammo.box_size_m.z * 0.5
		var label: StandardMaterial3D = StandardMaterial3D.new()
		label.albedo_texture = ammo.box_label
		label.roughness = 0.8
		for mesh: MeshInstance3D in box.find_children("*", "MeshInstance3D", true, false):
			for surface: int in mesh.mesh.get_surface_count():
				if mesh.mesh.surface_get_material(surface).resource_name.contains(AMMO_BOX_LABEL_SURFACE):
					mesh.set_surface_override_material(surface, label)
		return box
	if magazine_type == null or magazine_type.mesh == null:
		return null
	var magazine: MeshInstance3D = MeshInstance3D.new()
	magazine.mesh = magazine_type.mesh
	var metal: StandardMaterial3D = StandardMaterial3D.new()
	metal.albedo_texture = magazine_type.albedo
	metal.normal_enabled = magazine_type.normal != null
	metal.normal_texture = magazine_type.normal
	metal.metallic = 0.5
	metal.roughness = 0.6
	magazine.material_override = metal
	magazine.rotation_degrees.z = MAGAZINE_LYING_DEG
	magazine.position.y = MAGAZINE_REST_HEIGHT_M
	return magazine


## "5.56x45 FMJ x30" or "STANAG 30-round (20, 5.56x45 FMJ)".
func description() -> String:
	if ammo == null:
		return "ammo"
	if kind == Kind.LOOSE_AMMO:
		return "%s x%d" % [ammo.display_name, count]
	return "%s (%d, %s)" % [magazine_type.display_name, count, ammo.display_name]


## Puts the pickup into the player's inventory and returns how many rounds went in (a magazine counts as its rounds,
## 0 when it did not fit). Loose ammo takes backpack slots, so only what fits is taken and the rest stays in the world
## (`count` goes down). A magazine goes to a free rig slot, otherwise a free backpack slot.
func take(player: Player) -> int:
	if is_taken or ammo == null:
		return 0
	var inventory: AmmoInventory = player.inventory
	var taken: int
	if kind == Kind.LOOSE_AMMO:
		taken = inventory.add_loose(ammo.id, count)
		count -= taken
		if count <= 0:
			_mark_taken()
		return taken
	var magazine: Magazine = Magazine.new(magazine_type)
	for i: int in mini(count, magazine_type.capacity):
		magazine.rounds.append(ammo.id)
	if not inventory.add_magazine(magazine) and not inventory.add_to_backpack(magazine):
		return 0
	_mark_taken()
	return magazine.count()


func save_state() -> Dictionary:
	return {"taken": is_taken, "count": count}


func load_state(data: Dictionary) -> void:
	count = int(data.get("count", count))
	if bool(data.get("taken", false)):
		_mark_taken()


func _on_completed(actor: Node) -> void:
	var player: Player = actor as Player
	if player == null:
		return
	var text: String = description()
	var wanted: int = count
	var taken: int = take(player)
	if taken <= 0:
		EventBus.toast_requested.emit("NO ROOM IN THE RIG OR BACKPACK")
		return
	Audio.play_2d(&"round_load", &"SFX")
	if kind == Kind.LOOSE_AMMO and taken < wanted:
		EventBus.toast_requested.emit("TOOK %d, BACKPACK FULL" % taken)
	else:
		EventBus.toast_requested.emit("TOOK %s" % text.to_upper())


func _mark_taken() -> void:
	is_taken = true
	visible = false
	_interactable.enabled = false
	_interactable.monitorable = false
