extends RefCounted
# Single diagnostic-log sink for ThermalVTK. Every probe funnels through log(),
# so the enable gate and the file handle live in exactly one place. Off by
# default; turned on from the MCM "Debug log" option.

const LOG_PATH := "user://MCM/thermal-vtk/debug.log"

static var enabled := false
static var _file: FileAccess = null

static func set_enabled(v: bool) -> void:
	enabled = v
	if enabled:
		_open()

static func _open() -> void:
	if _file != null:
		return
	DirAccess.make_dir_recursive_absolute("user://MCM/thermal-vtk")
	# WRITE_READ, not READ_WRITE: READ_WRITE refuses to create a missing file,
	# WRITE_READ creates it and still does not truncate, so sessions append.
	_file = FileAccess.open(LOG_PATH, FileAccess.WRITE_READ)
	if _file == null:
		push_warning("[ThermalVTK] cannot open debug log %s err=%s" % [LOG_PATH, FileAccess.get_open_error()])
		return
	_file.seek_end()
	_file.store_line("=== session start %s v%s ===" % [_now_str(), _version()])
	_file.flush()

static func log(tag: String, msg: String) -> void:
	if not enabled:
		return
	_open()
	var line := "[%s]%s" % [_now_str(), fmt(tag, msg)]
	if _file != null:
		_file.store_line(line)
		_file.flush()
	print(line)

static func fmt(tag: String, msg: String) -> String:
	return "[%s] %s" % [tag, msg]

static func reset_for_tests() -> void:
	enabled = false
	if _file != null:
		_file.close()
		_file = null

static func _now_str() -> String:
	var dt := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02d %02d:%02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]

static func _version() -> String:
	var vf := FileAccess.open("res://mods/ThermalVTK/version.txt", FileAccess.READ)
	if vf == null:
		return "?"
	var v := vf.get_as_text().strip_edges()
	return v if v != "" else "?"
