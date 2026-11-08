class_name MeleeRules
extends RefCounted
## Pure rules for blades (design §5): who counts as struck from behind and how much damage that does.


## True when the attacker stands within half_arc_deg of straight behind the target, on the ground plane.
## target_facing is where the target looks; to_attacker points from the target to the attacker.
static func is_from_behind(target_facing: Vector3, to_attacker: Vector3, half_arc_deg: float) -> bool:
	var facing: Vector3 = Vector3(target_facing.x, 0.0, target_facing.z)
	var offset: Vector3 = Vector3(to_attacker.x, 0.0, to_attacker.z)
	if facing.length_squared() < 0.0001 or offset.length_squared() < 0.0001:
		return false
	return facing.angle_to(offset) >= deg_to_rad(180.0 - half_arc_deg)


static func damage_for(definition: WeaponDefinition, from_behind: bool, heavy: bool = false) -> float:
	if from_behind:
		return definition.melee_backstab_damage
	return definition.melee_heavy_damage if heavy else definition.melee_damage
