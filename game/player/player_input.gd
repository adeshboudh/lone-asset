class_name PlayerInput
extends Node
## Converts raw input into an InputIntent once per physics tick (design §3.2).

## When set, read_intent() returns this instead of reading devices (tests, AI dummies, replays).
var scripted_intent: InputIntent

var _intent: InputIntent = InputIntent.new()
var _look_delta: Vector2 = Vector2.ZERO
var _crouch_pressed: bool = false
var _jump_pressed: bool = false


func _unhandled_input(event: InputEvent) -> void:
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if Platform.is_mouse_captured():
			_look_delta += motion.relative
	elif event.is_action_pressed(&"crouch"):
		_crouch_pressed = true
	elif event.is_action_pressed(&"jump"):
		_jump_pressed = true


## Mouse movement since the last call, in pixels.
func take_look_delta() -> Vector2:
	var delta: Vector2 = _look_delta
	_look_delta = Vector2.ZERO
	return delta


## Intent for this physics tick. One-shot presses (crouch toggle, jump) are consumed.
func read_intent() -> InputIntent:
	if scripted_intent != null:
		return scripted_intent
	_intent.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	_intent.sprint = Input.is_action_pressed(&"sprint")
	_intent.lean = int(Input.is_action_pressed(&"lean_right")) - int(Input.is_action_pressed(&"lean_left"))
	_intent.crouch_toggled = _crouch_pressed
	_intent.jump = _jump_pressed
	_crouch_pressed = false
	_jump_pressed = false
	return _intent
