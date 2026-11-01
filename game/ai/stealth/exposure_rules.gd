class_name ExposureRules
extends RefCounted
## Pure rule for which light volume applies (design §9.1).


## Index of the volume with the highest priority; among equals, the one entered last (later in the list).
## Returns -1 for an empty list.
static func pick(priorities: Array[int]) -> int:
	var best: int = -1
	for i: int in priorities.size():
		if best == -1 or priorities[i] >= priorities[best]:
			best = i
	return best
