class_name WeaponDefinition
extends Resource
## Data for one weapon (design §5.1). New weapons are new .tres files; weapon code does not change.

@export var id: StringName
@export var display_name: String

@export_group("Attachment variant")
## The other version of this weapon (e.g. suppressor <-> muzzle brake), swapped with the attachment key.
## Ammo carries over. Link one way only: the base weapon points at its variant.
@export var alt_variant: WeaponDefinition
## Seconds the weapon is unusable while the attachment is swapped.
@export var variant_swap_s: float = 0.9

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
## Passes through thin penetrable surfaces: each metre of material costs the surface's
## penetration_cost_per_m, and damage drops by the share of power used up. 0 = never penetrates.
@export var penetration_power: float = 0.0

@export_group("Tracer")
## Glowing streak drawn along the bullet's flight. Off for melee.
@export var tracer_enabled: bool = true
## 1 = every shot, 5 = every fifth shot.
@export var tracer_every_n: int = 1
## Streak colour; its alpha is how see-through the streak is. Glow multiplies the colour above 1 so the glow effect picks it up.
@export var tracer_color: Color = Color(1.0, 0.7, 0.25, 0.5)
@export var tracer_glow: float = 1.2
@export var tracer_length_m: float = 40.0
@export var tracer_width_m: float = 0.01
## Distance flown before the streak first appears (0 = from the muzzle).
@export var tracer_start_m: float = 0.0

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

@export_group("Viewmodel kick")
## The gun's own kick in first person, on top of its animation (ViewmodelRecoilRules): how far one shot throws it
## back toward the eye and up (m), how far the muzzle tips up (deg) and the random sideways turn and roll (± deg).
## 0 = no kick.
@export var recoil_kick_back_m: float = 0.0
@export var recoil_kick_up_m: float = 0.0
@export var recoil_kick_pitch_deg: float = 0.0
@export var recoil_kick_yaw_deg: float = 0.0
@export var recoil_kick_roll_deg: float = 0.0
## Share of the kick left while aimed.
@export_range(0.0, 1.0) var recoil_kick_ads_mult: float = 0.5
## How fast the gun springs back (Hz) and how much it overshoots (1 = none, lower = more).
@export var recoil_spring_hz: float = 4.0
@export_range(0.05, 1.0) var recoil_spring_damping: float = 0.45

@export_group("Body hold")
## Where the player's hands rest on the weapon, in metres from the feet (x right, y up, z forward is -z).
## Only the body model uses them (shadow and other cameras); the viewmodel has its own hands.
@export var hold_right_hand: Vector3 = Vector3(0.16, 1.28, -0.38)
@export var hold_left_hand: Vector3 = Vector3(-0.1, 1.3, -0.35)
## Both hands move by this when fully aimed (up toward the sights).
@export var hold_ads_offset: Vector3 = Vector3(-0.06, 0.1, -0.02)
## Both hands move by this when sprinting (weapon lowered and pulled in).
@export var hold_sprint_offset: Vector3 = Vector3(0.0, -0.22, 0.1)
## False lets the left arm hang (knife).
@export var hold_uses_left_hand: bool = true

@export_group("Aiming")
@export var ads_fov: float = 55.0
## Magnification of the scope picture shown in the optic lens while aiming (1 = none: the lens is plain glass).
@export_range(1.0, 12.0) var scope_zoom: float = 1.0
## Seconds from hip to fully aimed. Longer feels heavier.
@export var ads_time: float = 0.28
## How far the gun overshoots the sights before settling (0 = none). Visual only.
@export_range(0.0, 0.6) var ads_settle: float = 0.3
## Metres the gun dips mid-move, so it swings into the sights instead of sliding. Visual only.
@export var ads_arc_m: float = 0.02
## How much of the idle breathing sway the aimed gun loses (0 = none, 1 = perfectly still), reached as the aim
## settles. Only viewmodels with an idle animation use it (set_ads_steadiness).
@export_range(0.0, 1.0) var ads_idle_steady: float = 0.0
## Speed of the idle animation when fully aimed, as a fraction of its normal speed (a held breath is slower).
@export_range(0.1, 1.0) var ads_idle_speed: float = 1.0

@export_group("Sway (viewmodel lag while turning and strafing)")
## Turn rate that gives full sway; faster turns are clamped.
@export var sway_ref_turn_deg_per_s: float = 180.0
## Strafe speed (m/s) that gives full sway.
@export var sway_ref_strafe_speed: float = 3.2
@export var sway_yaw_deg: float = 3.0
@export var sway_pitch_deg: float = 2.0
@export var sway_roll_deg: float = 5.0
@export var sway_strafe_roll_deg: float = 3.0
## Sideways and vertical shift at full sway, metres.
@export var sway_position_m: float = 0.03
## Share of the sway that remains when fully aimed.
@export_range(0.0, 1.0) var sway_ads_mult: float = 0.2
## How fast the viewmodel catches up (1/s); higher is stiffer.
@export var sway_smoothing: float = 12.0

@export_group("Walk bob (viewmodel motion while walking and sprinting)")
## The bob cycle follows the footstep stride: one bounce per step, one side swing per two steps.
@export var bob_vertical_m: float = 0.012
@export var bob_side_m: float = 0.004
@export var bob_roll_deg: float = 0.6
## Extra muzzle-down tilt at sprint pace.
@export var bob_sprint_tilt_deg: float = 6.0

@export_group("Stealth")
@export var suppressed: bool = true
## Gameplay noise radius heard by AI. Unsuppressed weapons: 80 m.
@export var noise_radius_m: float = 18.0
## Exposure (0–1) while the muzzle flashes; a suppressor hides most of it.
@export_range(0.0, 1.0) var flash_exposure: float = 1.0

@export_group("Audio (sound ids in the sound bank)")
@export var fire_sound: StringName = &"m4a1_fire_semi"
## Played instead of fire_sound while the weapon is in full-auto (empty = fire_sound in every mode).
@export var fire_sound_auto: StringName = &""
@export var dry_fire_sound: StringName = &"rifle_dry"
@export var reload_sound: StringName = &"rifle_reload"
@export var reload_empty_sound: StringName = &"rifle_reload_empty"

@export_group("Muzzle effects")
## Size of the muzzle flash sprite and smoke puff (1 = rifle size); the suppressed version is smaller still.
@export var muzzle_flash_scale: float = 1.0
@export var muzzle_smoke_scale: float = 1.0
## Brightness of the flash light at the muzzle (the suppressed version uses a quarter of it).
@export var muzzle_light_energy: float = 2.5

@export_group("Presentation")
## First-person model. Must contain a Node3D named "Muzzle".
@export var viewmodel_scene: PackedScene
## Where the viewmodel sits relative to the camera, hip-fired and fully aimed (metres). Aimed must
## put the sight on the camera axis; it depends on the model, so it lives with the definition.
@export var viewmodel_hip_position: Vector3 = Vector3(0.16, -0.17, -0.32)
@export var viewmodel_ads_position: Vector3 = Vector3(0.0, -0.105, -0.24)
## Turn of the gun at the hip (Euler degrees: x pitch up, y yaw left, z roll), about viewmodel_pivot, faded out
## while aiming, so the muzzle can point in toward the crosshair.
@export var viewmodel_hip_rotation_deg: Vector3 = Vector3.ZERO
## Point the gun turns about for the hip turn and the kick (camera frame, metres): about where the right hand grips.
@export var viewmodel_pivot: Vector3 = Vector3(0.1, -0.16, -0.05)
@export_subgroup("Viewmodel animations")
## Names in the viewmodel's AnimationPlayer. Empty = the model has none and the kick and reload dip are
## procedural. When "fire" is set the animation carries the recoil and the procedural kick is off.
@export var anim_idle: StringName = &""
@export var anim_draw: StringName = &""
@export var anim_fire: StringName = &""
@export var anim_reload: StringName = &""
@export var anim_reload_empty: StringName = &""
## Melee only: the heavy attack (aim button).
@export var anim_fire_alt: StringName = &""

@export_group("Melee")
## A blade: the trigger swings it instead of firing; ammo, spread and reload do not apply.
@export var melee: bool = false
@export var melee_range_m: float = 1.8
@export var melee_damage: float = 45.0
## Damage when the target is struck from behind: the silent takedown.
@export var melee_backstab_damage: float = 200.0
## "From behind" means within this many degrees of straight behind the target.
@export_range(0.0, 180.0) var melee_backstab_arc_deg: float = 60.0
## Whole swing, and when the blade lands inside it.
@export var melee_swing_s: float = 0.5
@export var melee_hit_delay_s: float = 0.18
## The heavy attack, on the aim button: slower, longer reach, harder hit. From behind it does the same
## takedown damage as the quick attack.
@export var melee_heavy_damage: float = 80.0
@export var melee_heavy_range_m: float = 2.3
@export var melee_heavy_swing_s: float = 0.8
@export var melee_heavy_hit_delay_s: float = 0.36
