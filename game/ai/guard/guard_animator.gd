class_name GuardAnimator
extends Node
## Plays the mocap clips on the guard's model. Reads the guard's horizontal speed and state each physics
## frame; the clip choice is in GuardAnimationRules. The model keeps its own AnimationPlayer.

@export var profile: GuardAnimationProfile
@export var guard: Guard
@export var player: AnimationPlayer

var _current: StringName = &""


func _ready() -> void:
	for clip_name: StringName in player.get_animation_list():
		player.get_animation(clip_name).loop_mode = Animation.LOOP_LINEAR


func _physics_process(_delta: float) -> void:
	if guard.is_dead:
		player.pause()
		return
	var speed: float = Vector2(guard.velocity.x, guard.velocity.z).length()
	var state: StringName = guard.brain.current_name
	var clip: StringName = GuardAnimationRules.clip_for(state, speed, profile)
	if clip != _current and player.has_animation(clip):
		_current = clip
		player.play(clip, profile.blend_s)
	player.speed_scale = GuardAnimationRules.speed_scale(speed, profile)


## The clip being played, for tests.
func current_clip() -> StringName:
	return _current
