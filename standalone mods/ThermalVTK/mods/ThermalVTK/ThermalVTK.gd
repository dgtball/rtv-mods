extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const VTKDebug = preload("res://mods/ThermalVTK/VTKDebug.gd")
const Probe = preload("res://mods/ThermalVTK/VTKProbe.gd")

const MOD_ID := "thermal-vtk"
const MOD_NAME := "ThermalVTK"
const CONFIG_DIR := "user://MCM/thermal-vtk"
const CONFIG_FILE := "user://MCM/thermal-vtk/config.ini"
const STATE_FILE := "user://MCM/thermal-vtk/thermal_state.cfg"
const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"
const PALETTE_COUNT := 4
# Fill opacity the Front-faces preset applies (the design's flat fill).
const PRESET_FILL_ALPHA := 0.05

var _nvg: Node = null
var _esp: Node = null
var _key_thermal_toggle: int = 0
var _key_palette_cycle: int = KEY_F6
var _key_debug_probe: int = KEY_F7
var _thermal_enabled: bool = false
var _mines_enabled: bool = true
var _mcm_thermal_seen: int = -1
var _mcm_palette_seen: int = -1
var _outline_enabled: bool = true
var _nvg_worn: bool = false

func _ready() -> void:
	_register_mcm()

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
		# The nomad marker belongs to the contour: it follows the same gate as
		# the outlines, so switching the contour off hides it as well.
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
	var cfg = ConfigFile.new()
	var CAT := "01. ThermalVision"
	cfg.set_value("Keycode", "key_thermal_toggle", {"name": "Hotkey: Toggle thermal vision", "default": 0, "default_type": "Keycode", "value": 0, "category": CAT, "menu_pos": 0, "tooltip": "Press in game to turn the thermal layer on and off."})
	cfg.set_value("Keycode", "key_palette_cycle", {"name": "Hotkey: Cycle world palette", "default": KEY_F6, "default_type": "Keycode", "value": KEY_F6, "category": CAT, "menu_pos": 1, "tooltip": "Press in game to cycle the world thermal palette."})
	cfg.set_value("Keycode", "key_debug_probe", {"name": "Hotkey: Debug key probe", "default": KEY_F7, "default_type": "Keycode", "value": KEY_F7, "category": CAT, "menu_pos": 20, "tooltip": "Writes the colour under the crosshair to the debug log. Turn the debug log on first, then press it while aiming at a filled NPC or the nomad marker. The view blinks for one frame."})
	cfg.set_value("Float", "nvg_noise", {"name": "NVG noise", "default": 4.0, "value": 4.0, "minRange": 0.0, "maxRange": 60.0, "step": 0.5, "category": CAT, "menu_pos": 2, "tooltip": "Grain amount over the NVG image. Lower is cleaner. Vanilla is fixed at 10."})
	cfg.set_value("Float", "nvg_white", {"name": "NVG brightness", "default": 1.0, "value": 1.0, "minRange": 0.05, "maxRange": 1.0, "step": 0.05, "category": CAT, "menu_pos": 3, "tooltip": "Brightness of the NVG image. 1 = full brightness; lower darkens the whole overlay."})
	cfg.set_value("Bool", "thermal_enabled", {"name": "Thermal vision", "default": false, "value": false, "category": CAT, "menu_pos": 4, "tooltip": "Master switch for the thermal vision layer: the contour ESP and mine highlighting. Plain green NVG is unaffected while this is off."})
	cfg.set_value("Bool", "thermal_mines", {"name": "Mine highlighting", "default": true, "value": true, "category": CAT, "menu_pos": 5, "tooltip": "Highlight mines while thermal vision is on."})
	cfg.set_value("Dropdown", "thermal_palette", {"default": "classic", "value": "classic", "options": {"classic": "Classic", "amber": "Amber", "forest": "Forest", "ice": "Ice"}, "category": CAT, "menu_pos": 8, "tooltip": "World thermal palette.", "name": "World palette"})
	cfg.set_value("Float", "thermal_world", {"default": 1.70, "value": 1.70, "minRange": 1.0, "maxRange": 4.0, "step": 0.05, "category": CAT, "menu_pos": 9, "tooltip": "How bright the surrounding world reads in thermal.", "name": "World brightness"})

	var CAT2 := "02. Contour ESP"
	cfg.set_value("Bool", "outline_enabled", {"name": "Contour ESP", "default": true, "value": true, "category": CAT2, "menu_pos": 0, "tooltip": "Draw state-coloured body outlines over NPCs. Off = full-screen thermal only."})
	cfg.set_value("Dropdown", "outline_style", {"name": "Outline style", "default": "front", "value": "front", "options": {"front": "Front-faces (ITH)", "back": "Back-faces"}, "category": CAT2, "menu_pos": 1, "tooltip": "Outline look. Front-faces is the clean silhouette; Back-faces is the older inflated look."})
	cfg.set_value("Float", "outline_rim", {"name": "Outline rim", "default": 0.42, "value": 0.42, "minRange": 0.0, "maxRange": 1.0, "step": 0.02, "category": CAT2, "menu_pos": 2, "tooltip": "Edge band width (Front-faces) or edge sharpness (Back-faces) of the outline."})
	cfg.set_value("Bool", "outline_body_fill", {"name": "Body fill", "default": true, "value": true, "category": CAT2, "menu_pos": 3, "tooltip": "Fill the NPC body with its state colour inside the outline."})
	cfg.set_value("Float", "fill_opacity", {"name": "Fill opacity", "default": 0.05, "value": 0.05, "minRange": 0.0, "maxRange": 1.0, "step": 0.05, "category": CAT2, "menu_pos": 5, "tooltip": "How solid the body fill is. 0 = outline only."})
	cfg.set_value("Float", "corpse_decay", {"name": "Corpse cooling time", "default": 8.0, "value": 8.0, "minRange": 0.0, "maxRange": 30.0, "step": 1.0, "category": CAT2, "menu_pos": 6, "tooltip": "Seconds a dead NPC's outline takes to cool from warm to cold."})
	cfg.set_value("Float", "outline_thickness", {"name": "Outline thickness", "default": 0.006, "value": 0.006, "minRange": 0.001, "maxRange": 0.02, "step": 0.001, "category": CAT2, "menu_pos": 7, "tooltip": "How far the outline band grows beyond the body."})
	cfg.set_value("Float", "outline_brightness", {"name": "Outline brightness", "default": 0.6, "value": 0.6, "minRange": 0.1, "maxRange": 3.0, "step": 0.1, "category": CAT2, "menu_pos": 8, "tooltip": "Brightness multiplier on the outline colour."})

	var CAT3 := "03. Outline Colours"
	cfg.set_value("Color", "state_normal", {"name": "Normal / idle", "default": Color(1.0, 0.72, 0.28), "value": Color(1.0, 0.72, 0.28), "allowAlpha": false, "category": CAT3, "menu_pos": 0, "tooltip": "Colour for NPCs that are idle, patrolling, looting or guarding."})
	cfg.set_value("Color", "state_combat", {"name": "In combat", "default": Color(0.95, 0.18, 0.15), "value": Color(0.95, 0.18, 0.15), "allowAlpha": false, "category": CAT3, "menu_pos": 1, "tooltip": "Colour for NPCs in combat, hunting, attacking or throwing grenades."})
	cfg.set_value("Color", "state_defend", {"name": "Defending", "default": Color(0.62, 0.30, 0.95), "value": Color(0.62, 0.30, 0.95), "allowAlpha": false, "category": CAT3, "menu_pos": 2, "tooltip": "Colour for NPCs taking cover, defending, ambushing or lurking."})

	var CAT4 := "04. Contour Range"
	cfg.set_value("Float", "outline_distance", {"name": "Outline distance", "default": 60.0, "value": 60.0, "minRange": 0.0, "maxRange": 300.0, "step": 10.0, "category": CAT4, "menu_pos": 0, "tooltip": "Maximum distance for an outline. Past half of this the outline fades out."})

	var CAT5 := "05. Diagnostics"
	cfg.set_value("Bool", "debug_log", {"name": "Debug log", "default": false, "value": false, "category": CAT5, "menu_pos": 0, "tooltip": "Write a diagnostic log of the contour ESP to user://MCM/thermal-vtk/debug.log. For troubleshooting; leave off for normal play."})

	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "author", "CaptiveAI and opencode")
	DirAccess.make_dir_recursive_absolute(CONFIG_DIR)
	_sync_config(cfg)
	MCM.RegisterConfiguration(MOD_ID, MOD_NAME, CONFIG_DIR, "NVG thermal overlay: contour ESP, mine highlighting and world thermal view", _mcm_apply, self)
	_mcm_apply(ConfigFile.new())

# Merge the freshly declared keys into the on-disk config by KEY: drop sections
# and keys that no longer exist in code, add new ones, but never overwrite a
# user's saved "value". Info is always rewritten.
func _sync_config(cfg: ConfigFile) -> void:
	var existing := ConfigFile.new()
	if FileAccess.file_exists(CONFIG_FILE):
		existing.load(CONFIG_FILE)
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
					var merged = new_v.duplicate()
					merged["value"] = old_v.get("value", new_v.get("value"))
					existing.set_value(s, k, merged)
		existing.save(CONFIG_FILE)
	if not FileAccess.file_exists(CONFIG_FILE):
		cfg.save(CONFIG_FILE)

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

const PALETTE_MODES := {"classic": 0, "amber": 1, "forest": 2, "ice": 3}
# Old Int configs (0..5) map onto the 4 remaining palettes; 1/2 (white/black
# hot) were dropped and fall back to Classic.
const LEGACY_PALETTE := {0: 0, 3: 1, 4: 2, 5: 3}

func _palette_mode_from_cfg(cfg: ConfigFile) -> int:
	var raw = _mcm_key_val(cfg, "Dropdown", "thermal_palette", "classic")
	if raw is String:
		return int(PALETTE_MODES.get(raw, 0))
	if raw is int or raw is float:
		return int(LEGACY_PALETTE.get(int(raw), 0))
	return 0

func _mcm_apply(cfg: ConfigFile) -> void:
	if cfg.get_sections().is_empty() and FileAccess.file_exists(CONFIG_FILE):
		cfg.load(CONFIG_FILE)
	VTKDebug.set_enabled(bool(_mcm_key_val(cfg, "Bool", "debug_log", false)))
	_ensure_nvg()
	if _nvg == null or not is_instance_valid(_nvg):
		return
	_key_thermal_toggle = int(_mcm_key_val(cfg, "Keycode", "key_thermal_toggle", 0))
	_key_palette_cycle = int(_mcm_key_val(cfg, "Keycode", "key_palette_cycle", KEY_F6))
	_key_debug_probe = int(_mcm_key_val(cfg, "Keycode", "key_debug_probe", KEY_F7))
	var mcm_thermal := bool(_mcm_key_val(cfg, "Bool", "thermal_enabled", false))
	var mcm_i: int = 1 if mcm_thermal else 0
	var saved = _read_state("thermal_enabled", null)
	if _mcm_thermal_seen < 0:
		_thermal_enabled = saved if saved != null else mcm_thermal
	elif saved != null and mcm_i == _mcm_thermal_seen:
		_thermal_enabled = saved
	else:
		_thermal_enabled = mcm_thermal
		_save_state("thermal_enabled", _thermal_enabled)
	_mcm_thermal_seen = mcm_i
	_mines_enabled = bool(_mcm_key_val(cfg, "Bool", "thermal_mines", true))
	_nvg.set_nvg_noise = float(_mcm_key_val(cfg, "Float", "nvg_noise", 4.0))
	_nvg.set_nvg_white = float(_mcm_key_val(cfg, "Float", "nvg_white", 1.0))
	# Palette: last explicit choice wins. An actual dropdown change beats the
	# saved state and is written back; a plain reload keeps the saved state (F6
	# or a previous menu choice) ahead of the MCM value.
	var mcm_palette: int = _palette_mode_from_cfg(cfg)
	var pal = _read_state("world_palette", null)
	var saved_i: int = int(pal) if pal != null else -1
	if _mcm_palette_seen >= 0 and mcm_palette != _mcm_palette_seen:
		_nvg.set_palette_mode(mcm_palette)
		_save_state("world_palette", mcm_palette)
	else:
		_nvg.set_palette_mode(saved_i if saved_i >= 0 else mcm_palette)
	_mcm_palette_seen = mcm_palette
	_nvg.set_world = float(_mcm_key_val(cfg, "Float", "thermal_world", 1.70))
	_nvg.set_thermal_enabled(_thermal_enabled)
	_nvg.set_mines_enabled(_mines_enabled)
	_ensure_esp()
	if _esp != null and is_instance_valid(_esp):
		_esp.p_decay = float(_mcm_key_val(cfg, "Float", "corpse_decay", 8.0))
		_esp.p_dist = float(_mcm_key_val(cfg, "Float", "outline_distance", 60.0))
		_esp.p_thickness = float(_mcm_key_val(cfg, "Float", "outline_thickness", 0.006))
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
		_esp.p_fill = bool(_mcm_key_val(cfg, "Bool", "outline_body_fill", true))
		_esp.p_fill_alpha = float(_mcm_key_val(cfg, "Float", "fill_opacity", 0.05))
		_esp.p_style = 0 if String(_mcm_key_val(cfg, "Dropdown", "outline_style", "front")) == "front" else 1
		_esp.p_rim = float(_mcm_key_val(cfg, "Float", "outline_rim", 0.42))
		# Preset: the outline style decides the fill default. Only when the style
		# actually changes do we touch fill/opacity, so a user's manual sliders
		# survive editor round-trips.
		_apply_style_preset(_esp.p_style, cfg)
		_nvg.set_outline_brightness = _esp.p_brightness
		_nvg.set_fill_opacity = _esp.p_fill_alpha if _esp.p_fill else 0.0
		_esp.p_colors = {
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"state_defend": _mcm_color_val(cfg, "state_defend", States.DEFAULT_DEFEND),
		}
		_nvg.set_state_colors({
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"state_defend": _mcm_color_val(cfg, "state_defend", States.DEFAULT_DEFEND),
		})
		# Mines share the ESP outline distance so both ranges track one setting.
		_nvg.set_glow_distance = _esp.p_dist
	_outline_enabled = bool(_mcm_key_val(cfg, "Bool", "outline_enabled", true))
	_apply_mode()

# The outline style is a fill preset: Front-faces fills the body at 0.05,
# Back-faces turns the fill off. The preset is written back into the MCM
# config, so the panel shows the values the shader uses instead of a stale
# slider. The guard (the persisted outline_style_seen state) keeps a manual
# fill opacity from being reset on every MCM round-trip.
func _apply_style_preset(style: int, cfg: ConfigFile, config_path: String = CONFIG_FILE, state_path: String = STATE_FILE) -> bool:
	var seen_style = _read_state("outline_style_seen", null, state_path)
	if seen_style == style:
		return false
	var fill: bool = (style == 0)
	var alpha: float = PRESET_FILL_ALPHA if fill else 0.0
	if _esp != null and is_instance_valid(_esp):
		_esp.p_fill = fill
		_esp.p_fill_alpha = alpha
	_cfg_set_value(cfg, "Bool", "outline_body_fill", fill)
	_cfg_set_value(cfg, "Float", "fill_opacity", alpha)
	_write_config_values(config_path, fill, alpha)
	_save_state("outline_style_seen", style, state_path)
	return true

# Writes the "value" member of an MCM entry and leaves the rest of the entry
# (name, range, tooltip) alone.
func _cfg_set_value(cfg: ConfigFile, section: String, key: String, value) -> void:
	if cfg == null or not cfg.has_section_key(section, key):
		return
	var d = cfg.get_value(section, key, {})
	if typeof(d) != TYPE_DICTIONARY:
		cfg.set_value(section, key, value)
		return
	var merged = d.duplicate()
	merged["value"] = value
	cfg.set_value(section, key, merged)

# The MCM panel reads its sliders from the config file and offers no way to
# push a value into it, so the preset is written there directly.
func _write_config_values(path: String, fill: bool, alpha: float) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return false
	_cfg_set_value(cf, "Bool", "outline_body_fill", fill)
	_cfg_set_value(cf, "Float", "fill_opacity", alpha)
	return cf.save(path) == OK

func _apply_defaults() -> void:
	var saved = _read_state("thermal_enabled", null)
	if saved != null:
		_thermal_enabled = saved
	if _nvg != null and is_instance_valid(_nvg):
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
