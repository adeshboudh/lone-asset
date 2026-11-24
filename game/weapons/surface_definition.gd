class_name SurfaceDefinition
extends Resource
## How one surface material reacts to bullets. A level node picks its surface with the `surface` metadata
## (the same one footsteps read). New surface = a new entry in `data/surfaces/surface_table.tres`.

@export var id: StringName

@export_group("Impact effect")
## Sound id in the sound bank. Empty or missing = the generic world impact sound.
@export var impact_sound: StringName = &""
## Sparks, dust or splash thrown out of the hit point.
@export var fx_color: Color = Color(0.8, 0.8, 0.8)
@export var fx_count: int = 8
@export var fx_speed_m: float = 3.0
@export var fx_lifetime_s: float = 0.4
@export var fx_size_m: float = 0.045

@export_group("Impact flipbook")
## 4x4 sprite sheet played once, camera-facing, at the hit point. Null = no puff on this surface.
@export var flipbook: Texture2D
@export var flipbook_size_m: float = 0.45
@export var flipbook_fps: float = 25.0
@export var flipbook_tint: Color = Color.WHITE

@export_group("Ricochet")
## A bullet bounces when it meets the surface at or below this angle to the surface plane (degrees). 0 = never.
@export_range(0.0, 45.0) var ricochet_max_angle_deg: float = 0.0
## Share of speed and of damage the bullet keeps after bouncing.
@export_range(0.0, 1.0) var ricochet_speed_keep: float = 0.6
@export_range(0.0, 1.0) var ricochet_damage_keep: float = 0.5

@export_group("Penetration")
## False = bullets stop here. True = bullets with enough penetration power pass through.
@export var penetrable: bool = false
## Penetration power used up per metre of material. A weapon's penetration_power divided by this is how thick
## a layer it can pass through.
@export var penetration_cost_per_m: float = 1000.0
