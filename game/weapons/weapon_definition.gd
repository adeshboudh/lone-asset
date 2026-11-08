class_name WeaponDefinition
extends Resource
## Data for one weapon (design §5.1). New weapons are new .tres files; weapon code does not change.

@export var id: StringName
@export var display_name: String

@export_group("Fire")
@export var damage: float = 34.0
@export var fire_rate_rpm: float = 750.0
## Cycled with the fire-mode key. Supported: &"semi", &"auto".
@export var fire_modes: Array[StringName] = [&"semi", &"auto"]
@export var magazine_size: int = 30
@export var reserve_ammo: int = 90
@export var reload_time: float = 2.2
@export var reload_time_empty: float = 2.8

@export_group("Ballistics")
## Metres per second.
@export var muzzle_velocity: float = 880.0
@export var gravity_scale: float = 1.0
@export var max_range: float = 400.0
## Raycast segments per physics tick.
@export var projectile_steps_per_tick: int = 4
## Unused until penetration is implemented (Milestone 2).
@export var penetration_power: float = 0.0

@export_group("Accuracy (cone half-angle, degrees)")
@export var spread_hip_deg: float = 2.5
@export var spread_ads_deg: float = 0.15
## Added at full walking speed.
@export var spread_move_add_deg: float = 2.0
@export var spread_crouch_mult: float = 0.7
## Bloom added per shot, capped, recovering over time.
@export var spread_per_shot_deg: float = 0.35
@export var spread_max_bloom_deg: float = 2.0
@export var spread_recovery_deg_per_s: float = 6.0

@export_group("Recoil (degrees)")
@export var recoil_pitch_deg: float = 0.6
## Random sideways kick, ± this value.
@export var recoil_yaw_deg: float = 0.25
@export var recoil_ads_mult: float = 0.6
@export var recoil_recovery_deg_per_s: float = 8.0

@export_group("Aiming")
@export var ads_fov: float = 55.0
## Seconds from hip to fully aimed.
@export var ads_time: float = 0.18

@export_group("Stealth")
@export var suppressed: bool = true
## Gameplay noise radius heard by AI. Unsuppressed weapons: 80 m.
@export var noise_radius_m: float = 18.0
## Exposure (0–1) while the muzzle flashes; a suppressor hides most of it.
@export_range(0.0, 1.0) var flash_exposure: float = 1.0

@export_group("Audio (sound ids in the sound bank)")
@export var fire_sound: StringName = &"rifle_shot_suppressed"
@export var dry_fire_sound: StringName = &"rifle_dry"
@export var reload_sound: StringName = &"rifle_reload"
@export var reload_empty_sound: StringName = &"rifle_reload_empty"

@export_group("Presentation")
## First-person model. Must contain a Node3D named "Muzzle".
@export var viewmodel_scene: PackedScene
## Where the viewmodel sits relative to the camera, hip-fired and fully aimed (metres). Aimed must
## put the sight on the camera axis; it depends on the model, so it lives with the definition.
@export var viewmodel_hip_position: Vector3 = Vector3(0.16, -0.17, -0.32)
@export var viewmodel_ads_position: Vector3 = Vector3(0.0, -0.105, -0.24)
@export_subgroup("Viewmodel animations")
## Names in the viewmodel's AnimationPlayer. Empty = the model has none and the kick and reload dip are
## procedural. When "fire" is set the animation carries the recoil and the procedural kick is off.
@export var anim_idle: StringName = &""
@export var anim_draw: StringName = &""
@export var anim_fire: StringName = &""
@export var anim_reload: StringName = &""
@export var anim_reload_empty: StringName = &""
