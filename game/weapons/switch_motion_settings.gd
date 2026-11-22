class_name SwitchMotionSettings
extends Resource
## Numbers of the procedural weapon switch (see SwitchMotionRules): the weapon in hand drops away, the new one
## swings up and settles with a small overshoot.

@export_group("Timing")
## Time to put the weapon in hand away (accelerating drop).
@export_range(0.05, 1.0) var holster_time_s: float = 0.22
## Time for the new weapon to come up and settle (the overshoot happens inside it).
@export_range(0.1, 1.5) var draw_time_s: float = 0.55
## How much later the draw rotation follows the draw movement: the hand leads, the gun trails.
@export_range(0.0, 0.2) var draw_rotation_lag_s: float = 0.05

@export_group("Pose")
## Offset of the fully lowered weapon from its hip place (metres, camera space: x right, y up, z back).
@export var lowered_offset: Vector3 = Vector3(0.05, -0.32, 0.1)
## Rotation of the fully lowered weapon (degrees: pitch, yaw, roll about the grip).
@export var lowered_rotation_deg: Vector3 = Vector3(-42.0, 12.0, 14.0)

@export_group("Settle")
## Damping of the draw spring (0.3 bouncy, 1 no overshoot). 0.6 overshoots about 10 % of the lowered pose.
@export_range(0.2, 1.0) var draw_damping: float = 0.6
