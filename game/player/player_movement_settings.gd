class_name PlayerMovementSettings
extends Resource
## Player movement tuning (design §4.1). Edited in data/player/player_movement.tres.

@export_group("Speeds (m/s)")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 5.8
@export var crouch_speed: float = 1.7
@export var aim_speed_multiplier: float = 0.6

@export_group("Acceleration (m/s²)")
@export var ground_acceleration: float = 30.0
@export var ground_deceleration: float = 40.0
## Fraction of ground acceleration available in the air.
@export_range(0.0, 1.0) var air_control: float = 0.25

@export_group("Jump")
@export var jump_velocity: float = 4.2

@export_group("Stance (m)")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.15
@export var stand_eye_height: float = 1.65
@export var crouch_eye_height: float = 1.0
@export var body_radius: float = 0.35
@export var stance_transition_time: float = 0.25

@export_group("Lean")
@export var lean_angle_deg: float = 12.0
@export var lean_offset: float = 0.35
## Full lean per second.
@export var lean_speed: float = 5.0

@export_group("Terrain")
@export var max_slope_deg: float = 40.0
@export var step_height: float = 0.35

@export_group("Look")
## Radians per pixel of mouse movement.
@export var mouse_sensitivity: float = 0.0025
@export var max_pitch_deg: float = 85.0

@export_group("Head bob")
@export var head_bob_enabled: bool = true
@export var head_bob_amplitude: float = 0.03
## Bob cycles per metre travelled.
@export var head_bob_cycles_per_metre: float = 0.6
