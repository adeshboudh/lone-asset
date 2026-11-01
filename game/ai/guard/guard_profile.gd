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

@export_group("Investigate and search")
@export var investigate_speed: float = 2.0
@export var search_speed: float = 2.0
## Seconds spent turning toward a stimulus before walking to it.
@export var turn_to_stimulus_s: float = 0.6
## Minimum seconds spent looking around at the place being investigated.
@export var investigate_look_s: float = 4.0
## While scanning, seconds between changes of direction, and how far each side to look.
@export var scan_step_s: float = 1.3
@export var scan_angle_deg: float = 60.0
@export var search_points_min: int = 4
@export var search_points_max: int = 6
@export var search_radius_m: float = 12.0
@export var search_min_separation_m: float = 3.0
## Seconds spent scanning at each search point.
@export var search_scan_s: float = 2.5
## A search ends after this many seconds without any new stimulus.
@export var search_timeout_s: float = 45.0
## After any search suspicion stays at least this high for search_floor_duration_s...
@export var search_floor: float = 10.0
@export var search_floor_duration_s: float = 60.0
## ...and after any combat at least this high for the rest of the session ("guards stay wary").
@export var combat_floor: float = 30.0
## Walking back to the patrol route.
@export var return_speed: float = 2.0

@export_group("Combat")
@export var weapon: WeaponDefinition
## Combat ends (and a search starts) when the target has not been seen or felt for this long.
@export var target_lost_s: float = 8.0
## Seconds between first having a clear view and the first shot.
@export var reaction_delay_s: float = 0.35
## Aim error (cone half-angle) when the fight starts, settling to the minimum over aim_settle_s.
@export var aim_error_start_deg: float = 6.0
@export var aim_error_min_deg: float = 1.0
@export var aim_settle_s: float = 3.0
## Error multiplier while the target is moving.
@export var moving_target_error_mult: float = 1.5
@export var burst_min: int = 2
@export var burst_max: int = 4
@export var burst_pause_min_s: float = 0.7
@export var burst_pause_max_s: float = 1.5
## A guard fires only when facing the target to within this many degrees.
@export var fire_alignment_deg: float = 12.0
## Every this many seconds (random in the range) a guard looks for a new firing position.
@export var reposition_interval_min_s: float = 4.0
@export var reposition_interval_max_s: float = 7.0
@export var reposition_min_m: float = 4.0
@export var reposition_max_m: float = 9.0
@export var reposition_samples: int = 10
@export var reposition_timeout_s: float = 4.0
