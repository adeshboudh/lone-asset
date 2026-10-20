extends Node
## Levelled, categorised logging. Keeps a ring buffer of recent lines for bug reports.

enum Level { DEBUG, INFO, WARN, ERROR }

const BUFFER_SIZE: int = 500

var min_level: Level = Level.DEBUG if OS.is_debug_build() else Level.INFO

var _buffer: PackedStringArray = PackedStringArray()


func debug(category: StringName, message: String) -> void:
	_write(Level.DEBUG, category, message)


func info(category: StringName, message: String) -> void:
	_write(Level.INFO, category, message)


func warn(category: StringName, message: String) -> void:
	_write(Level.WARN, category, message)


func error(category: StringName, message: String) -> void:
	_write(Level.ERROR, category, message)


## Most recent log lines, oldest first.
func get_recent_lines() -> PackedStringArray:
	return _buffer.duplicate()


func _write(level: Level, category: StringName, message: String) -> void:
	if level < min_level:
		return
	var line: String = "[%s] [%s] %s" % [Level.keys()[level], category, message]
	match level:
		Level.WARN:
			push_warning(line)
		Level.ERROR:
			push_error(line)
		_:
			print(line)
	_buffer.append(line)
	if _buffer.size() > BUFFER_SIZE:
		_buffer.remove_at(0)
