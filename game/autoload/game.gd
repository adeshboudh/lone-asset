extends Node
## Top-level game flow (design §2.2): title, loading, playing, paused.
## The scene tree is paused in every state except PLAYING and TITLE.
##
## Mouse capture rules (design §4.3):
## - capture is only requested from a click (browsers reject it otherwise);
## - PAUSED -> PLAYING only happens once the browser confirms the capture;
## - losing the capture while playing (Esc, alt-tab, tab hidden) pauses the game.

signal state_changed(old_state: GameStateMachine.State, new_state: GameStateMachine.State)

const TITLE_SCENE: String = "res://game/ui/title/title_screen.tscn"
const FIRST_LEVEL_SCENE: String = "res://game/levels/sandbox/sandbox.tscn"
const PAUSE_MENU_SCENE: PackedScene = preload("res://game/ui/pause/pause_menu.tscn")

var state: GameStateMachine.State:
	get:
		return _machine.state

var _machine: GameStateMachine = GameStateMachine.new()
var _pause_menu: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_machine.state_changed.connect(_on_state_changed)

	_pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(_pause_menu)
	_pause_menu.resume_requested.connect(resume)
	_pause_menu.quit_requested.connect(go_to_title)

	Platform.mouse_captured.connect(_on_mouse_captured)
	Platform.mouse_capture_lost.connect(pause)
	Platform.mouse_capture_failed.connect(_on_mouse_capture_failed)
	Platform.focus_lost.connect(pause)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		pause()
		get_viewport().set_input_as_handled()


## Called by the title screen when it is shown.
func enter_title() -> void:
	if state != GameStateMachine.State.TITLE:
		_machine.transition(GameStateMachine.State.TITLE)


## Called from the "Play" click, which is the user gesture that allows mouse capture and audio.
func start_game() -> void:
	if not _machine.transition(GameStateMachine.State.LOADING):
		return
	Platform.capture_mouse()
	var error: Error = get_tree().change_scene_to_file(FIRST_LEVEL_SCENE)
	if error != OK:
		Log.error(&"game", "Could not load %s (%s)" % [FIRST_LEVEL_SCENE, error_string(error)])
		_machine.transition(GameStateMachine.State.TITLE)


## Called by a level once it is ready to play.
func level_ready() -> void:
	if not _machine.transition(GameStateMachine.State.PLAYING):
		return
	if not Platform.is_mouse_captured() and not Platform.is_capture_pending():
		pause()


func pause() -> void:
	if state == GameStateMachine.State.PLAYING:
		_machine.transition(GameStateMachine.State.PAUSED)


## Requests mouse capture; the game resumes when the browser confirms it.
func resume() -> void:
	if state == GameStateMachine.State.PAUSED:
		Platform.capture_mouse()


func go_to_title() -> void:
	if _machine.transition(GameStateMachine.State.TITLE):
		get_tree().change_scene_to_file(TITLE_SCENE)


func _on_state_changed(old_state: GameStateMachine.State, new_state: GameStateMachine.State) -> void:
	var playing: bool = new_state == GameStateMachine.State.PLAYING
	var paused: bool = new_state == GameStateMachine.State.PAUSED
	get_tree().paused = not (playing or new_state == GameStateMachine.State.TITLE)
	if not playing:
		Platform.release_mouse()
	if paused:
		_pause_menu.open()
	else:
		_pause_menu.close()

	var name_text: String = GameStateMachine.state_name(new_state)
	Log.info(&"game", "%s -> %s" % [GameStateMachine.state_name(old_state), name_text])
	Platform.set_test_hook("state", name_text)
	state_changed.emit(old_state, new_state)


func _on_mouse_captured() -> void:
	if state == GameStateMachine.State.PAUSED:
		_machine.transition(GameStateMachine.State.PLAYING)


func _on_mouse_capture_failed() -> void:
	match state:
		GameStateMachine.State.PLAYING:
			pause()
			_pause_menu.show_capture_hint()
		GameStateMachine.State.PAUSED:
			_pause_menu.show_capture_hint()
