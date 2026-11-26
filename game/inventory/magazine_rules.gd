class_name MagazineRules
extends RefCounted
## Pure rules for magazines: what fits what, loading and unloading one round, how full a magazine looks, and which
## spare magazine a reload takes. Calibers and families are kept apart (spec "Calibers and fit").


## Magazine fit: the weapon takes the magazine's family.
static func can_insert(weapon: WeaponDefinition, magazine: Magazine) -> bool:
	return weapon.magazine_families.has(magazine.type.family)


## Load fit: the round's caliber is one the magazine accepts and there is room. Ammo types may mix: the last round
## loaded is the first fired.
static func can_load(magazine: Magazine, ammo: AmmoType) -> bool:
	return not magazine.is_full() and magazine.type.accepted_calibers.has(ammo.caliber)


static func load_round(magazine: Magazine, ammo: AmmoType) -> bool:
	if not can_load(magazine, ammo):
		return false
	magazine.rounds.append(ammo.id)
	return true


## Removes the top round and returns its ammo id, or an empty id when the magazine is empty.
static func unload_round(magazine: Magazine) -> StringName:
	if magazine.is_empty():
		return &""
	return magazine.rounds.pop_back()


static func fullness(magazine: Magazine) -> float:
	return float(magazine.count()) / float(maxi(magazine.type.capacity, 1))


static func fullness_label(magazine: Magazine) -> String:
	var fraction: float = fullness(magazine)
	if magazine.is_empty():
		return "empty"
	if fraction >= 1.0:
		return "full"
	if fraction > 0.66:
		return "mostly full"
	if fraction > 0.33:
		return "about half"
	return "nearly empty"


## Index in `pouches` of the magazine a reload takes, or -1. A candidate fits the weapon and holds more rounds than
## `rounds_in_gun_magazine` (swapping for a fuller one only). Preference: the ammo the gun already uses, then the
## fullest, then the lowest index.
static func best_magazine(pouches: Array[Magazine], weapon: WeaponDefinition, current_ammo: StringName, rounds_in_gun_magazine: int) -> int:
	var best: int = -1
	for i: int in pouches.size():
		var candidate: Magazine = pouches[i]
		if not can_insert(weapon, candidate) or candidate.count() <= rounds_in_gun_magazine:
			continue
		if best < 0 or _better(candidate, pouches[best], current_ammo):
			best = i
	return best


static func _better(candidate: Magazine, best: Magazine, current_ammo: StringName) -> bool:
	var candidate_same: bool = candidate.top() == current_ammo
	var best_same: bool = best.top() == current_ammo
	if candidate_same != best_same:
		return candidate_same
	return candidate.count() > best.count()
