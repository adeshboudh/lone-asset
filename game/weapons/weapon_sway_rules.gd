class_name WeaponSwayRules
extends RefCounted
## Viewmodel sway (design §5.2): the weapon lags behind the camera while turning and strafing.
## Pure functions, unit-tested; Weapon applies the result.


## Turn rate in rad/s: x = yaw (right is positive), y = pitch (up is positive).
## strafe_speed: m/s along the player's right (right is positive). aim_blend: 0 hip, 1 aimed.
static func target_position(weapon: WeaponDefinition, turn_rate: Vector2, strafe_speed: float, aim_blend: float) -> Vector3:
	var turn: Vector2 = _normalised_turn(weapon, turn_rate)
	var strafe: float = _normalised_strafe(weapon, strafe_speed)
	var offset: Vector3 = Vector3(-turn.x - strafe, -turn.y, 0.0) * weapon.sway_position_m
	return offset * _aim_scale(weapon, aim_blend)


## Euler degrees (x pitch, y yaw, z roll) to add to the viewmodel.
static func target_rotation_deg(weapon: WeaponDefinition, turn_rate: Vector2, strafe_speed: float, aim_blend: float) -> Vector3:
	var turn: Vector2 = _normalised_turn(weapon, turn_rate)
	var strafe: float = _normalised_strafe(weapon, strafe_speed)
	var rotation_deg: Vector3 = Vector3(
		-turn.y * weapon.sway_pitch_deg,
		turn.x * weapon.sway_yaw_deg,
		turn.x * weapon.sway_roll_deg + strafe * weapon.sway_strafe_roll_deg)
	return rotation_deg * _aim_scale(weapon, aim_blend)


## Frame-rate independent smoothing toward target.
static func approach(current: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	return target + (current - target) * exp(-rate * delta)


static func _normalised_turn(weapon: WeaponDefinition, turn_rate: Vector2) -> Vector2:
	var reference: float = deg_to_rad(maxf(weapon.sway_ref_turn_deg_per_s, 0.001))
	return (turn_rate / reference).clampf(-1.0, 1.0)


static func _normalised_strafe(weapon: WeaponDefinition, strafe_speed: float) -> float:
	return clampf(strafe_speed / maxf(weapon.sway_ref_strafe_speed, 0.001), -1.0, 1.0)


static func _aim_scale(weapon: WeaponDefinition, aim_blend: float) -> float:
	return lerpf(1.0, weapon.sway_ads_mult, clampf(aim_blend, 0.0, 1.0))
