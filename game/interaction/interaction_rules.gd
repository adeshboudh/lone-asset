class_name InteractionRules
extends RefCounted
## Pure rules for interactions (design §12).


## Hold progress (0–1) after another delta seconds of holding. A zero duration completes at once.
static func advance_hold(progress: float, delta: float, duration: float) -> float:
	if duration <= 0.0:
		return 1.0
	return clampf(progress + delta / duration, 0.0, 1.0)
