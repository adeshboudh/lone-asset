extends GdUnitTestSuite
## The UI standard: everything is authored for a 1920x1080 picture (docs/architecture.md, "UI size standard").
## A 1080p window shows the HUD inside the screen, with the crosshair in the middle.

const PLAYER_SCENE: PackedScene = preload("res://game/player/player.tscn")
const SCREEN: Rect2 = Rect2(0.0, 0.0, 1920.0, 1080.0)

var _arena: Node3D
var _player: Player
var _window: Window
var _old_size: Vector2i


func before_test() -> void:
	_arena = auto_free(Node3D.new())
	add_child(_arena)
	_arena.add_child(BallisticsSystem.new())
	_player = PLAYER_SCENE.instantiate()
	_arena.add_child(_player)
	_window = get_tree().root
	_old_size = _window.size
	_window.size = Vector2i(1920, 1080)
	await get_tree().physics_frame
	await get_tree().physics_frame


func after_test() -> void:
	_window.size = _old_size


func test_the_project_standard_is_1920_by_1080() -> void:
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_width"))).is_equal(1920)
	assert_int(int(ProjectSettings.get_setting("display/window/size/viewport_height"))).is_equal(1080)
	assert_str(String(ProjectSettings.get_setting("display/window/stretch/mode"))).is_equal("canvas_items")
	assert_str(String(ProjectSettings.get_setting("display/window/stretch/aspect"))).is_equal("expand")


func test_the_crosshair_is_in_the_middle_of_the_picture() -> void:
	var crosshair: Control = (_player.get_node("Hud") as Hud).get_node("%Crosshair")
	assert_vector(crosshair.get_global_rect().get_center()).is_equal_approx(SCREEN.get_center(), Vector2(1.0, 1.0))


func test_every_hud_element_is_inside_the_picture_with_long_texts() -> void:
	var hud: Hud = (_player.get_node("Hud") as Hud)
	EventBus.toast_requested.emit("TOOK STANAG 30-ROUND (30, 5.56X45 SUBSONIC) AND MOVE IT TO THE RIG FIRST")
	for label: Label in [hud.get_node("%AmmoLabel"), hud.get_node("%HealthLabel"), hud.get_node("%StanceLabel"),
			hud.get_node("%ObjectiveList"), hud.get_node("%PromptLabel"), hud.get_node("%ToastLabel")]:
		label.text = "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWW"
	await get_tree().physics_frame
	await get_tree().physics_frame
	for node: Node in hud.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if not control.is_visible_in_tree() or control.size == Vector2.ZERO:
			continue
		var rect: Rect2 = control.get_global_rect()
		assert_bool(SCREEN.grow(1.0).encloses(rect)) \
			.override_failure_message("HUD element %s is %s, outside %s" % [control.name, rect, SCREEN]).is_true()


func test_the_default_field_of_view_is_the_standard_80_vertical() -> void:
	# Godot's FOV is vertical: 80 vertical is about 112.3 horizontal at 16:9.
	assert_float(_player.camera.fov).is_equal(80.0)
	var horizontal: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(80.0) * 0.5) * 16.0 / 9.0))
	assert_float(horizontal).is_equal_approx(112.3, 0.2)
