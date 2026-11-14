class_name LoadoutRules
extends RefCounted
## Pure rules for the weapon slots: which slot a switch request lands on, and the attachment swap.


## requested is 1-based (the number keys); 0 means no request. Returns the slot to hold afterwards
## (0-based): the current one when nothing was asked, the slot does not exist, or switching is blocked.
static func slot_after(requested: int, current: int, count: int, can_switch: bool) -> int:
	if requested < 1 or requested > count or not can_switch:
		return current
	return requested - 1


## The attachment can be swapped when the weapon has a variant and is not busy reloading or swapping.
static func can_swap_variant(has_variant: bool, reloading: bool, swapping: bool) -> bool:
	return has_variant and not reloading and not swapping
