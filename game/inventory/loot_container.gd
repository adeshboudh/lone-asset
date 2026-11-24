class_name LootContainer
extends Node3D
## Something the player can open and loot: a crate, locker, shelf or a fallen guard. F opens the inventory screen's
## container panel on its contents (EventBus.container_opened). The contents are saved with the checkpoint.

const DEFINITION: InteractionDefinition = preload("res://data/interaction/container.tres")
const USE_RADIUS_M: float = 1.0

## Stable id for saves (a fallen guard uses "drop_" plus the guard's id).
@export var container_id: StringName
@export var title: String = "Supply crate"
## Magazines and loose rounds a level designer puts in (used only while the store is empty at the start).
@export var starting_magazines: Array[StartingMagazine] = []
@export var starting_loose: Dictionary = {}
@export var magazine_capacity: int = 12
## The size of the crate box; a zero size draws nothing (a fallen guard is its own picture).
@export var box_size_m: Vector3 = Vector3(0.9, 0.5, 0.6)

var store: LootStore

var _interactable: Interactable


func _ready() -> void:
	add_to_group(&"containers")
	if store == null:
		store = LootStore.new(magazine_capacity)
		for entry: StartingMagazine in starting_magazines:
			var magazine: Magazine = Magazine.new(entry.type)
			for i: int in mini(entry.rounds, entry.type.capacity):
				magazine.rounds.append(entry.ammo.id)
			store.add_magazine(magazine)
		for id: Variant in starting_loose:
			store.add_loose(StringName(String(id)), int(starting_loose[id]))
	if box_size_m != Vector3.ZERO:
		var box: MeshInstance3D = MeshInstance3D.new()
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = box_size_m
		box.mesh = mesh
		box.position.y = box_size_m.y * 0.5
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.22, 0.25, 0.2)
		box.material_override = material
		add_child(box)
	_interactable = Interactable.new()
	_interactable.definition = DEFINITION
	_interactable.interactable_id = container_id
	_interactable.prompt_text = "Open %s" % title.to_lower()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var sphere: SphereShape3D = SphereShape3D.new()
	sphere.radius = USE_RADIUS_M
	shape.shape = sphere
	_interactable.add_child(shape)
	_interactable.position.y = 0.3
	_interactable.completed.connect(_on_completed)
	add_child(_interactable)


func save_state() -> Dictionary:
	return store.to_dict()


func load_state(data: Dictionary) -> void:
	if data.is_empty():
		return
	store = LootStore.from_dict(data, InventoryCatalog.default())


func _on_completed(actor: Node) -> void:
	if actor is Player:
		EventBus.container_opened.emit(store, title, self)
