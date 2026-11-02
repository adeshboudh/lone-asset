extends Node
## Platform glue (design §2.2, §4.3): mouse capture and window focus loss.

signal mouse_captured
signal mouse_capture_lost
## The capture was not granted in time.
signal mouse_capture_failed
## The window lost focus.
signal focus_lost

const CAPTURE_TIMEOUT_S: float = 1.5

## Seconds (ticks) when capture was requested; negative when no request is pending.
var _capture_requested_at: float = -1.0
var _capture_confirmed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Log.info(&"platform", "Started: %s, renderer %s, build %s" % [
		OS.get_name(),
		RenderingServer.get_current_rendering_method(),
		ProjectSettings.get_setting("application/config/version"),
	])


func _process(_delta: float) -> void:
	# Read the real capture state: the window manager can drop the capture at any time (alt-tab).
	var captured: bool = DisplayServer.mouse_get_mode() == DisplayServer.MOUSE_MODE_CAPTURED
	if is_capture_pending():
		if captured:
			_capture_requested_at = -1.0
			_capture_confirmed = true
			mouse_captured.emit()
		elif _now() - _capture_requested_at > CAPTURE_TIMEOUT_S:
			_capture_requested_at = -1.0
			Log.warn(&"platform", "Mouse capture not granted")
			mouse_capture_failed.emit()
	elif _capture_confirmed and not captured:
		_capture_confirmed = false
		mouse_capture_lost.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		focus_lost.emit()


func capture_mouse() -> void:
	_capture_requested_at = _now()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func release_mouse() -> void:
	_capture_requested_at = -1.0
	_capture_confirmed = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_mouse_captured() -> bool:
	return _capture_confirmed


func is_capture_pending() -> bool:
	return _capture_requested_at >= 0.0


## Called once the first screen is up. The smoke test waits for this line.
func mark_ready() -> void:
	Log.info(&"platform", "Ready")


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
