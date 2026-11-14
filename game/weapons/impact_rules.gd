class_name ImpactRules
extends RefCounted
## Pure rules for what a bullet does when it meets a surface: ricochet and penetration.


## Angle between the bullet's path and the surface plane, 0 to 90 degrees (0 = skimming along it).
static func grazing_angle_deg(direction: Vector3, normal: Vector3) -> float:
	return rad_to_deg(asin(clampf(absf(direction.normalized().dot(normal.normalized())), 0.0, 1.0)))


## A bullet ricochets at shallow angles, up to max_ricochets times. max_angle_deg of 0 never ricochets.
static func ricochets(max_angle_deg: float, grazing_deg: float, ricochets_so_far: int, max_ricochets: int) -> bool:
	return max_angle_deg > 0.0 and grazing_deg <= max_angle_deg and ricochets_so_far < max_ricochets


## The bullet's direction after bouncing off a surface with this normal.
static func reflect(direction: Vector3, normal: Vector3) -> Vector3:
	return direction.normalized().bounce(normal.normalized())


## Penetration power left after passing through thickness_m of material. 0 or less = the bullet is stopped.
static func remaining_power(power: float, thickness_m: float, cost_per_m: float) -> float:
	return maxf(power - thickness_m * cost_per_m, 0.0)
