extends GdUnitTestSuite
## Menu sounds: hover and press sounds come from UiSounds.wire, and the press sound is always the click.

var _played: Array[StringName] = []
var _recorder: Callable
var _root: Control
var _plain: Button
var _off: Button


func before_test() -> void:
	_root = auto_free(Control.new())
	_plain = Button.new()
	_off = Button.new()
	_off.disabled = true
	for button: Button in [_plain, _off]:
		_root.add_child(button)
	add_child(_root)
	UiSounds.wire(_root)
	_played.clear()
	_recorder = func(id: StringName, _bus: StringName) -> void: _played.append(id)
	Audio.sound_played.connect(_recorder)


func after_test() -> void:
	Audio.sound_played.disconnect(_recorder)


func test_pressing_a_button_plays_the_click() -> void:
	_plain.pressed.emit()
	assert_array(_played).is_equal([&"ui_click"])


func test_hover_and_focus_play_the_hover_sound() -> void:
	_plain.mouse_entered.emit()
	_plain.focus_entered.emit()
	assert_array(_played).is_equal([&"ui_hover", &"ui_hover"])


func test_disabled_button_does_not_play_hover() -> void:
	_off.mouse_entered.emit()
	assert_array(_played).is_empty()


func test_menu_scenes_have_sounds_on_every_button() -> void:
	for path: String in ["res://game/ui/pause/pause_menu.tscn", "res://game/ui/death/death_screen.tscn"]:
		var menu: Node = auto_free((load(path) as PackedScene).instantiate())
		add_child(menu)
		for node: Node in menu.find_children("*", "BaseButton", true, false):
			var button: BaseButton = node as BaseButton
			assert_bool(button.has_meta(UiSounds.WIRED)).override_failure_message("%s: %s has no menu sounds" % [path, button.name]).is_true()
