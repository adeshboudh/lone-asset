class_name WeaponSpread
extends RefCounted
## Accuracy cone (design §5.1): base spread from aiming, stance and movement, plus per-shot bloom
## that recovers over time. Angles are cone half-angles in degrees.

var bloom: float = 0.0


## moving: 0 = still, 1 = walking speed or faster.
func current_deg(weapon: WeaponDefinition, aiming: bool, moving: float, crouched: bool) -> float:
	var spread: float = weapon.spread_ads_deg if aiming else weapon.spread_hip_deg
	spread += weapon.spread_move_add_deg * clampf(moving, 0.0, 1.0) * (0.25 if aiming else 1.0)
	if crouched:
		spread *= weapon.spread_crouch_mult
	return spread + bloom * (0.3 if aiming else 1.0)


func on_shot(weapon: WeaponDefinition) -> void:
	bloom = minf(bloom + weapon.spread_per_shot_deg, weapon.spread_max_bloom_deg)


func update(weapon: WeaponDefinition, delta: float) -> void:
	bloom = maxf(bloom - weapon.spread_recovery_deg_per_s * delta, 0.0)


## A random direction inside the cone around forward, uniformly distributed over the cone's cross-section.
static func random_direction(forward: Vector3, spread_deg: float, rng: RandomNumberGenerator) -> Vector3:
	var radius: float = tan(deg_to_rad(spread_deg)) * sqrt(rng.randf())
	var spin: float = rng.randf() * TAU
	var up_hint: Vector3 = Vector3.FORWARD if absf(forward.normalized().y) > 0.99 else Vector3.UP
	var basis: Basis = Basis.looking_at(forward, up_hint)
	return (forward.normalized() + (basis.x * cos(spin) + basis.y * sin(spin)) * radius).normalized()
