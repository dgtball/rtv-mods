extends SceneTree

const ESP = preload("res://mods/ThermalVTK/VTKESP.gd")
const ThermalMod = preload("res://mods/ThermalVTK/ThermalVTK.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")

const SRC := "res://mods/ThermalVTK/ThermalVTK.gd"
const SET_SRC := "res://mods/ThermalVTK/VTKSettings.gd"

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_fill_keys_gone()
	t_rim_and_decay_defaults()
	t_single_state_source()
	t_mcm_labels()
	print("")
	if fails == 0:
		print("Preset tests passed")
		quit(0)
	else:
		print("Preset tests failed: ", fails)
		quit(1)

# The body fill is gone: the ESP has no fill field and the MCM registers no
# fill setting, so the outline always draws the ring alone.
func t_fill_keys_gone() -> void:
	var esp = ESP.new()
	ck(esp.get("p_fill") == null, "ESP has no p_fill field")
	ck(esp.get("p_fill_alpha") == null, "ESP has no p_fill_alpha field")
	esp.free()
	var src := FileAccess.get_file_as_string(SRC)
	ck(not src.contains("outline_body_fill"), "MCM drops outline_body_fill")
	ck(not src.contains("\"fill_opacity\""), "MCM drops fill_opacity")
	ck(not src.contains("PRESET_FILL_ALPHA"), "PRESET_FILL_ALPHA is gone")
	ck(not src.contains("_apply_style_preset"), "the fill preset is gone")

# The outline no longer offers a style dropdown: it always draws the ring.
# The rim defaults to 2.0 in steps of 0.5, and the cooling time to 30 s over
# a 0..180 window. The descriptor table is the single registration source.
func _descr(key: String) -> Dictionary:
	for r in Settings.DESCRIPTORS:
		if r["key"] == key:
			return r
	return {}

func t_rim_and_decay_defaults() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	var set_src := FileAccess.get_file_as_string(SET_SRC)
	ck(not (src + set_src).contains("outline_style"), "MCM drops the outline_style dropdown")
	var rim := _descr("outline_rim")
	ck(float(rim.get("def", -1.0)) == 2.0 and float(rim.get("step", -1.0)) == 0.5
		and float(rim.get("max", -1.0)) == 6.0, "outline_rim is 2.0 in 0.5 steps up to 6.0")
	var decay := _descr("corpse_decay")
	ck(float(decay.get("def", -1.0)) == 90.0 and float(decay.get("max", -1.0)) == 180.0,
		"corpse_decay defaults to 90 s and tops out at 180 s")

# The thermal toggle and the world palette live in our own state file only.
# A second source of truth (an MCM checkbox or dropdown) fought the hotkey on
# every menu round-trip, so both MCM entries are gone.
func t_single_state_source() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	ck(not src.contains("\"thermal_enabled\", {"), "MCM drops the thermal_enabled entry")
	ck(not src.contains("\"thermal_palette\", {"), "MCM drops the thermal_palette dropdown")
	ck(not src.contains("_mcm_thermal_seen"), "the MCM/state reconcile is gone")
	ck(not src.contains("_mcm_palette_seen"), "the palette reconcile is gone")
	ck(not src.contains("LEGACY_PALETTE"), "the legacy palette map is gone")
	ck(src.contains("_read_state(\"thermal_enabled\", false)"),
		"the thermal toggle is read from the state file")
	ck(src.contains("_read_state(\"world_palette\", null)"),
		"the world palette is read from the state file")

# The panel labels dropped the duplicated "Outline"/"Contour" prefixes, the
# range block is gone (the distance moved into the ESP block) and the debug
# hotkey moved next to the other diagnostics.
func t_mcm_labels() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	var set_src := FileAccess.get_file_as_string(SET_SRC)
	ck((src + set_src).contains("NPC highlighting (ESP)"), "the contour entry is called NPC highlighting (ESP)")
	ck((src + set_src).contains("Rim"), "the rim entry lost the Outline prefix")
	ck((src + set_src).contains("\"Thickness\""), "the thickness entry lost the Outline prefix")
	ck(set_src.contains("\"Brightness\""), "the brightness entry lost the Outline prefix")
	ck((src + set_src).contains("Cooling time"), "the cooling entry is called Cooling time")
	ck(set_src.contains("\"Default\""), "the idle state colour is called Default")
	ck(not (src + set_src).contains("04. Contour Range"), "the separate range block is gone")
	ck(_descr("outline_distance").get("sect") == "Float"
		and _descr("outline_distance").get("name") == "Distance"
		and _descr("outline_distance").get("cat").begins_with("02."), "the distance moved into the ESP block")
