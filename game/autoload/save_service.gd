extends Node
## Checkpoint saving and loading (design §16). Checkpoints only: written when an objective that asks
## for one is completed, and restored by Continue, Retry and "restart from checkpoint".

const PATH: String = "user://saves/checkpoint.json"
const TEMP_PATH: String = "user://saves/checkpoint.json.tmp"

## A checkpoint to apply once the next level is ready (see Game.level_ready).
var pending: Dictionary = {}



func _ready() -> void:
	EventBus.checkpoint_requested.connect(func(_objective_id: StringName) -> void: save_checkpoint.call_deferred())
	Mission.mission_completed.connect(delete_checkpoint)


func has_checkpoint() -> bool:
	return not read_checkpoint().is_empty()


## The saved checkpoint, migrated to the current schema; empty if there is none or it cannot be used.
func read_checkpoint() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var data: Dictionary = SaveRules.from_text(FileAccess.get_file_as_string(PATH))
	var problem: String = SaveRules.problem_with(data)
	if not problem.is_empty():
		Log.warn(&"save", "Ignoring checkpoint: %s" % problem)
		return {}
	return SaveRules.migrate(data)


func delete_checkpoint() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


## Collects the state of the running level and writes it. Returns false if there is nothing to save.
func save_checkpoint() -> bool:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player == null or Mission.state.is_finished:
		return false
	var data: Dictionary = {
		"schema_version": SaveRules.SCHEMA_VERSION,
		"build_id": str(ProjectSettings.get_setting("application/config/version")),
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"mission_id": String(Mission.state.definition.id),
		"mission": Mission.save_state(),
		"objectives": Mission.state.save_state()["objectives"],
		"player": player.save_state(),
		"guards": [],
		"world": {"doors": {}, "terminals": {}},
	}
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		data["guards"].append((node as Guard).save_state())
	for node: Node in get_tree().get_nodes_in_group(&"doors"):
		var door: Door = node as Door
		data["world"]["doors"][String(door.door_id)] = door.save_state()
	for node: Node in get_tree().get_nodes_in_group(&"terminals"):
		var terminal: Terminal = node as Terminal
		data["world"]["terminals"][String(terminal.terminal_id)] = terminal.save_state()
	data["world"]["tags"] = player.binoculars.save_state()
	var ok: bool = _write(data)
	if ok:
		Log.info(&"save", "Checkpoint saved")
	return ok


## Puts a checkpoint's state back into the level that was just loaded.
func apply(data: Dictionary) -> void:
	var player: Player = get_tree().get_first_node_in_group(&"player") as Player
	if player != null:
		player.load_state(data.get("player", {}))
		player.binoculars.load_state(data.get("world", {}).get("tags", {}))
	var saved_guards: Dictionary = {}
	for entry: Dictionary in data.get("guards", []):
		saved_guards[StringName(entry["guard_id"])] = entry
	for node: Node in get_tree().get_nodes_in_group(&"guards"):
		var guard: Guard = node as Guard
		if saved_guards.has(guard.guard_id):
			guard.load_state(saved_guards[guard.guard_id])
	var world: Dictionary = data.get("world", {})
	for node: Node in get_tree().get_nodes_in_group(&"doors"):
		var door: Door = node as Door
		door.load_state(world.get("doors", {}).get(String(door.door_id), {}))
	for node: Node in get_tree().get_nodes_in_group(&"terminals"):
		var terminal: Terminal = node as Terminal
		terminal.load_state(world.get("terminals", {}).get(String(terminal.terminal_id), {}))
	Mission.load_state(data.get("mission", {}), data.get("objectives", {}))


## Opens the folder holding the checkpoint in the system file manager, so players can back it up or
## copy a save in.
func open_save_folder() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	OS.shell_open(ProjectSettings.globalize_path(PATH.get_base_dir()))


## Validates and stores a save given as text. Returns [success, message].
func import_text(text: String) -> Array:
	var data: Dictionary = SaveRules.from_text(text)
	var problem: String = SaveRules.problem_with(data)
	if problem.is_empty() and not _write(SaveRules.migrate(data)):
		problem = "The save could not be written."
	if problem.is_empty():
		return [true, "Save imported."]
	return [false, problem]


## Temp file first, then swap it in, so a crash mid-write cannot leave half a save.
func _write(data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		Log.warn(&"save", "Could not open %s (%s)" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(SaveRules.to_text(data))
	file.close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	return DirAccess.rename_absolute(TEMP_PATH, PATH) == OK
