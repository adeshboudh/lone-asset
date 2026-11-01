class_name GuardAlertRules
extends RefCounted
## Which state a guard's suspicion pushes it into (design §7.2). Pure logic, unit-tested.
##
## Suspicion only escalates a guard; getting calm again is up to each state (timeouts, lost target).


## Returns the state the guard should switch to, or &"" to stay as it is.
## `has_contact` is true while the guard has recently seen the player or been hurt by them: a guard
## that only heard gunfire searches "combat ready" instead of fighting an enemy it has not found.
static func target_state(current: StringName, band: SuspicionRules.Band, has_contact: bool) -> StringName:
	if current == GuardState.DEAD:
		return &""
	if band >= SuspicionRules.Band.COMBAT:
		if has_contact:
			return &"" if current == GuardState.COMBAT else GuardState.COMBAT
		return GuardState.SEARCH if _is_calm(current) or current == GuardState.INVESTIGATE else &""
	if band >= SuspicionRules.Band.SEARCHING:
		return GuardState.SEARCH if _is_calm(current) or current == GuardState.INVESTIGATE else &""
	if band >= SuspicionRules.Band.SUSPICIOUS:
		return GuardState.INVESTIGATE if _is_calm(current) else &""
	return &""


static func _is_calm(state: StringName) -> bool:
	return state == GuardState.PATROL or state == GuardState.RETURN_TO_PATROL
