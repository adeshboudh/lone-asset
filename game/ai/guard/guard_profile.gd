class_name GuardProfile
extends Resource
## Tuning for one kind of guard (design §7.1). Edited in data/ai/guard_default.tres.
## Perception and combat values join in WP 7 and WP 8.

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Movement (m/s)")
@export var patrol_speed: float = 1.5
@export var run_speed: float = 4.5
@export var acceleration: float = 12.0
## Degrees per second.
@export var turn_speed_deg: float = 270.0
@export var step_height: float = 0.35

@export_group("Navigation")
## Horizontal distance (m) from a target at which the guard counts as arrived.
@export var arrive_distance: float = 0.5
## A guard that moves less than stuck_min_progress_m in this many seconds gives up on its target.
@export var stuck_timeout_s: float = 2.5
@export var stuck_min_progress_m: float = 0.15
