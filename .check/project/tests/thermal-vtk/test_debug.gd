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

class FakeESP extends Node:
	var contour_layer: bool = false
	var xray_layer: bool = false
	var marker_visible: bool = false
	func set_layers(contour: bool, xray: bool) -> void:
		contour_layer = contour
		xray_layer = xray
		marker_visible = contour

class FakeNVG extends Node:
	var set_palette: int = 0
	var palette_writes: int = 0
	var worn: bool = true
	func nvg_active() -> bool:
		return worn
	func set_palette_mode(mode: int) -> void:
		set_palette = mode
		palette_writes += 1
	func set_thermal_enabled(_v: bool) -> void:
		pass
	func set_mines_enabled(_v: bool) -> void:
		pass

# F6 cycles the world thermal palette, which only exists while the thermal
# picture is actually on screen. That takes both switches: the thermal toggle
# AND the helmet. Cycling it out of sight changed the palette behind the user's
# back and toasted a name nobody could see. The mod has to be in the tree:
# _notify reaches for /root/Loader by absolute path, which fails outside it.
func t_f6_guard() -> void:
	DirAccess.make_dir_recursive_absolute("user://MCM/thermal-vtk")
	var mod = ThermalMod.new()
	var nvg := FakeNVG.new()
	mod._nvg = nvg
	get_root().add_child(mod)
	nvg.set_palette = 0
	nvg.palette_writes = 0
	mod._thermal_enabled = true
	nvg.worn = false
	mod._cycle_palette()
	ck(nvg.palette_writes == 0, "F6 is a no-op while the helmet is off")
	nvg.worn = true
	mod._cycle_palette()
	ck(nvg.palette_writes == 1 and nvg.set_palette == 1, "F6 cycles while the thermal picture is up")
	mod._thermal_enabled = false
	mod._cycle_palette()
	ck(nvg.palette_writes == 1, "F6 is a no-op with thermal off")
	mod.queue_free()
	nvg.queue_free()
	if FileAccess.file_exists(ThermalMod.STATE_FILE):
		DirAccess.remove_absolute(ThermalMod.STATE_FILE)

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
	ck(not esp.contour_layer, "thermal off hides the ESP even with the helmet on")
	ck(not esp.marker_visible, "thermal off hides the nomad marker")
	mod.free()
	esp.free()
	nvg.free()
