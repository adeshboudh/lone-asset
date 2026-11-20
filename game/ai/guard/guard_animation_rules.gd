class_name GuardAnimationRules
extends RefCounted
## Picks the clip and playback speed for a guard from its state and speed. Pure logic, no nodes.


## True when the guard carries its rifle up (it has heard or seen something).
static func weapon_ready(state: StringName) -> bool:
	return state == GuardState.INVESTIGATE or state == GuardState.SEARCH or state == GuardState.COMBAT


static func is_jogging(speed: float, profile: GuardAnimationProfile) -> bool:
	return speed >= profile.jog_from_speed


static func clip_for(state: StringName, speed: float, profile: GuardAnimationProfile) -> StringName:
	var ready: bool = weapon_ready(state)
	if speed < profile.idle_below_speed:
		return profile.aim_idle if ready else profile.relaxed_idle
	if is_jogging(speed, profile):
		return profile.aim_jog if ready else profile.relaxed_jog
	return profile.aim_walk if ready else profile.relaxed_walk


## Playback speed that makes the clip's footsteps match the real ground speed. Standing clips play at 1.
static func speed_scale(speed: float, profile: GuardAnimationProfile) -> float:
	if speed < profile.idle_below_speed:
		return 1.0
	var reference: float = profile.jog_clip_speed if is_jogging(speed, profile) else profile.walk_clip_speed
	return clampf(speed / reference, profile.min_speed_scale, profile.max_speed_scale)
