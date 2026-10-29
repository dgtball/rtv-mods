extends SceneTree

const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const ThermalMod = preload("res://mods/ThermalVTK/ThermalVTK.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _wipe() -> void:
	if FileAccess.file_exists(Dbg.LOG_PATH):
		DirAccess.remove_absolute(Dbg.LOG_PATH)

# The sink's file handle is module state: a test that wipes the log has to
# close it first, or the running session keeps appending to the deleted file.
func _reset_sink() -> void:
	if Dbg._file != null:
		Dbg._file.close()
		Dbg._file = null
	Dbg.enabled = false

func _run() -> void:
	_reset_sink()
	_wipe()
	t_fmt()
	t_disabled_writes_nothing()
	_wipe()
	t_enabled_creates_and_appends()
	_reset_sink()
	_wipe()
	t_f6_guard()
	t_marker_follows_contour_gate()
	print("")
	if fails == 0:
		print("Debug tests passed")
		quit(0)
	else:
		print("Debug tests failed: ", fails)
		quit(1)

func t_fmt() -> void:
	ck(Dbg.fmt("ESP", "x") == "[ESP] x", "fmt composes [TAG] msg")

# The gate must stop the file from ever being created, not just stop writes.
func t_disabled_writes_nothing() -> void:
	Dbg.set_enabled(false)
	Dbg.log("ESP", "should not create")
	ck(not FileAccess.file_exists(Dbg.LOG_PATH), "disabled log creates no file")

func t_enabled_creates_and_appends() -> void:
	Dbg.set_enabled(true)
	Dbg.log("ESP", "hello")
	ck(FileAccess.file_exists(Dbg.LOG_PATH), "enabled log creates file")
	var txt := ""
	if FileAccess.file_exists(Dbg.LOG_PATH):
		var f := FileAccess.open(Dbg.LOG_PATH, FileAccess.READ)
		if f != null:
			txt = f.get_as_text()
			f.close()
	ck(txt.contains("[ESP] hello"), "file holds the logged line")
	ck(txt.contains("session start"), "file holds a session header")

# F6 cycles the world thermal palette, which only exists while thermal vision
# is on. Cycling it with thermal off changed the palette behind the user's back
# and toasted a palette name nobody could see. The palette lives behind the
# game's Loader, so the guard is asserted on the source.
func t_f6_guard() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/ThermalVTK.gd")
	var idx := src.find("func _cycle_palette")
	ck(idx >= 0, "cycle_palette present")
	if idx < 0:
		return
	var body := src.substr(idx, 260)
	ck(body.contains("if not _thermal_enabled"), "F6 early-returns when thermal is off")

class FakeESP extends Node:
	var contour_layer: bool = false
	var xray_layer: bool = false
	var marker_visible: bool = false
	func set_layers(contour: bool, xray: bool) -> void:
		contour_layer = contour
		xray_layer = xray
		marker_visible = contour

class FakeNVG extends Node:
	func nvg_active() -> bool:
		return true

# The friendly-nomad marker is part of the contour: with the contour switched
# off there is no outline to sit on, so the marker has to disappear with it.
func t_marker_follows_contour_gate() -> void:
	var mod = ThermalMod.new()
	var esp := FakeESP.new()
	var nvg := FakeNVG.new()
	mod._esp = esp
	mod._nvg = nvg
	mod._thermal_enabled = true
	mod._outline_enabled = false
	mod._apply_mode()
	ck(esp.contour_layer == false, "contour off disables the ESP")
	ck(esp.xray_layer == true, "x-ray stays live while the contour is off")
	ck(esp.marker_visible == false, "contour off hides the nomad marker")
	mod._outline_enabled = true
	mod._apply_mode()
	ck(esp.contour_layer == true and esp.xray_layer == true, "contour on enables both layers")
	ck(esp.marker_visible == true, "contour on shows the nomad marker")
	mod._thermal_enabled = false
	mod._apply_mode()
	ck(esp.contour_layer == false and esp.xray_layer == false, "thermal off disables the ESP")
	ck(esp.marker_visible == false, "thermal off hides the nomad marker")
	mod.free()
	esp.free()
	nvg.free()
