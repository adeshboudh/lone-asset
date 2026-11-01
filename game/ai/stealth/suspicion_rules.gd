class_name SuspicionRules
extends RefCounted
## Pure suspicion maths (design §9), unit-tested directly.

enum Band { NORMAL, CURIOUS, SUSPICIOUS, SEARCHING, COMBAT }

const MAX_SUSPICION: float = 100.0
## Lower edge of each band: 0–20 Normal, 20–40 Curious, 40–60 Suspicious, 60–80 Searching, 80–100 Combat.
const BAND_STARTS: Array[float] = [0.0, 20.0, 40.0, 60.0, 80.0]
## Distances up to this give the full sight rate.
const FULL_RATE_DISTANCE_M: float = 5.0
const FAR_DISTANCE_FACTOR: float = 0.15


static func band_of(value: float) -> Band:
	var band: int = Band.NORMAL
	for i: int in BAND_STARTS.size():
		if value >= BAND_STARTS[i]:
			band = i
	return band as Band


## 1.0 up close, falling smoothly to 0.15 at the end of the vision range.
static func distance_factor(distance: float, max_range: float) -> float:
	var t: float = smoothstep(FULL_RATE_DISTANCE_M, maxf(max_range, FULL_RATE_DISTANCE_M + 0.01), distance)
	return lerpf(1.0, FAR_DISTANCE_FACTOR, t)


static func light_factor(exposure: float) -> float:
	return lerpf(0.1, 1.0, clampf(exposure, 0.0, 1.0))


static func stance_factor(crouched: bool) -> float:
	return 0.6 if crouched else 1.0


static func motion_factor(motion: PerceptionRules.Motion) -> float:
	match motion:
		PerceptionRules.Motion.STILL:
			return 0.5
		PerceptionRules.Motion.SPRINT:
			return 1.6
		_:
			return 1.0


static func cone_factor(cone: PerceptionRules.Cone) -> float:
	return 0.4 if cone == PerceptionRules.Cone.PERIPHERAL else 1.0


## A guard that is already suspicious notices more easily.
static func state_factor(state_name: StringName) -> float:
	match state_name:
		GuardState.INVESTIGATE, GuardState.SEARCH:
			return 1.5
		GuardState.COMBAT:
			return 3.0
		_:
			return 1.0


## Suspicion gained per second while the target is visible (design §9.2).
static func sight_gain_per_second(profile: GuardProfile, visibility: float, distance: float, exposure: float,
		crouched: bool, motion: PerceptionRules.Motion, cone: PerceptionRules.Cone, state_name: StringName) -> float:
	return profile.sight_base_rate * visibility \
		* distance_factor(distance, profile.primary_range_m) \
		* light_factor(exposure) \
		* stance_factor(crouched) \
		* motion_factor(motion) \
		* cone_factor(cone) \
		* state_factor(state_name)


static func is_instant_detection(profile: GuardProfile, visibility: float, distance: float, exposure: float) -> bool:
	return distance <= profile.instant_distance_m \
		and visibility >= profile.instant_min_visibility \
		and exposure >= profile.instant_min_exposure
