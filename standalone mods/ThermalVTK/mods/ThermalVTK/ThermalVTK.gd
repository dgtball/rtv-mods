extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const VTKDebug = preload("res://mods/ThermalVTK/VTKDebug.gd")
const Probe = preload("res://mods/ThermalVTK/VTKProbe.gd")
const Calibration = preload("res://mods/ThermalVTK/VTKCalibration.gd")

const MOD_ID := "thermal-vtk"
const MOD_NAME := "ThermalVTK"
const CONFIG_DIR := "user://MCM/thermal-vtk"
const CONFIG_FILE := "user://MCM/thermal-vtk/config.ini"
const STATE_FILE := "user://MCM/thermal-vtk/thermal_state.cfg"
const MOD_CONFIG_FILE := "user://mod_config.cfg"
const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"
const PALETTE_COUNT := 4

var _nvg: Node = null
var _esp: Node = null
# The file the settings are read from: the profile the mod loader has active.
var _config_path: String = CONFIG_FILE
var _key_thermal_toggle: int = 0
var _key_palette_cycle: int = KEY_F6
var _key_debug_probe: int = KEY_F7
var _key_cal_cycle: int = KEY_F8
var _thermal_enabled: bool = false
var _mines_enabled: bool = true
var _outline_enabled: bool = true
var _xray_enabled: bool = true
var _nvg_worn: bool = false
var _cal_active: bool = false
var _cal_index: int = 0

func _ready() -> void:
	VTKDebug.log("LIFE", "autoload ready begin")
	_register_mcm()
	VTKDebug.log("LIFE", "autoload ready end")

func _ensure_nvg() -> void:
	if _nvg != null and is_instance_valid(_nvg):
		return
	var NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
	_nvg = NVG.new()
	add_child(_nvg)
	_ensure_esp()

func _ensure_esp() -> void:
	if _esp != null and is_instance_valid(_esp):
		return
	var ESP = preload("res://mods/ThermalVTK/VTKESP.gd")
	_esp = ESP.new()
	add_child(_esp)

# ---------- hotkey ----------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := event as InputEventKey
	if _key_palette_cycle != 0 and (k.keycode == _key_palette_cycle or k.physical_keycode == _key_palette_cycle):
		_cycle_palette()
		get_viewport().set_input_as_handled()
		return
	if _key_debug_probe != 0 and (k.keycode == _key_debug_probe or k.physical_keycode == _key_debug_probe):
		# The probe is a debug tool: without the debug log the key stays free
		# for the game, so nothing is consumed.
		if VTKDebug.enabled:
			_probe_center()
			get_viewport().set_input_as_handled()
		return
	if _key_cal_cycle != 0 and (k.keycode == _key_cal_cycle or k.physical_keycode == _key_cal_cycle):
		# The calibration cycle is a debug tool: without the debug log the key
		# stays free for the game, so nothing is consumed.
		if VTKDebug.enabled:
			_cal_step(k.shift_pressed)
			get_viewport().set_input_as_handled()
		return
	if _key_thermal_toggle == 0:
		return
	if k.keycode == _key_thermal_toggle or k.physical_keycode == _key_thermal_toggle:
		_toggle_thermal()
		get_viewport().set_input_as_handled()

func _toggle_thermal() -> void:
	_thermal_enabled = not _thermal_enabled
	if _nvg != null and is_instance_valid(_nvg):
		_nvg.set_thermal_enabled(_thermal_enabled)
	_apply_mode()
	_notify("Thermal vision: " + ("ON" if _thermal_enabled else "OFF"),
		Color.GREEN if _thermal_enabled else Color(0.7, 0.7, 0.7))
	_save_state("thermal_enabled", _thermal_enabled)

const PALETTE_NAMES: Array[String] = ["Classic", "Amber", "Forest", "Ice"]

func _cycle_palette() -> void:
	# The world palette only shows while thermal vision is on, so F6 is a
	# no-op otherwise: no palette change and no toast.
	if not _thermal_enabled:
		return
	if _nvg == null or not is_instance_valid(_nvg):
		return
	var mode: int = (int(_nvg.set_palette) + 1) % PALETTE_COUNT
	_nvg.set_palette_mode(mode)
	_notify("World palette: " + PALETTE_NAMES[mode], Color(0.6, 0.8, 1.0))
	_save_state("world_palette", mode)

# Debug key calibration: the hotkey cycles the candidate keys, so their
# colour under the night-vision helmet can be measured with the probe.
# The first press turns the calibration on at the first candidate, every
# further press advances it, and Shift turns it off again.
func _cal_step(off: bool) -> void:
	if off:
		_cal_active = false
		_cal_index = 0
		_push_calibration()
		VTKDebug.log("CAL", "off")
		return
	if _cal_active:
		_cal_index = (_cal_index + 1) % Calibration.count()
	else:
		_cal_active = true
		_cal_index = 0
	_push_calibration()
	VTKDebug.log("CAL", "candidate #%d %s" % [_cal_index, Calibration.label(_cal_index)])
	if _esp == null or not is_instance_valid(_esp) or not bool(_esp.contour_layer):
		VTKDebug.log("CAL", "the contour is off, nothing is painted")

func _push_calibration() -> void:
	if _esp == null or not is_instance_valid(_esp):
		return
	_esp.set_calibration(_cal_active, _cal_index)

# Debug key probe: read the colour under the crosshair into the debug log.
# The NVG overlay paints the thermal palette (or the green tint) over the whole
# frame, so the overlay rect is hidden for the sampled frame -- the raw scene
# pixel underneath is what the key detector compares against.
func _probe_center() -> void:
	if not VTKDebug.enabled:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var nvg = _nvg
	if nvg != null and is_instance_valid(nvg):
		nvg.set_overlay_visible(false)
	var rgb: Color = await Probe.read_center(vp)
	if nvg != null and is_instance_valid(nvg):
		nvg.set_overlay_visible(true)
	if rgb.a <= 0.0:
		VTKDebug.log("PROBE", "probe failed: no frame")
		return
	var hint := "raw-nvg-off"
	if _nvg_active():
		hint = "raw-thermal" if _thermal_enabled else "raw-nvg"
	VTKDebug.log("PROBE", Probe.format(rgb, hint))

func _apply_mode() -> void:
	if _esp != null and is_instance_valid(_esp):
		# Two independent layers on the thermal stack: the contour (rings and
		# the nomad marker) and the x-ray reveals. Either one can run alone.
		var on := _thermal_enabled and _nvg_active()
		_esp.set_layers(on and _outline_enabled, on and _xray_enabled)

func _nvg_active() -> bool:
	if _nvg == null or not is_instance_valid(_nvg):
		return false
	return _nvg.nvg_active()

# The contour lives in world space, so it does not follow vanilla NVG by itself.
# Watch the worn state and re-apply on change, or outlines would keep drawing
# with the helmet off and only appear on the next hotkey change.
func _process(_delta: float) -> void:
	var worn := _nvg_active()
	if worn == _nvg_worn:
		return
	_nvg_worn = worn
	_apply_mode()

# Toast channel exposed by the game's /root/Loader (loader.Message).
func _notify(text: String, color: Color) -> void:
	var loader = get_node_or_null(Paths.LOADER)
	if loader != null and loader.has_method("Message"):
		loader.Message(text, color)

# Persist hotkey/palette choices in our own state file. MCM keeps an in-memory copy
# and rewrites its config wholesale, so writing the toggle there gets clobbered.
# Read-modify-write so the two keys (thermal_enabled, world_palette) do not
# clobber each other.
func _save_state(key: String, v) -> void:
	var sf := ConfigFile.new()
	if FileAccess.file_exists(STATE_FILE):
		sf.load(STATE_FILE)
	sf.set_value("state", key, v)
	var err := sf.save(STATE_FILE)
	if err != OK:
		push_warning("ThermalVTK: failed to save state '%s' (%d)" % [key, err])

func _read_state(key: String, fallback):
	if not FileAccess.file_exists(STATE_FILE):
		return fallback
	var sf := ConfigFile.new()
	if sf.load(STATE_FILE) != OK:
		return fallback
	return sf.get_value("state", key, fallback)

# ---------- MCM ----------

func _register_mcm() -> void:
	_ensure_nvg()
	if not ResourceLoader.exists(MCM_HELPERS):
		_apply_defaults()
		return
	var MCM = load(MCM_HELPERS)
	if MCM == null or not MCM.has_method("RegisterConfiguration"):
		_apply_defaults()
		return
	var cfg := Settings.mcm_config()
	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "author", "CaptiveAI and opencode")
	DirAccess.make_dir_recursive_absolute(CONFIG_DIR)
	# The default file is the seed MCM copies a fresh profile from.
	_sync_config(cfg, CONFIG_FILE)
	MCM.RegisterConfiguration(MOD_ID, MOD_NAME, CONFIG_DIR, "NVG thermal overlay: contour ESP, mine highlighting and world thermal view", _mcm_apply, self)
	# MCM creates the profile file once and never refreshes it, so the menu
	# would keep showing entries we removed or renamed. Merge the registration
	# into the active profile too: the player's values stay, the labels and
	# defaults come from the code.
	_config_path = _active_config_path()
	_sync_config(cfg, _config_path)
	_mcm_apply(ConfigFile.new())
	VTKDebug.log("LIFE", "autoload mcm registered")

# Merge the freshly declared keys into an on-disk config by KEY: drop sections
# and keys that no longer exist in code, add new ones, but never overwrite a
# user's saved "value". The labels, ranges and defaults always come from the
# code, so a renamed or removed setting stops showing up in the menu.
# Info is always rewritten.
func _sync_config(cfg: ConfigFile, path: String) -> void:
	var existing := ConfigFile.new()
	if FileAccess.file_exists(path):
		existing.load(path)
		var stale_sections := []
		for s in existing.get_sections():
			if s != "Info" and not cfg.has_section(s):
				stale_sections.append(s)
		for s in stale_sections:
			existing.erase_section(s)
		for s in cfg.get_sections():
			var stale_keys: Array = []
			if existing.has_section(s):
				for k in existing.get_section_keys(s):
					if not cfg.has_section_key(s, k):
						stale_keys.append(k)
			for k in stale_keys:
				existing.erase_section_key(s, k)
		for s in cfg.get_sections():
			for k in cfg.get_section_keys(s):
				if s == "Info":
					existing.set_value(s, k, cfg.get_value(s, k, {}))
					continue
				if not existing.has_section_key(s, k):
					existing.set_value(s, k, cfg.get_value(s, k, {}))
					continue
				var old_v = existing.get_value(s, k, {})
				var new_v = cfg.get_value(s, k, {})
				if typeof(old_v) == TYPE_DICTIONARY and typeof(new_v) == TYPE_DICTIONARY:
					# Start from the saved entry so the player's own extras
					# survive (the modifier flags of a hotkey), then take every
					# property the code declares from the registration.
					var merged = old_v.duplicate()
					for prop in new_v.keys():
						if prop != "value":
							merged[prop] = new_v[prop]
					merged["value"] = old_v.get("value", new_v.get("value"))
					existing.set_value(s, k, merged)
		existing.save(path)
	if not FileAccess.file_exists(path):
		cfg.save(path)

# The mod loader can run several profiles and MCM keeps the settings of the
# active one in "<profile>.ini" next to the default "config.ini". The menu
# writes that file, so the mod has to read it as well, or the player's
# settings are lost on every restart.
func _active_profile_name() -> String:
	var mc := ConfigFile.new()
	if mc.load(MOD_CONFIG_FILE) != OK:
		return "config"
	var p := str(mc.get_value("settings", "active_profile", "config"))
	if p == "" or p == "Default":
		return "config"
	return p

func _config_path_for_profile(profile: String) -> String:
	return "user://MCM/%s/%s.ini" % [MOD_ID, profile]

func _active_config_path() -> String:
	return _config_path_for_profile(_active_profile_name())

func _mcm_apply(cfg: ConfigFile) -> void:
	VTKDebug.log("LIFE", "mcm apply begin")
	if cfg.get_sections().is_empty() and FileAccess.file_exists(_config_path):
		cfg.load(_config_path)
	# One typed snapshot from the descriptor table; the modules consume it
	# wholesale, so a renamed key is a parse error, not a silent stale value.
	var rec = Settings.read(cfg)
	VTKDebug.set_enabled(rec.debug_log)
	_ensure_nvg()
	if _nvg == null or not is_instance_valid(_nvg):
		return
	_key_thermal_toggle = rec.key_thermal_toggle
	_key_palette_cycle = rec.key_palette_cycle
	_key_debug_probe = rec.key_debug_probe
	_key_cal_cycle = rec.key_cal_cycle
	# The thermal toggle and the world palette live in our own state file, not
	# in the MCM config: the hotkey writes them, and a second source of truth
	# would fight the hotkey on every menu round-trip.
	_thermal_enabled = bool(_read_state("thermal_enabled", false))
	_mines_enabled = rec.thermal_mines
	# The world palette is a runtime choice: it lives in our state file and is
	# changed with the cycle hotkey, so there is no MCM dropdown for it.
	var pal = _read_state("world_palette", null)
	_nvg.apply_config(rec)
	_nvg.set_palette_mode(int(pal) if pal != null else 0)
	_nvg.set_thermal_enabled(_thermal_enabled)
	_ensure_esp()
	if _esp != null and is_instance_valid(_esp):
		_esp.apply_config(rec)
	_outline_enabled = rec.outline_enabled
	_xray_enabled = rec.outline_xray
	_apply_mode()


func _apply_defaults() -> void:
	# No MCM in this install: the runtime choices still come from our state
	# file, so the hotkeys keep working.
	_thermal_enabled = bool(_read_state("thermal_enabled", false))
	var pal = _read_state("world_palette", null)
	if _nvg != null and is_instance_valid(_nvg):
		_nvg.set_palette_mode(int(pal) if pal != null else 0)
		_nvg.set_thermal_enabled(_thermal_enabled)
		_nvg.set_mines_enabled(_mines_enabled)
	_apply_mode()

func _mod_version() -> String:
	var vf = FileAccess.open("res://mods/ThermalVTK/version.txt", FileAccess.READ)
	if vf == null:
		return "unknown"
	var v := vf.get_as_text().strip_edges()
	vf.close()
	return v if v != "" else "unknown"
