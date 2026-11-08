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
## Trigger held (only after a press made while the mouse was captured).
var fire: bool = false
## Trigger went down this tick.
var fire_pressed: bool = false
var aim: bool = false
var reload: bool = false
var fire_mode_toggled: bool = false
## Number key pressed this tick to pick a weapon: 1-based slot, 0 for none.
var weapon_slot: int = 0
## Interact key held, and went down this tick.
var interact: bool = false
var interact_pressed: bool = false
## Binoculars key went down this tick, and mouse wheel steps (+1 in, -1 out) since the last tick.
var binoculars_toggled: bool = false
var zoom_step: int = 0


func clear() -> void:
	move = Vector2.ZERO
	sprint = false
	crouch_toggled = false
	lean = 0
	jump = false
	fire = false
	fire_pressed = false
	aim = false
	reload = false
	fire_mode_toggled = false
	weapon_slot = 0
	interact = false
	interact_pressed = false
	binoculars_toggled = false
	zoom_step = 0
