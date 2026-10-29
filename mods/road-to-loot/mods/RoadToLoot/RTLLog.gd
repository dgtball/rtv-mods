extends RefCounted

const PREFIX := "[RTL] "
const LOG_DIR := "user://MCM/road-to-loot"
const LOG_FILE := LOG_DIR + "/rtl.log"

static func ensure_dir() -> void:
	DirAccess.make_dir_recursive_absolute(LOG_DIR)

static func clear() -> void:
	ensure_dir()
	var f := FileAccess.open(LOG_FILE, FileAccess.WRITE)
	if f != null:
		f.close()

static func _now() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [t.year, t.month, t.day, t.hour, t.minute, t.second]

static func _append(msg: String) -> void:
	ensure_dir()
	var f := FileAccess.open(LOG_FILE, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line("[" + _now() + "] " + msg)
	f.close()

static func line(msg: String) -> void:
	_append(PREFIX + msg)

static func warn(msg: String) -> void:
	_append("[WARN] " + PREFIX + msg)
