class_name AudioRules
extends RefCounted
## Pure audio rules (design §22), unit-tested directly.

## Quieter by this much for each wall between the sound and the listener.
const DB_PER_WALL: float = -6.0
## Sounds closer than this are never treated as occluded (own footsteps, own weapon).
const MIN_OCCLUSION_DISTANCE_M: float = 2.0
const MUFFLED_SUFFIX: String = "_muffled"
## Surfaces with their own footstep and landing sounds; anything else uses generic.
const FOOTSTEP_SURFACES: Array[StringName] = [&"concrete", &"dirt", &"grass", &"metal"]
const GENERIC_SURFACE: StringName = &"generic"


static func occlusion_volume_db(walls: int) -> float:
	return DB_PER_WALL * minf(float(walls), float(NoiseRules.MAX_WALLS))


## Id of the sound to play: the pre-muffled copy when walls are in the way and one exists.
static func variant_id(id: StringName, walls: int, has_muffled: bool) -> StringName:
	return StringName(String(id) + MUFFLED_SUFFIX) if walls > 0 and has_muffled else id


## Sound id of one footstep: `footstep_<surface>`.
static func footstep_id(surface: StringName) -> StringName:
	return StringName("footstep_" + String(_sound_surface(surface)))


## Sound id of a landing: `landing_<surface>`.
static func landing_id(surface: StringName) -> StringName:
	return StringName("landing_" + String(_sound_surface(surface)))


static func _sound_surface(surface: StringName) -> StringName:
	return surface if surface in FOOTSTEP_SURFACES else GENERIC_SURFACE
