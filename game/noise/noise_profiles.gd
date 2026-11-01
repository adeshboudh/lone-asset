class_name NoiseProfiles
extends Resource
## Noise radii and footstep timing (design §8.2). Edited in data/noise/noise_profiles.tres.
## Shot radii come from each WeaponDefinition.

@export_group("Radius (m)")
@export var footstep_walk_m: float = 4.0
@export var footstep_sprint_m: float = 12.0
@export var footstep_crouch_m: float = 1.5
@export var landing_m: float = 8.0
@export var door_m: float = 10.0
@export var impact_m: float = 12.0

@export_group("Stride length (m between footsteps)")
@export var stride_walk_m: float = 1.8
@export var stride_sprint_m: float = 2.4
@export var stride_crouch_m: float = 1.2

@export_group("Surfaces")
## Footstep radius multiplier by the "surface" metadata of the floor. Unlisted surfaces count as 1.
@export var surface_footstep_multipliers: Dictionary[StringName, float] = {
	&"metal": 1.5,
	&"grass": 0.7,
}


func footstep_radius(type: StringName) -> float:
	match type:
		NoiseEvent.FOOTSTEP_SPRINT:
			return footstep_sprint_m
		NoiseEvent.FOOTSTEP_CROUCH:
			return footstep_crouch_m
		_:
			return footstep_walk_m


func stride(type: StringName) -> float:
	match type:
		NoiseEvent.FOOTSTEP_SPRINT:
			return stride_sprint_m
		NoiseEvent.FOOTSTEP_CROUCH:
			return stride_crouch_m
		_:
			return stride_walk_m


func surface_multiplier(surface: StringName) -> float:
	return surface_footstep_multipliers.get(surface, 1.0)
