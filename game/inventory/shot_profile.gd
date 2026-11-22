class_name ShotProfile
extends RefCounted
## What the round that was just fired changes about the shot. Built from an AmmoType; the default is a plain round.

var damage_mult: float = 1.0
var penetration_mult: float = 1.0
var velocity_mult: float = 1.0
var noise_mult: float = 1.0
var tracer: bool = false


static func from_ammo(ammo: AmmoType) -> ShotProfile:
	var profile: ShotProfile = ShotProfile.new()
	if ammo != null:
		profile.damage_mult = ammo.damage_mult
		profile.penetration_mult = ammo.penetration_mult
		profile.velocity_mult = ammo.velocity_mult
		profile.noise_mult = ammo.noise_mult
		profile.tracer = ammo.tracer
	return profile
