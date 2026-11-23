class_name PlayerAudio
extends Node
## The player's own footsteps and landings (design §22). Non-positional: they come from the player.

const FOOTSTEP_DB: Dictionary[StringName, float] = {
	NoiseEvent.FOOTSTEP_CROUCH: -9.0,
	NoiseEvent.FOOTSTEP_WALK: -3.0,
	NoiseEvent.FOOTSTEP_SPRINT: 0.0,
}
const LANDING_MIN_FALL_M: float = NoiseEmitterComponent.LANDING_MIN_FALL_M

func on_step(type: StringName, surface: StringName) -> void:
	Audio.play_2d(AudioRules.footstep_id(surface), &"Footsteps", FOOTSTEP_DB.get(type, -3.0))


func on_landed(fall_height: float, surface: StringName) -> void:
	if fall_height >= LANDING_MIN_FALL_M:
		Audio.play_2d(AudioRules.landing_id(surface), &"Footsteps", clampf(-6.0 + fall_height * 2.0, -6.0, 3.0))
