class_name GuardAnimationProfile
extends Resource
## Which mocap clip a guard plays and how it is paced. Edited in data/ai/guard_animation.tres.

@export_group("Relaxed (patrol, return)")
@export var relaxed_idle: StringName = &"MOB1_Stand_Relaxed_Idle"
@export var relaxed_walk: StringName = &"MOB1_Walk_F_IPC"
@export var relaxed_jog: StringName = &"MOB1_Jog_F_IPC"
@export_group("Weapon ready (investigate, search, combat)")
@export var aim_idle: StringName = &"W2_Stand_Aim_Idle_v2"
@export var aim_walk: StringName = &"W2_Walk_Aim_F_Loop_IPC"
@export var aim_jog: StringName = &"W2_Jog_Aim_F_Loop_IPC"
@export_group("Pacing (m/s)")
## Below this horizontal speed the guard stands still.
@export var idle_below_speed: float = 0.15
## At or above this speed the jog clip plays instead of the walk clip.
@export var jog_from_speed: float = 3.0
## The speed each clip was captured at; the clip plays faster or slower to match the real speed so feet do not slide.
@export var walk_clip_speed: float = 1.4
@export var jog_clip_speed: float = 3.6
@export var min_speed_scale: float = 0.5
@export var max_speed_scale: float = 1.6
## Seconds to cross-fade between clips.
@export var blend_s: float = 0.2
