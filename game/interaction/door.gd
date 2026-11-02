class_name Door
extends Node3D
## A hinged door (design §12). The player toggles it with the interact key; a guard walking into the
## door opens it through the same Interactable. Closed doors block sight and halve noise like a wall;
## the doorway is part of the baked navigation mesh, so guards path through and open the door on arrival.

const HALF_WIDTH_M: float = 1.0
const HEIGHT_M: float = 2.6
## A door a guard opened closes again once nobody has been near it for this long.
const AI_CLOSE_DELAY_S: float = 5.0

@export var door_id: StringName
@export var open_angle_deg: float = 100.0
@export var swing_time_s: float = 0.6

var is_open: bool = false
## 0 closed, 1 fully open.
var open_amount: float = 0.0

var _opened_by_ai: bool = false
var _idle_time: float = 0.0

@onready var _leaf: AnimatableBody3D = %Leaf
@onready var _interactable: Interactable = %Interactable
@onready var _sensor: Area3D = %GuardSensor


func _ready() -> void:
	add_to_group(&"doors")
	_interactable.interactable_id = door_id
	_interactable.prompt_text = "Open"
	_interactable.completed.connect(_on_interacted)
	_apply_pose()


func _physics_process(delta: float) -> void:
	var target: float = 1.0 if is_open else 0.0
	if not is_equal_approx(open_amount, target):
		open_amount = move_toward(open_amount, target, delta / swing_time_s)
		_apply_pose()
	if is_open:
		_auto_close(delta)
	else:
		_open_for_approaching_guard()


func open(actor: Node) -> void:
	if is_open:
		return
	is_open = true
	_opened_by_ai = actor != null and actor.is_in_group(&"guards")
	_idle_time = 0.0
	_interactable.prompt_text = "Close"
	Audio.play_3d(&"door_open", _leaf.global_position)


func close(_actor: Node) -> void:
	if not is_open:
		return
	is_open = false
	_opened_by_ai = false
	_interactable.prompt_text = "Open"
	Audio.play_3d(&"door_close", _leaf.global_position)


func save_state() -> Dictionary:
	return {"open": is_open}


func load_state(data: Dictionary) -> void:
	is_open = bool(data.get("open", false))
	open_amount = 1.0 if is_open else 0.0
	_opened_by_ai = false
	_interactable.prompt_text = "Close" if is_open else "Open"
	_apply_pose()


func _on_interacted(actor: Node) -> void:
	if is_open:
		close(actor)
	else:
		open(actor)


func _apply_pose() -> void:
	var angle: float = -deg_to_rad(open_angle_deg) * smoothstep(0.0, 1.0, open_amount)
	var hinge: Vector3 = Vector3(-HALF_WIDTH_M, HEIGHT_M * 0.5, 0.0)
	var swing: Basis = Basis(Vector3.UP, angle)
	_leaf.transform = Transform3D(swing, hinge + swing * Vector3(HALF_WIDTH_M, 0.0, 0.0))


## Opens when a guard in the doorway zone is walking toward the door.
func _open_for_approaching_guard() -> void:
	for body: Node3D in _sensor.get_overlapping_bodies():
		var guard: CharacterBody3D = body as CharacterBody3D
		if guard == null or not guard.is_in_group(&"guards"):
			continue
		var to_door: Vector3 = global_position - guard.global_position
		to_door.y = 0.0
		if guard.velocity.dot(to_door) > 0.2:
			_interactable.complete(guard)
			return


func _auto_close(delta: float) -> void:
	if not _opened_by_ai:
		return
	if _sensor.has_overlapping_bodies():
		_idle_time = 0.0
		return
	_idle_time += delta
	if _idle_time >= AI_CLOSE_DELAY_S:
		close(null)
