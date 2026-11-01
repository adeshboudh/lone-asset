class_name InputIntent
extends RefCounted
## What the player wants to do this physics tick (design §3.2). Components read intents, never raw input,
## so scripted test dummies and replays can drive the same player. Mouse look is applied per rendered
## frame by Player and is not part of the intent.

## x: right, y: forward. Length ≤ 1.
var move: Vector2 = Vector2.ZERO
var sprint: bool = false
var crouch_toggled: bool = false
## -1 left, 0 none, 1 right.
var lean: int = 0
var jump: bool = false


func clear() -> void:
	move = Vector2.ZERO
	sprint = false
	crouch_toggled = false
	lean = 0
	jump = false
