class_name AmmoType
extends Resource
## One kind of round (design: docs/superpowers/specs/2026-11-22-inventory-magazines-design.md). New ammo is a new
## .tres file. The multipliers scale the firing weapon's own numbers (see ShotProfile).

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Caliber id; a magazine accepts the calibers listed in its type.
@export var caliber: StringName

@export_group("Effect on the shot")
@export var damage_mult: float = 1.0
@export var penetration_mult: float = 1.0
@export var velocity_mult: float = 1.0
## Scales the noise radius of the shot.
@export var noise_mult: float = 1.0
## The round always draws a tracer.
@export var tracer: bool = false
