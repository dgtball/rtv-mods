extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
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
	if _esp == null or not is_instance_valid(_esp) or not bool(_esp.enabled):
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
		# The whole contour stack (ESP rings, x-ray trigger reveals, nomad
		# marker) lives on the thermal layer: with the helmet off nothing runs.
		var on := _thermal_enabled and _outline_enabled and _nvg_active()
		_esp.set_enabled(on)
		_esp.marker_visible = on

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
func _save_state(key: String, v, path: String = STATE_FILE) -> void:
	var sf := ConfigFile.new()
	if FileAccess.file_exists(path):
		sf.load(path)
	sf.set_value("state", key, v)
	var err := sf.save(path)
	if err != OK:
		push_warning("ThermalVTK: failed to save state '%s' (%d)" % [key, err])

func _read_state(key: String, fallback, path: String = STATE_FILE):
	if not FileAccess.file_exists(path):
		return fallback
	var sf := ConfigFile.new()
	if sf.load(path) != OK:
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
	var cfg := _mcm_config()
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

# The settings the mod declares. MCM shows them and the mod merges them into
# the config file, so the labels, the ranges and the defaults live here only.
func _mcm_config() -> ConfigFile:
	var cfg = ConfigFile.new()
	var CAT := "01. ThermalVision"
	cfg.set_value("Keycode", "key_thermal_toggle", {"name": "Thermal vision", "default": 0, "default_type": "Keycode", "type": "Key", "value": 0, "category": CAT, "menu_pos": 0, "tooltip": "Hotkey: press in game to turn the thermal layer on and off."})
	cfg.set_value("Keycode", "key_palette_cycle", {"name": "World palette", "default": KEY_F6, "default_type": "Keycode", "type": "Key", "value": KEY_F6, "category": CAT, "menu_pos": 1, "tooltip": "Hotkey: cycle the world thermal palette."})
	cfg.set_value("Bool", "outline_enabled", {"name": "NPC highlighting (ESP)", "default": true, "value": true, "category": CAT, "menu_pos": 2, "tooltip": "Draw state-coloured body outlines over NPCs while thermal vision is on. Off = full-screen thermal only."})
	cfg.set_value("Bool", "outline_xray", {"name": "X-ray Triggers", "default": true, "value": true, "category": CAT, "menu_pos": 3, "tooltip": "On top of the ESP, event reveals knock out through walls: gunfire, shouts, idle chatter, footsteps, reloads, pain cries and grenade throws ring the NPC for a few seconds at their own reveal range (sliders in the X-ray Triggers tab)."})
	cfg.set_value("Bool", "thermal_mines", {"name": "Mine highlighting", "default": true, "value": true, "category": CAT, "menu_pos": 4, "tooltip": "Highlight mines while thermal vision is on."})
	cfg.set_value("Float", "nvg_noise", {"name": "NVG noise", "default": 0.0, "value": 0.0, "minRange": 0.0, "maxRange": 60.0, "step": 0.5, "category": CAT, "menu_pos": 5, "tooltip": "Grain amount over the NVG image. Lower is cleaner. Vanilla is fixed at 10."})
	cfg.set_value("Float", "nvg_white", {"name": "NVG brightness", "default": 1.0, "value": 1.0, "minRange": 0.05, "maxRange": 1.0, "step": 0.05, "category": CAT, "menu_pos": 6, "tooltip": "Brightness of the NVG image. 1 = full brightness; lower darkens the whole overlay."})
	cfg.set_value("Float", "thermal_world", {"default": 1.70, "value": 1.70, "minRange": 1.0, "maxRange": 4.0, "step": 0.05, "category": CAT, "menu_pos": 7, "tooltip": "How bright the surrounding world reads in thermal.", "name": "World brightness"})

	var CAT2 := "02. NPC"
	cfg.set_value("Float", "outline_distance", {"name": "Distance", "default": 60.0, "value": 60.0, "minRange": 0.0, "maxRange": 300.0, "step": 10.0, "category": CAT2, "menu_pos": 0, "tooltip": "Maximum distance for an outline. Past half of this the outline fades out."})
	cfg.set_value("Float", "outline_rim", {"name": "Rim", "default": 2.0, "value": 2.0, "minRange": 0.0, "maxRange": 6.0, "step": 0.5, "category": CAT2, "menu_pos": 1, "tooltip": "Edge sharpness of the outline. 1.0 is a linear falloff; higher values tighten the band toward the silhouette."})
	cfg.set_value("Float", "outline_thickness", {"name": "Thickness", "default": 0.006, "value": 0.006, "minRange": 0.001, "maxRange": 0.02, "step": 0.001, "category": CAT2, "menu_pos": 2, "tooltip": "How far the outline band grows beyond the body."})
	cfg.set_value("Float", "outline_brightness", {"name": "Brightness", "default": 0.6, "value": 0.6, "minRange": 0.1, "maxRange": 3.0, "step": 0.1, "category": CAT2, "menu_pos": 3, "tooltip": "Brightness multiplier on the outline colour."})
	cfg.set_value("Float", "corpse_decay", {"name": "Cooling time", "default": 30.0, "value": 30.0, "minRange": 0.0, "maxRange": 180.0, "step": 1.0, "category": CAT2, "menu_pos": 4, "tooltip": "Seconds a dead NPC's outline takes to cool from warm to cold."})

	var CAT4 := "03. X-ray Triggers"
	cfg.set_value("Float", "trigger_fire_dist", {"name": "Gunfire distance", "default": 100.0, "value": 100.0, "minRange": 1.0, "maxRange": 300.0, "step": 5.0, "category": CAT4, "menu_pos": 0, "tooltip": "Reveal range for a gun-shot."})
	cfg.set_value("Float", "trigger_voice_dist", {"name": "Shout distance", "default": 20.0, "value": 20.0, "minRange": 1.0, "maxRange": 60.0, "step": 1.0, "category": CAT4, "menu_pos": 1, "tooltip": "Reveal range for a combat shout."})
	cfg.set_value("Float", "trigger_idle_dist", {"name": "Idle voice distance", "default": 6.0, "value": 6.0, "minRange": 1.0, "maxRange": 30.0, "step": 1.0, "category": CAT4, "menu_pos": 2, "tooltip": "Reveal range for idle chatter (whistling, muttering)."})
	cfg.set_value("Float", "trigger_move_dist", {"name": "Walk distance", "default": 10.0, "value": 10.0, "minRange": 1.0, "maxRange": 40.0, "step": 1.0, "category": CAT4, "menu_pos": 3, "tooltip": "Reveal range for footsteps from a walking bot."})
	cfg.set_value("Float", "trigger_run_dist", {"name": "Sprint distance", "default": 20.0, "value": 20.0, "minRange": 1.0, "maxRange": 60.0, "step": 1.0, "category": CAT4, "menu_pos": 4, "tooltip": "Reveal range for a sprinting bot's footsteps."})
	cfg.set_value("Float", "trigger_reload_dist", {"name": "Reload distance", "default": 12.0, "value": 12.0, "minRange": 1.0, "maxRange": 40.0, "step": 1.0, "category": CAT4, "menu_pos": 5, "tooltip": "Reveal range for a reload."})
	cfg.set_value("Float", "trigger_pain_dist", {"name": "Pain cry distance", "default": 15.0, "value": 15.0, "minRange": 1.0, "maxRange": 40.0, "step": 1.0, "category": CAT4, "menu_pos": 6, "tooltip": "Reveal range for a pain cry."})
	cfg.set_value("Float", "trigger_nade_dist", {"name": "Grenade distance", "default": 60.0, "value": 60.0, "minRange": 1.0, "maxRange": 120.0, "step": 5.0, "category": CAT4, "menu_pos": 7, "tooltip": "Reveal range for a thrown grenade."})
	cfg.set_value("Float", "trigger_fire_time", {"name": "Gunfire seconds", "default": 5.0, "value": 5.0, "minRange": 1.0, "maxRange": 15.0, "step": 0.5, "category": CAT4, "menu_pos": 8, "tooltip": "How long the gun-shot reveal stays up."})
	cfg.set_value("Float", "trigger_voice_time", {"name": "Shout seconds", "default": 5.0, "value": 5.0, "minRange": 1.0, "maxRange": 15.0, "step": 0.5, "category": CAT4, "menu_pos": 9, "tooltip": "How long the combat-shout reveal stays up."})
	cfg.set_value("Float", "trigger_idle_time", {"name": "Idle voice seconds", "default": 2.0, "value": 2.0, "minRange": 1.0, "maxRange": 10.0, "step": 0.5, "category": CAT4, "menu_pos": 10, "tooltip": "How long the idle-chatter reveal stays up."})
	cfg.set_value("Float", "trigger_move_time", {"name": "Footsteps seconds", "default": 1.5, "value": 1.5, "minRange": 1.0, "maxRange": 10.0, "step": 0.5, "category": CAT4, "menu_pos": 11, "tooltip": "How long the footstep reveal stays up."})
	cfg.set_value("Float", "trigger_reload_time", {"name": "Reload seconds", "default": 2.0, "value": 2.0, "minRange": 1.0, "maxRange": 10.0, "step": 0.5, "category": CAT4, "menu_pos": 12, "tooltip": "How long the reload-sound reveal stays up."})
	cfg.set_value("Float", "trigger_pain_time", {"name": "Pain cry seconds", "default": 3.0, "value": 3.0, "minRange": 1.0, "maxRange": 10.0, "step": 0.5, "category": CAT4, "menu_pos": 13, "tooltip": "How long the pain-cry reveal stays up after the bot takes damage."})
	cfg.set_value("Float", "trigger_nade_time", {"name": "Grenade seconds", "default": 6.0, "value": 6.0, "minRange": 1.0, "maxRange": 15.0, "step": 0.5, "category": CAT4, "menu_pos": 14, "tooltip": "How long the grenade-throw reveal stays up."})

	var CAT3 := CAT2
	cfg.set_value("Color", "state_normal", {"name": "Default", "default": Color(1.0, 0.72, 0.28), "value": Color(1.0, 0.72, 0.28), "allowAlpha": false, "category": CAT3, "menu_pos": 5, "tooltip": "Colour for NPCs that are idle, patrolling, looting or guarding."})
	cfg.set_value("Color", "state_combat", {"name": "In combat", "default": Color(0.95, 0.18, 0.15), "value": Color(0.95, 0.18, 0.15), "allowAlpha": false, "category": CAT3, "menu_pos": 6, "tooltip": "Colour for NPCs in combat, hunting, attacking or throwing grenades."})
	cfg.set_value("Color", "state_defend", {"name": "Defending", "default": Color(0.62, 0.30, 0.95), "value": Color(0.62, 0.30, 0.95), "allowAlpha": false, "category": CAT3, "menu_pos": 7, "tooltip": "Colour for NPCs taking cover, defending, ambushing or lurking."})

	var CAT5 := "04. Diagnostics"
	cfg.set_value("Bool", "debug_log", {"name": "Debug log", "default": false, "value": false, "category": CAT5, "menu_pos": 0, "tooltip": "Write a diagnostic log of the contour ESP to user://MCM/thermal-vtk/debug.log. For troubleshooting; leave off for normal play."})
	cfg.set_value("Keycode", "key_debug_probe", {"name": "Hotkey: Debug key probe", "default": KEY_F7, "default_type": "Keycode", "type": "Key", "value": KEY_F7, "category": CAT5, "menu_pos": 20, "tooltip": "Writes the colour under the crosshair to the debug log. Turn the debug log on first, then press it while aiming at an outlined NPC or the nomad marker. The view blinks for one frame."})
	cfg.set_value("Keycode", "key_cal_cycle", {"name": "Hotkey: Calibration cycle", "default": KEY_F8, "default_type": "Keycode", "type": "Key", "value": KEY_F8, "category": CAT5, "menu_pos": 21, "tooltip": "Debug tool: cycles a test colour for the outline and the nomad marker, so its colour under the night-vision helmet can be measured with the debug probe. Turn the debug log on first, then aim at an outlined NPC and press the probe key. Shift turns the calibration off."})

	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "author", "CaptiveAI and opencode")
	return cfg

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

func _mcm_key_val(cfg: ConfigFile, section: String, key: String, fallback):
	if not cfg.has_section_key(section, key):
		return fallback
	var d = cfg.get_value(section, key, {})
	if typeof(d) == TYPE_DICTIONARY and d.has("value"):
		return d["value"]
	return d if typeof(d) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else fallback

func _mcm_color_val(cfg: ConfigFile, key: String, fallback: Color) -> Color:
	if not cfg.has_section_key("Color", key):
		return fallback
	var d = cfg.get_value("Color", key, {})
	var v = d.get("value") if typeof(d) == TYPE_DICTIONARY else d
	return v if v is Color else fallback

func _mcm_apply(cfg: ConfigFile) -> void:
	VTKDebug.log("LIFE", "mcm apply begin")
	if cfg.get_sections().is_empty() and FileAccess.file_exists(_config_path):
		cfg.load(_config_path)
	VTKDebug.set_enabled(bool(_mcm_key_val(cfg, "Bool", "debug_log", false)))
	_ensure_nvg()
	if _nvg == null or not is_instance_valid(_nvg):
		return
	_key_thermal_toggle = int(_mcm_key_val(cfg, "Keycode", "key_thermal_toggle", 0))
	_key_palette_cycle = int(_mcm_key_val(cfg, "Keycode", "key_palette_cycle", KEY_F6))
	_key_debug_probe = int(_mcm_key_val(cfg, "Keycode", "key_debug_probe", KEY_F7))
	_key_cal_cycle = int(_mcm_key_val(cfg, "Keycode", "key_cal_cycle", KEY_F8))
	# The thermal toggle and the world palette live in our own state file, not
	# in the MCM config: the hotkey writes them, and a second source of truth
	# would fight the hotkey on every menu round-trip.
	_thermal_enabled = bool(_read_state("thermal_enabled", false))
	_mines_enabled = bool(_mcm_key_val(cfg, "Bool", "thermal_mines", true))
	_nvg.set_nvg_noise = float(_mcm_key_val(cfg, "Float", "nvg_noise", 4.0))
	_nvg.set_nvg_white = float(_mcm_key_val(cfg, "Float", "nvg_white", 1.0))
	# The world palette is a runtime choice: it lives in our state file and is
	# changed with the cycle hotkey, so there is no MCM dropdown for it.
	var pal = _read_state("world_palette", null)
	_nvg.set_palette_mode(int(pal) if pal != null else 0)
	_nvg.set_world = float(_mcm_key_val(cfg, "Float", "thermal_world", 1.70))
	_nvg.set_thermal_enabled(_thermal_enabled)
	_nvg.set_mines_enabled(_mines_enabled)
	_ensure_esp()
	if _esp != null and is_instance_valid(_esp):
		_esp.p_decay = float(_mcm_key_val(cfg, "Float", "corpse_decay", 30.0))
		_esp.p_dist = float(_mcm_key_val(cfg, "Float", "outline_distance", 60.0))
		_esp.p_thickness = float(_mcm_key_val(cfg, "Float", "outline_thickness", 0.006))
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
		_esp.p_rim = float(_mcm_key_val(cfg, "Float", "outline_rim", 2.0))
		# outline_xray is the "X-ray Triggers" toggle: on = the ring ignores the
		# depth buffer plus the event reveals knock through walls; off = the
		# occluded ring keeps walls and the scope mask in play.
		_esp.set_xray(bool(_mcm_key_val(cfg, "Bool", "outline_xray", true)))
		_esp.p_trig = bool(_mcm_key_val(cfg, "Bool", "outline_xray", true))
		_esp.p_fire_s = float(_mcm_key_val(cfg, "Float", "trigger_fire_time", 5.0))
		_esp.p_fire_d = float(_mcm_key_val(cfg, "Float", "trigger_fire_dist", 100.0))
		_esp.p_voice_s = float(_mcm_key_val(cfg, "Float", "trigger_voice_time", 5.0))
		_esp.p_voice_d = float(_mcm_key_val(cfg, "Float", "trigger_voice_dist", 20.0))
		_esp.p_idle_s = float(_mcm_key_val(cfg, "Float", "trigger_idle_time", 2.0))
		_esp.p_idle_d = float(_mcm_key_val(cfg, "Float", "trigger_idle_dist", 6.0))
		_esp.p_move_s = float(_mcm_key_val(cfg, "Float", "trigger_move_time", 1.5))
		_esp.p_move_d = float(_mcm_key_val(cfg, "Float", "trigger_move_dist", 10.0))
		_esp.p_run_d = float(_mcm_key_val(cfg, "Float", "trigger_run_dist", 20.0))
		_esp.p_reload_s = float(_mcm_key_val(cfg, "Float", "trigger_reload_time", 2.0))
		_esp.p_reload_d = float(_mcm_key_val(cfg, "Float", "trigger_reload_dist", 12.0))
		_esp.p_pain_s = float(_mcm_key_val(cfg, "Float", "trigger_pain_time", 3.0))
		_esp.p_pain_d = float(_mcm_key_val(cfg, "Float", "trigger_pain_dist", 15.0))
		_esp.p_nade_s = float(_mcm_key_val(cfg, "Float", "trigger_nade_time", 6.0))
		_esp.p_nade_d = float(_mcm_key_val(cfg, "Float", "trigger_nade_dist", 60.0))
		_nvg.set_state_brightness = _esp.p_brightness
		_nvg.set_state_colors({
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"state_defend": _mcm_color_val(cfg, "state_defend", States.DEFAULT_DEFEND),
		})
		# Mines share the ESP outline distance so both ranges track one setting.
		_nvg.set_glow_distance = _esp.p_dist
	_outline_enabled = bool(_mcm_key_val(cfg, "Bool", "outline_enabled", true))
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
