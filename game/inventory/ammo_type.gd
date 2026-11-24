class_name AmmoType
extends Resource
## One kind of round (design: docs/superpowers/specs/2026-11-22-inventory-magazines-design.md). New ammo is a new
## .tres file. The multipliers scale the firing weapon's own numbers (see ShotProfile).

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Label drawn on the front and back of the ammo box model (the pickup in the world).
@export var box_label: Texture2D
## Real-world size of the ammo box in metres: x along the label, y the label's height, z the thickness.
@export var box_size_m: Vector3 = Vector3(0.1, 0.062, 0.036)
## Loose rounds of this type that fit in one backpack slot (loose ammo uses backpack slots).
@export var stack_size: int = 60
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
