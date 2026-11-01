class_name ExposureComponent
extends Node
## How brightly lit the player is (design §9.1): the highest-priority LightVolume overlapping the
## player, else the level's ambient light; briefly raised by muzzle flash.
## Re-evaluated when volumes are entered or left, not every frame.

signal changed(exposure: float)

const FLASH_TIME_S: float = 0.1

## Authored light level at the player's position, without flash.
var light_level: float = 1.0
## Light level including muzzle flash. This is what AI vision uses.
var exposure: float = 1.0
## The volume currently setting the light level, or null when ambient applies.
var active_volume: LightVolume

var _volumes: Array[LightVolume] = []
var _ambient: float = 1.0
var _flash_level: float = 0.0
var _flash_remaining: float = 0.0


func _ready() -> void:
	var lighting: LevelLighting = get_tree().get_first_node_in_group(LevelLighting.GROUP) as LevelLighting
	if lighting != null:
		_ambient = lighting.ambient_light_level
	else:
		Log.warn(&"stealth", "Level has no LevelLighting; treating it as fully lit")
	_recompute()


func volume_entered(volume: LightVolume) -> void:
	_volumes.erase(volume)
	_volumes.append(volume)
	_recompute()


func volume_exited(volume: LightVolume) -> void:
	_volumes.erase(volume)
	_recompute()


## Raises exposure to at least `level` for a moment (muzzle flash, flashlight).
func flash(level: float) -> void:
	_flash_level = level
	_flash_remaining = FLASH_TIME_S
	_update_exposure()


func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining -= delta
		if _flash_remaining <= 0.0:
			_flash_level = 0.0
			_update_exposure()


func _recompute() -> void:
	_volumes = _volumes.filter(func(volume: LightVolume) -> bool: return is_instance_valid(volume))
	var priorities: Array[int] = []
	for volume: LightVolume in _volumes:
		priorities.append(volume.light_priority)
	var index: int = ExposureRules.pick(priorities)
	active_volume = _volumes[index] if index >= 0 else null
	light_level = active_volume.light_level if active_volume != null else _ambient
	_update_exposure()


func _update_exposure() -> void:
	var new_exposure: float = maxf(light_level, _flash_level)
	if not is_equal_approx(new_exposure, exposure):
		exposure = new_exposure
		changed.emit(exposure)
