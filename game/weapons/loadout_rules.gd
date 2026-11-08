class_name LoadoutRules
extends RefCounted
## Pure rules for the weapon slots: which slot a switch request lands on.


## requested is 1-based (the number keys); 0 means no request. Returns the slot to hold afterwards
## (0-based): the current one when nothing was asked, the slot does not exist, or switching is blocked.
static func slot_after(requested: int, current: int, count: int, can_switch: bool) -> int:
	if requested < 1 or requested > count or not can_switch:
		return current
	return requested - 1
