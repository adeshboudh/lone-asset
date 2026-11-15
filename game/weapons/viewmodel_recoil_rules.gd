class_name ViewmodelRecoilRules
extends RefCounted
## The first-person gun's kick (design: docs/superpowers/specs/2026-11-16-procedural-viewmodel-design.md): each
## shot gives a spring a push (back toward the eye, muzzle up, a random roll and sideways turn); the spring brings
## the gun back with a small overshoot. Shots in quick succession pile up. Pure functions, unit-tested; Weapon
## applies the result on top of the animation. The camera's own recoil (aim kick) is separate.

## Longest step the spring takes at once; longer frames are split so it stays stable.
const MAX_STEP_S: float = 1.0 / 120.0


## Advances a damped spring toward zero. hz: how fast it swings back, damping: 1 = no overshoot, lower overshoots.
## Returns [position, velocity].
static func step(position: Vector3, velocity: Vector3, hz: float, damping: float, delta: float) -> Array:
	var omega: float = TAU * hz
	var x: Vector3 = position
	var v: Vector3 = velocity
	var left: float = delta
	while left > 0.0:
		var dt: float = minf(left, MAX_STEP_S)
		v += (-omega * omega * x - 2.0 * damping * omega * v) * dt
		x += v * dt
		left -= dt
	return [x, v]


## The push one shot gives: [position velocity (m/s), rotation velocity (deg/s, x pitch up, y yaw, z roll)], set so
## the spring's swing peaks at the weapon's kick values. side and roll are random numbers in -1..1 for this shot.
static func shot_velocity(weapon: WeaponDefinition, aim_blend: float, side: float, roll: float) -> Array:
	var scale: float = lerpf(1.0, weapon.recoil_kick_ads_mult, aim_blend) * TAU * weapon.recoil_spring_hz \
			/ peak_factor(weapon.recoil_spring_damping)
	var position: Vector3 = Vector3(0.0, weapon.recoil_kick_up_m, weapon.recoil_kick_back_m) * scale
	var rotation: Vector3 = Vector3(weapon.recoil_kick_pitch_deg, weapon.recoil_kick_yaw_deg * side,
			weapon.recoil_kick_roll_deg * roll) * scale
	return [position, rotation]


## How far a spring at rest swings for a unit push, times its angular frequency (from the damped-spring solution).
static func peak_factor(damping: float) -> float:
	var z: float = clampf(damping, 0.05, 0.95)
	var root: float = sqrt(1.0 - z * z)
	return exp(-z / root * atan(root / z))


## A rotation (Euler degrees: x pitch, y yaw, z roll) about a pivot point, as a transform.
static func about_pivot(rotation_deg: Vector3, pivot: Vector3) -> Transform3D:
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), deg_to_rad(rotation_deg.z)))
	return Transform3D(basis, pivot - basis * pivot)
