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
	t_no_fill_toggle()
	t_fill_keys_present()
	t_thickness_and_decay_defaults()
	t_single_state_source()
	t_mcm_labels()
	print("")
	if fails == 0:
		print("Preset tests passed")
		quit(0)
	else:
		print("Preset tests failed: ", fails)
		quit(1)

func t_no_fill_toggle() -> void:
	var set_src := FileAccess.get_file_as_string(SET_SRC)
	ck(not set_src.contains("\"body_fill\""), "MCM drops the full-body fill toggle")
	ck(set_src.contains("OUTLINE_THICKNESS"), "thickness default comes from the shared constant")
	ck(set_src.contains("OUTLINE_BRIGHTNESS"), "brightness default comes from the shared constant")
	ck(set_src.contains("FILL_ALPHA"), "fill alpha default comes from the shared constant")

# Full-body fill is configurable: ESP carries fill mode/alpha and MCM registers
# body_fill and fill_alpha.
func t_fill_keys_present() -> void:
	var esp = ESP.new()
	ck(esp.get("p_body_fill") != null, "ESP has a p_body_fill field")
	ck(esp.get("p_fill_alpha") != null, "ESP has a p_fill_alpha field")
	esp.free()
	var set_src := FileAccess.get_file_as_string(SET_SRC)
	ck(set_src.contains("\"fill_alpha\""), "MCM registers fill_alpha")
	ck(not set_src.contains("PRESET_FILL_ALPHA"), "PRESET_FILL_ALPHA is gone")
	ck(not FileAccess.get_file_as_string(SRC).contains("_apply_style_preset"), "the fill preset is gone")

# The outline no longer offers a style dropdown: it always draws a solid ring.
# Thickness and cooling time live in the descriptor table as the single source.
func _descr(key: String) -> Dictionary:
	for r in Settings.DESCRIPTORS:
		if r["key"] == key:
			return r
	return {}

func t_thickness_and_decay_defaults() -> void:
	var src := FileAccess.get_file_as_string(SRC)
	var set_src := FileAccess.get_file_as_string(SET_SRC)
	ck(not (src + set_src).contains("outline_style"), "MCM drops the outline_style dropdown")
	ck(_descr("outline_rim").is_empty(), "the Rim setting is gone")
	var thick := _descr("outline_thickness")
	ck(absf(float(thick.get("def", -1.0)) - 0.005) < 0.000001 and absf(float(thick.get("step", -1.0)) - 0.0005) < 0.000001
		and absf(float(thick.get("max", -1.0)) - 0.02) < 0.000001, "outline_thickness default/step/max match settings")
	var decay := _descr("corpse_decay")
	ck(absf(float(decay.get("def", -1.0)) - 70.0) < 0.001 and absf(float(decay.get("max", -1.0)) - 180.0) < 0.001,
		"corpse_decay default/max match settings")

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
	ck((src + set_src).contains('"NPC ESP"'), "the contour entry is called NPC ESP")
	ck(set_src.contains('"Mine ESP"'), "the mine entry is called Mine ESP")
	ck(set_src.contains('"Nomads marker"'), "the nomad entry is called Nomads marker")
	ck(set_src.contains('"Highlight softness"'), "the highlight entry is called Highlight softness")
	ck(set_src.contains('"Daylight strength"'), "the strength entry exists")
	ck((src + set_src).contains("Rim") == false, "the removed rim entry leaves no label behind")
	ck((src + set_src).contains("\"Thickness\""), "the thickness entry lost the Outline prefix")
	ck(set_src.contains("\"Brightness\""), "the brightness entry lost the Outline prefix")
	ck((src + set_src).contains("Cooling time"), "the cooling entry is called Cooling time")
	ck(set_src.contains("\"Default\""), "the idle state colour is called Default")
	ck(not (src + set_src).contains("04. Contour Range"), "the separate range block is gone")
	ck(_descr("outline_distance").get("sect") == "Float"
		and _descr("outline_distance").get("name") == "Distance"
		and _descr("outline_distance").get("cat").begins_with("02."), "the distance moved into the ESP block")
