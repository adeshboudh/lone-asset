class_name AmmoPickup
extends Node3D
## Loose ammo or a magazine lying in the level (docs/superpowers/specs/2026-11-22-inventory-magazines-design.md).
## The player takes it with the interact key. Loose ammo is always taken; a magazine needs a free pouch and stays
## where it is when the pouches are full. A taken pickup is saved with the checkpoint.

enum Kind { LOOSE_AMMO, MAGAZINE }

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
@onready var _label: Label3D = %Label


func _ready() -> void:
	add_to_group(&"pickups")
	_interactable.interactable_id = pickup_id
	_interactable.prompt_text = "Take %s" % description()
	_interactable.completed.connect(_on_completed)
	_label.text = description()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.75, 0.6, 0.2) if kind == Kind.LOOSE_AMMO else Color(0.2, 0.22, 0.25)
	_box.material_override = material
	if kind == Kind.MAGAZINE:
		_box.scale = Vector3(0.5, 1.4, 1.0)


## "5.56x45 FMJ x30" or "STANAG 30-round (20, 5.56x45 FMJ)".
func description() -> String:
	if ammo == null:
		return "ammo"
	if kind == Kind.LOOSE_AMMO:
		return "%s x%d" % [ammo.display_name, count]
	return "%s (%d, %s)" % [magazine_type.display_name, count, ammo.display_name]


## Puts the pickup into the player's inventory. False (and it stays) when a magazine does not fit in the pouches.
func take(player: Player) -> bool:
	if is_taken or ammo == null:
		return false
	var inventory: AmmoInventory = player.inventory
	if kind == Kind.LOOSE_AMMO:
		inventory.add_loose(ammo.id, count)
	else:
		var magazine: Magazine = Magazine.new(magazine_type)
		for i: int in mini(count, magazine_type.capacity):
			magazine.rounds.append(ammo.id)
		if not inventory.add_magazine(magazine):
			return false
	_mark_taken()
	return true


func save_state() -> Dictionary:
	return {"taken": is_taken}


func load_state(data: Dictionary) -> void:
	if bool(data.get("taken", false)):
		_mark_taken()


func _on_completed(actor: Node) -> void:
	var player: Player = actor as Player
	if player == null:
		return
	var text: String = description()
	if take(player):
		Audio.play_2d(&"round_load", &"SFX")
		EventBus.toast_requested.emit("TOOK %s" % text.to_upper())
	else:
		EventBus.toast_requested.emit("POUCHES FULL")


func _mark_taken() -> void:
	is_taken = true
	visible = false
	_interactable.enabled = false
	_interactable.monitorable = false
