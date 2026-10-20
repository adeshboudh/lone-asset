extends Node
## Web platform glue (design §2.2, §4.3): mouse capture (pointer lock), tab visibility,
## focus loss and browser test hooks. Also works in desktop/editor runs.

signal mouse_captured
signal mouse_capture_lost
## The browser did not grant the capture in time (e.g. the re-lock cooldown after Esc).
signal mouse_capture_failed
## Tab hidden or window lost focus.
signal focus_lost

## Object on `window` that browser tests (Playwright) read.
const JS_HOOK: String = "window.__lone_asset"
const CAPTURE_TIMEOUT_S: float = 1.5

var is_web: bool = OS.has_feature("web")

## Seconds (ticks) when capture was requested; negative when no request is pending.
var _capture_requested_at: float = -1.0
var _capture_confirmed: bool = false
## Must stay referenced, or the browser-side callback is released.
var _visibility_callback: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if is_web:
		JavaScriptBridge.eval("%s = %s || {};" % [JS_HOOK, JS_HOOK], true)
		_listen_for_visibility()
	Log.info(&"platform", "Started: %s, renderer %s, build %s" % [
		OS.get_name(),
		RenderingServer.get_current_rendering_method(),
		ProjectSettings.get_setting("application/config/version"),
	])


func _process(_delta: float) -> void:
	# Read the real capture state: on the web the browser can grant, refuse or drop the pointer lock at any time.
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


## Must be called while handling a click or key press.
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


## Called once the first screen is up. Browser tests wait for this flag.
func mark_ready() -> void:
	Log.info(&"platform", "Ready")
	set_test_hook("ready", true)


## Publishes a JSON-serialisable value on window.__lone_asset for browser tests.
func set_test_hook(key: String, value: Variant) -> void:
	if is_web:
		JavaScriptBridge.eval("%s[%s] = %s;" % [JS_HOOK, JSON.stringify(key), JSON.stringify(value)], true)


func _listen_for_visibility() -> void:
	_visibility_callback = JavaScriptBridge.create_callback(_on_visibility_change)
	var document: JavaScriptObject = JavaScriptBridge.get_interface("document")
	document.addEventListener("visibilitychange", _visibility_callback)


func _on_visibility_change(_args: Array) -> void:
	if JavaScriptBridge.eval("document.hidden", true):
		focus_lost.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
