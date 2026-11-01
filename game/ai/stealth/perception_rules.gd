class_name PerceptionRules
extends RefCounted
## Pure vision rules (design §8.1, §8.3), unit-tested directly.

enum Cone { NONE, PRIMARY, PERIPHERAL }
enum Motion { STILL, WALK, SPRINT }

## Rays per vision check: head, chest and pelvis of the target.
const RAYS_PER_CHECK: int = 3
## Line of sight is blocked by world geometry and closed doors (physics layer 1).
const LOS_MASK: int = 1
## Below this speed (m/s) a player counts as standing still.
const STILL_SPEED: float = 0.3

const NEAR_DISTANCE_M: float = 15.0
const MID_DISTANCE_M: float = 40.0
const NEAR_INTERVAL_S: float = 0.1
const MID_INTERVAL_S: float = 0.2
const FAR_INTERVAL_S: float = 1.0


## Which vision cone the target is in, from the angle off the guard's facing (horizontal and vertical,
## absolute degrees) and the distance. Peripheral vision is wide but short.
static func classify(profile: GuardProfile, horizontal_deg: float, vertical_deg: float, distance: float) -> Cone:
	if vertical_deg > profile.vertical_limit_deg:
		return Cone.NONE
	if distance <= profile.primary_range_m and horizontal_deg <= profile.primary_fov_deg * 0.5:
		return Cone.PRIMARY
	if distance <= profile.peripheral_range_m and horizontal_deg <= profile.peripheral_fov_deg * 0.5:
		return Cone.PERIPHERAL
	return Cone.NONE


## Seconds between vision checks: nearer targets are checked more often; a guard in Combat always at 10 Hz.
static func update_interval(distance: float, in_combat: bool) -> float:
	if in_combat or distance < NEAR_DISTANCE_M:
		return NEAR_INTERVAL_S
	return MID_INTERVAL_S if distance < MID_DISTANCE_M else FAR_INTERVAL_S


static func motion_of(speed: float, sprinting: bool) -> Motion:
	if sprinting:
		return Motion.SPRINT
	return Motion.STILL if speed < STILL_SPEED else Motion.WALK


## Absolute horizontal angle in degrees between a facing direction and a direction to a target.
static func horizontal_angle_deg(facing: Vector3, to_target: Vector3) -> float:
	var f: Vector2 = Vector2(facing.x, facing.z)
	var t: Vector2 = Vector2(to_target.x, to_target.z)
	if f.length() < 0.0001 or t.length() < 0.0001:
		return 0.0
	return rad_to_deg(absf(f.angle_to(t)))


## Absolute angle in degrees above or below the horizontal.
static func vertical_angle_deg(to_target: Vector3) -> float:
	var flat: float = Vector2(to_target.x, to_target.z).length()
	return rad_to_deg(absf(atan2(to_target.y, flat)))
