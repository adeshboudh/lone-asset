class_name SoundBank
extends Resource
## Sound effects by id; each id has one or more variants (design §22). Written by
## tools/audio/make_placeholder_sounds.py while the sounds are placeholders. Replace a file, keep its name.

## StringName id -> Array of AudioStream variants.
@export var sounds: Dictionary = {}


func has_sound(id: StringName) -> bool:
	return sounds.has(id) and not (sounds[id] as Array).is_empty()


## A random variant of the sound, or null if the id is unknown.
func pick(id: StringName, rng: RandomNumberGenerator) -> AudioStream:
	if not has_sound(id):
		return null
	var variants: Array = sounds[id]
	return variants[rng.randi() % variants.size()] as AudioStream
