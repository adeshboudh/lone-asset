class_name PlayerInput
extends Node
## Converts raw input into an InputIntent once per physics tick (design §3.2).

## When set, read_intent() returns this instead of reading devices (tests, AI dummies, replays).
var scripted_intent: InputIntent

var _intent: InputIntent = InputIntent.new()
var _look_delta: Vector2 = Vector2.ZERO
var _crouch_pressed: bool = false
var _jump_pressed: bool = false
## The trigger only counts after a press made while captured, so the click that resumes the game
## does not fire.
var _fire_armed: bool = false
var _fire_pressed: bool = false
var _reload_pressed: bool = false
var _fire_mode_pressed: bool = false
var _interact_pressed: bool = false
var _binoculars_pressed: bool = false
var _zoom_step: int = 0


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if Platform.is_mouse_captured():
			_look_delta += motion.relative
	elif event.is_action_pressed(&"crouch"):
		_crouch_pressed = true
	elif event.is_action_pressed(&"jump"):
		_jump_pressed = true
	elif event.is_action_pressed(&"fire"):
		if Platform.is_mouse_captured():
			_fire_armed = true
			_fire_pressed = true
	elif event.is_action_released(&"fire"):
		_fire_armed = false
	elif event.is_action_pressed(&"reload"):
		_reload_pressed = true
	elif event.is_action_pressed(&"fire_mode"):
		_fire_mode_pressed = true
	elif event.is_action_pressed(&"interact"):
		_interact_pressed = true
	elif event.is_action_pressed(&"binoculars"):
		_binoculars_pressed = true
	elif event.is_action_pressed(&"zoom_in"):
		_zoom_step += 1
	elif event.is_action_pressed(&"zoom_out"):
		_zoom_step -= 1


## Mouse movement since the last call, in pixels.
func take_look_delta() -> Vector2:
	var delta: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return delta


## Intent for this physics tick. One-shot presses (crouch, jump, trigger, reload, fire mode, interact) are consumed.
func read_intent() -> InputIntent:
	if scripted_intent != null:
		return scripted_intent
	_intent.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	_intent.sprint = Input.is_action_pressed(&"sprint")
	_intent.lean = int(Input.is_action_pressed(&"lean_right")) - int(Input.is_action_pressed(&"lean_left"))
	_intent.crouch_toggled = _crouch_pressed
	_intent.jump = _jump_pressed
	_intent.fire = _fire_armed and Input.is_action_pressed(&"fire")
	_intent.fire_pressed = _fire_pressed
	_intent.aim = Input.is_action_pressed(&"aim") and Platform.is_mouse_captured()
	_intent.reload = _reload_pressed
	_intent.fire_mode_toggled = _fire_mode_pressed
	_intent.interact = Input.is_action_pressed(&"interact") and Platform.is_mouse_captured()
	_intent.interact_pressed = _interact_pressed
	_intent.binoculars_toggled = _binoculars_pressed
	_intent.zoom_step = _zoom_step
	_crouch_pressed = false
	_jump_pressed = false
	_fire_pressed = false
	_reload_pressed = false
	_fire_mode_pressed = false
	_interact_pressed = false
	_binoculars_pressed = false
	_zoom_step = 0
	return _intent
