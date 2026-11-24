class_name ProfileStore
extends RefCounted
## Reads and writes `user://saves/profile.json`: the operative carried from one mission to the next. Written
## atomically (temp file, then rename) like checkpoints.

const PATH: String = "user://saves/profile.json"
const TEMP_PATH: String = "user://saves/profile.json.tmp"


## Writes the player's profile. False when the file cannot be written.
static func write(player: Player) -> bool:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		Log.warn(&"save", "Could not open %s (%s)" % [TEMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(SaveRules.to_text(ProfileRules.build(player.save_state())))
	file.close()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	return DirAccess.rename_absolute(TEMP_PATH, PATH) == OK


## The saved profile, or an empty dictionary when there is none or it cannot be used.
static func read() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var data: Dictionary = SaveRules.from_text(FileAccess.get_file_as_string(PATH))
	var problem: String = ProfileRules.problem_with(data)
	if not problem.is_empty():
		Log.warn(&"save", "Ignoring profile: %s" % problem)
		return {}
	return data
