class_name DamageInfo
extends RefCounted
## One instance of damage (design §6). amount already includes hit-zone multipliers.

var amount: float = 0.0
## &"ballistic", &"melee", &"explosive", &"fall"
var type: StringName = &"ballistic"
## Instigator (the shooter), or null.
var source: Node
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.ZERO
var direction: Vector3 = Vector3.ZERO
## &"head", &"torso", &"limb", or &"" when not applicable.
var hit_zone: StringName = &""
