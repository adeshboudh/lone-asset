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
var weapon: Weapon:
	get:
		return _weapon
var health: HealthComponent:
	get:
		return _health
var exposure: ExposureComponent:
	get:
		return _exposure
var binoculars: Binoculars:
	get:
		return _binoculars
var interactor: Interactor:
	get:
		return _interactor
var is_crouched: bool:
	get:
		return _stance.is_crouched

var _pitch: float = 0.0
var _idle_intent: InputIntent = InputIntent.new()
## Recoil offset on top of the aim pitch; recovers toward 0.
var _recoil_pitch: float = 0.0
var _base_fov: float = 0.0
var _bob_phase: float = 0.0

@onready var _input: PlayerInput = %PlayerInput
@onready var _movement: MovementComponent = %MovementComponent
@onready var _stance: StanceComponent = %StanceComponent
@onready var _lean: LeanComponent = %LeanComponent
@onready var _collision: CollisionShape3D = %CollisionShape
@onready var _head: Node3D = %Head
@onready var _lean_pivot: Node3D = %LeanPivot
@onready var _camera: Camera3D = %Camera
@onready var _weapon: Weapon = %Weapon
@onready var _health: HealthComponent = %HealthComponent
@onready var _hud: Hud = %Hud
@onready var _noise: NoiseEmitterComponent = %NoiseEmitterComponent
@onready var _exposure: ExposureComponent = %ExposureComponent
@onready var _audio: PlayerAudio = %PlayerAudio
@onready var _interactor: Interactor = %Interactor
@onready var _binoculars: Binoculars = %Binoculars


func _ready() -> void:
	floor_max_angle = deg_to_rad(settings.max_slope_deg)
	floor_snap_length = settings.step_height + 0.05
	_stance.setup(_collision, settings)
	_head.position.y = _stance.eye_height
	_base_fov = Settings.fov_deg
	_camera.fov = _base_fov
	Settings.changed.connect(func() -> void: _base_fov = Settings.fov_deg)
	add_to_group(&"player")
	_movement.landed.connect(_on_landed)
	_noise.stepped.connect(_audio.on_step)
	_weapon.fired.connect(_on_weapon_fired)
	_health.died.connect(_on_died)
	_interactor.setup(self)
	_hud.setup(self)


## Where guards look when checking whether they can see the player (design §8.1): head, chest and
## pelvis. The head is the camera, so leaning around a corner exposes only the head.
func perception_points() -> PackedVector3Array:
	var eye_height: float = _stance.eye_height
	return PackedVector3Array([
		_camera.global_position,
		global_position + Vector3.UP * (eye_height - 0.35),
		global_position + Vector3.UP * (eye_height * 0.55),
	])


func save_state() -> Dictionary:
	return {
		"position": SaveRules.vector_to_array(global_position),
		"yaw": snappedf(rotation.y, 0.001),
		"stance": "crouch" if _stance.is_crouched else "stand",
		"health": _health.health,
		"weapon": {"id": String(_weapon.definition.id), "mag": _weapon.logic.magazine, "reserve": _weapon.logic.reserve},
	}


func load_state(data: Dictionary) -> void:
	global_position = SaveRules.array_to_vector(data["position"])
	rotation.y = float(data["yaw"])
	velocity = Vector3.ZERO
	_pitch = 0.0
	_stance.restore(data["stance"] == "crouch", settings)
	_head.position.y = _stance.eye_height
	_health.health = float(data["health"])
	_weapon.logic.magazine = int(data["weapon"]["mag"])
	_weapon.logic.reserve = int(data["weapon"]["reserve"])


## Scripted input for tests and AI dummies; null returns control to the devices.
func set_scripted_intent(intent: InputIntent) -> void:
	_input.scripted_intent = intent


func _process(delta: float) -> void:
	var aim_fov: float = lerpf(_base_fov, _weapon.definition.ads_fov, smoothstep(0.0, 1.0, _weapon.aim_blend))
	aim_fov = lerpf(aim_fov, BinocularsRules.fov_for_zoom(_base_fov, _binoculars.zoom), smoothstep(0.0, 1.0, _binoculars.raise_blend))
	_camera.fov = aim_fov
	# Same on-screen mouse speed when zoomed in.
	var look: Vector2 = _input.take_look_delta() * settings.mouse_sensitivity * Settings.mouse_sensitivity_scale * (aim_fov / _base_fov)
	look.y = SettingsRules.look_y(look.y, Settings.invert_y)
	rotate_y(-look.x)
	var max_pitch: float = deg_to_rad(settings.max_pitch_deg)
	_pitch = clampf(_pitch - look.y, -max_pitch, max_pitch)
	_recoil_pitch = move_toward(_recoil_pitch, 0.0, deg_to_rad(_weapon.definition.recoil_recovery_deg_per_s) * delta)
	_head.rotation.x = clampf(_pitch + _recoil_pitch, -max_pitch, max_pitch)
	_head.position.y = _stance.eye_height + _head_bob_offset(delta)
	_lean.apply(_lean_pivot, settings)


func _physics_process(delta: float) -> void:
	var intent: InputIntent = _input.read_intent()
	_stance.physics_update(self, intent, settings, delta)
	_movement.physics_update(self, intent, _stance, settings, delta)
	_noise.physics_update(self, is_on_floor(), horizontal_speed, _stance.is_crouched, _movement.is_sprinting, delta)
	_lean.physics_update(self, intent, settings, _movement.is_sprinting, _head.global_position, delta)
	var moving: float = clampf(horizontal_speed / settings.walk_speed, 0.0, 1.0)
	_binoculars.physics_update(self, intent, delta)
	_weapon.visible = not _binoculars.is_active
	# Raised binoculars take both hands: the weapon sees no input.
	var weapon_intent: InputIntent = _idle_intent if _binoculars.is_active else intent
	var kick: Vector2 = _weapon.physics_update(weapon_intent, delta, self, _camera.global_transform, moving, _stance.is_crouched)
	_interactor.physics_update(_camera, intent, delta)
	_recoil_pitch += kick.x
	rotate_y(kick.y)


func _on_weapon_fired(_origin: Vector3, _direction: Vector3) -> void:
	_noise.emit_shot(self, _weapon.definition)
	_exposure.flash(_weapon.definition.flash_exposure)


func _on_landed(fall_height: float) -> void:
	_noise.on_landed(self, fall_height)
	_audio.on_landed(fall_height)
	var amount: float = DamageRules.fall_damage(fall_height, _health.max_health)
	if amount <= 0.0:
		return
	var info: DamageInfo = DamageInfo.new()
	info.type = &"fall"
	info.amount = amount
	info.hit_position = global_position
	_health.apply_damage(info)


func _on_died(info: DamageInfo) -> void:
	Log.info(&"player", "Died (%s)" % info.type)
	EventBus.player_died.emit()


func _head_bob_offset(delta: float) -> float:
	if not (settings.head_bob_enabled and Settings.head_bob) or not is_on_floor():
		return 0.0
	var speed: float = horizontal_speed
	_bob_phase = fmod(_bob_phase + speed * delta * settings.head_bob_cycles_per_metre * TAU, TAU)
	return sin(_bob_phase) * settings.head_bob_amplitude * clampf(speed / settings.walk_speed, 0.0, 1.5)
