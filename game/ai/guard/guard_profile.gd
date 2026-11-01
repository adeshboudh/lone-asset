class_name GuardProfile
extends Resource
## Tuning for one kind of guard (design §7.1). Edited in data/ai/guard_default.tres.
## Combat values join in WP 8.

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

@export_group("Vision")
## Height of the eyes above the feet.
@export var eye_height_m: float = 1.62
@export var primary_fov_deg: float = 100.0
@export var primary_range_m: float = 35.0
@export var peripheral_fov_deg: float = 160.0
@export var peripheral_range_m: float = 10.0
## Looking up or down further than this sees nothing.
@export var vertical_limit_deg: float = 50.0

@export_group("Suspicion from sight")
## Suspicion per second when the whole player is in plain view up close, before the other factors.
@export var sight_base_rate: float = 45.0
## Within this distance, seeing at least instant_min_visibility of a lit player raises suspicion to 100.
@export var instant_distance_m: float = 3.0
@export_range(0.0, 1.0) var instant_min_visibility: float = 0.67
@export_range(0.0, 1.0) var instant_min_exposure: float = 0.3

@export_group("Suspicion from sound and damage")
## Footsteps, landings and doors add this much...
@export var noise_step_gain: float = 10.0
## ...but never push suspicion above this (they alone cause Investigate, not Search).
@export var noise_step_cap: float = 45.0
## Suppressed shots and bullet impacts.
@export var noise_quiet_gain: float = 35.0
## An unsuppressed shot sets suspicion to at least this.
@export var noise_loud_level: float = 80.0

@export_group("Suspicion decay")
## Seconds without a stimulus before suspicion starts to fall.
@export var decay_delay_s: float = 3.0
@export var decay_rate: float = 8.0
## Walking speed multiplier while Curious (suspicion 20–40).
@export_range(0.1, 1.0) var curious_speed_factor: float = 0.5
