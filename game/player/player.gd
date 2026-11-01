class_name Player
extends CharacterBody3D
## First-person player (design §3–4). The root wires the components together each tick;
## the components hold the behaviour.

@export var settings: PlayerMovementSettings

var camera: Camera3D:
	get:
		return _camera
var stance: StanceComponent.Stance:
	get:
		return _stance.stance
var is_sprinting: bool:
	get:
		return _movement.is_sprinting
var lean_amount: float:
	get:
		return _lean.amount
var horizontal_speed: float:
	get:
		return Vector2(velocity.x, velocity.z).length()

var _pitch: float = 0.0
var _bob_phase: float = 0.0

@onready var _input: PlayerInput = %PlayerInput
@onready var _movement: MovementComponent = %MovementComponent
@onready var _stance: StanceComponent = %StanceComponent
@onready var _lean: LeanComponent = %LeanComponent
@onready var _collision: CollisionShape3D = %CollisionShape
@onready var _head: Node3D = %Head
@onready var _lean_pivot: Node3D = %LeanPivot
@onready var _camera: Camera3D = %Camera


func _ready() -> void:
	floor_max_angle = deg_to_rad(settings.max_slope_deg)
	floor_snap_length = settings.step_height + 0.05
	_stance.setup(_collision, settings)
	_head.position.y = _stance.eye_height


## Scripted input for tests and AI dummies; null returns control to the devices.
func set_scripted_intent(intent: InputIntent) -> void:
	_input.scripted_intent = intent


func _process(delta: float) -> void:
	var look: Vector2 = _input.take_look_delta() * settings.mouse_sensitivity
	rotate_y(-look.x)
	var max_pitch: float = deg_to_rad(settings.max_pitch_deg)
	_pitch = clampf(_pitch - look.y, -max_pitch, max_pitch)
	_head.rotation.x = _pitch
	_head.position.y = _stance.eye_height + _head_bob_offset(delta)
	_lean.apply(_lean_pivot, settings)


func _physics_process(delta: float) -> void:
	var intent: InputIntent = _input.read_intent()
	_stance.physics_update(self, intent, settings, delta)
	_movement.physics_update(self, intent, _stance, settings, delta)
	_lean.physics_update(self, intent, settings, _movement.is_sprinting, _head.global_position, delta)


func _head_bob_offset(delta: float) -> float:
	if not settings.head_bob_enabled or not is_on_floor():
		return 0.0
	var speed: float = horizontal_speed
	_bob_phase = fmod(_bob_phase + speed * delta * settings.head_bob_cycles_per_metre * TAU, TAU)
	return sin(_bob_phase) * settings.head_bob_amplitude * clampf(speed / settings.walk_speed, 0.0, 1.5)
