class_name SuspicionModel
extends RefCounted
## One guard's suspicion, 0–100 (design §9). Pure logic: sight, sound and damage push it up; it decays
## once nothing new has happened for a while. Never goes below the current floor.

signal band_changed(old_band: SuspicionRules.Band, new_band: SuspicionRules.Band)

var profile: GuardProfile
var value: float = 0.0
var band: SuspicionRules.Band:
	get:
		return SuspicionRules.band_of(value)
## Lowest value suspicion decays to right now.
var floor_value: float:
	get:
		return _floor_value if _time < _floor_until else 0.0
## Seconds since something raised suspicion.
var seconds_since_stimulus: float:
	get:
		return _since_stimulus

var _time: float = 0.0
var _since_stimulus: float = 0.0
var _floor_value: float = 0.0
var _floor_until: float = 0.0


func _init(guard_profile: GuardProfile) -> void:
	profile = guard_profile


## Time passing. Call every physics tick.
func update(delta: float) -> void:
	_time += delta
	_since_stimulus += delta
	if _since_stimulus >= profile.decay_delay_s:
		_set_value(maxf(value - profile.decay_rate * delta, minf(floor_value, value)))


## A vision check saw the target. `dt` is the time the sighting covers (since the previous check).
func add_sight(visibility: float, distance: float, exposure: float, crouched: bool,
		motion: PerceptionRules.Motion, cone: PerceptionRules.Cone, state_name: StringName, dt: float) -> void:
	if visibility <= 0.0:
		return
	if SuspicionRules.is_instant_detection(profile, visibility, distance, exposure):
		_set_value(SuspicionRules.MAX_SUSPICION)
	else:
		var gain: float = SuspicionRules.sight_gain_per_second(profile, visibility, distance, exposure, crouched, motion, cone, state_name)
		_set_value(value + gain * dt)
	_since_stimulus = 0.0


## Heard a noise of this NoiseEvent type (design §9.3).
func add_noise(type: StringName) -> void:
	match type:
		NoiseEvent.SHOT:
			_set_value(maxf(value, profile.noise_loud_level))
		NoiseEvent.SHOT_SUPPRESSED, NoiseEvent.IMPACT:
			_set_value(value + profile.noise_quiet_gain)
		_:
			# Footsteps, landings and doors: a nudge that cannot push past the cap.
			if value < profile.noise_step_cap:
				_set_value(minf(value + profile.noise_step_gain, profile.noise_step_cap))
	_since_stimulus = 0.0


func on_damage() -> void:
	_set_value(SuspicionRules.MAX_SUSPICION)
	_since_stimulus = 0.0


## Suspicion will not decay below `level` for `duration` seconds (negative: for good).
func raise_floor(level: float, duration: float) -> void:
	if level < floor_value:
		return
	_floor_value = level
	_floor_until = INF if duration < 0.0 else _time + duration


func set_value(new_value: float) -> void:
	_set_value(new_value)


func _set_value(new_value: float) -> void:
	var old_band: SuspicionRules.Band = band
	value = clampf(new_value, 0.0, SuspicionRules.MAX_SUSPICION)
	var new_band: SuspicionRules.Band = band
	if new_band != old_band:
		band_changed.emit(old_band, new_band)
