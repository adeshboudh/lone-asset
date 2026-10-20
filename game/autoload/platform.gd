extends Node
## Web platform glue. Milestone 1 / WP 1: browser test hooks.
## WP 2 adds pointer-lock tracking, tab-visibility pause and storage persistence.

## Object on `window` that browser tests (Playwright) read.
const JS_HOOK: String = "window.__lone_asset"

var is_web: bool = OS.has_feature("web")


func _ready() -> void:
	if is_web:
		JavaScriptBridge.eval("%s = %s || {};" % [JS_HOOK, JS_HOOK], true)
	Log.info(&"platform", "Started: %s, renderer %s, build %s" % [
		OS.get_name(),
		RenderingServer.get_current_rendering_method(),
		ProjectSettings.get_setting("application/config/version"),
	])


## Called once the first playable scene is up. Browser tests wait for this flag.
func mark_ready() -> void:
	Log.info(&"platform", "Ready")
	if is_web:
		JavaScriptBridge.eval("%s.ready = true;" % JS_HOOK, true)
