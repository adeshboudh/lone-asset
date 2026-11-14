class_name TracerRules
extends RefCounted
## Pure rules for bullet tracers: which shots show one and how long the visible streak is.


## True when the shot with this index (0 for the first shot) gets a tracer. every_n <= 1 means every shot.
static func shows_tracer(shot_index: int, every_n: int) -> bool:
	return every_n <= 1 or shot_index % every_n == 0


## Length of the streak behind the bullet's head. Nothing is drawn until the bullet has flown start_m
## from the muzzle (so the streak does not fill the screen), then it grows to full length, and it
## never reaches back past the start point.
static func visible_length(travelled_m: float, start_m: float, length_m: float) -> float:
	return clampf(travelled_m - start_m, 0.0, length_m)
