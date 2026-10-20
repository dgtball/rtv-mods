extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const VTKDebug = preload("res://mods/ThermalVTK/VTKDebug.gd")

const MOD_ID := "thermal-vtk"
const MOD_NAME := "ThermalVTK"
const CONFIG_DIR := "user://MCM/thermal-vtk"
const CONFIG_FILE := "user://MCM/thermal-vtk/config.ini"
const STATE_FILE := "user://MCM/thermal-vtk/thermal_state.cfg"
const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"
const PALETTE_COUNT := 4

var _nvg: Node = null
var _esp: Node = null
var _key_thermal_toggle: int = 0
var _key_palette_cycle: int = KEY_F6
var _thermal_enabled: bool = false
var _mines_enabled: bool = true
var _mcm_thermal_seen: int = -1
var _saved_palette: int = -1
var _outline_enabled: bool = true
var _nvg_worn: bool = false

func _ready() -> void:
	var saved_pal = _read_state("world_palette", null)
	_saved_palette = int(saved_pal) if saved_pal != null else -1
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
	if _nvg == null or not is_instance_valid(_nvg):
		return
	var mode: int = (int(_nvg.set_palette) + 1) % PALETTE_COUNT
	_nvg.set_palette_mode(mode)
	_notify("World palette: " + PALETTE_NAMES[mode], Color(0.6, 0.8, 1.0))
	_save_state("world_palette", mode)

func _apply_mode() -> void:
	if _esp != null and is_instance_valid(_esp):
		_esp.set_enabled(_thermal_enabled and _outline_enabled and _nvg_active())

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
	var cfg = ConfigFile.new()
	var CAT := "01. ThermalVision"
	cfg.set_value("Keycode", "key_thermal_toggle", {"name": "Hotkey: Toggle thermal vision", "default": 0, "default_type": "Keycode", "value": 0, "category": CAT, "menu_pos": 0, "tooltip": "Press in game to turn the thermal layer on and off."})
	cfg.set_value("Keycode", "key_palette_cycle", {"name": "Hotkey: Cycle world palette", "default": KEY_F6, "default_type": "Keycode", "value": KEY_F6, "category": CAT, "menu_pos": 1, "tooltip": "Press in game to cycle the world thermal palette."})
	cfg.set_value("Float", "nvg_noise", {"name": "NVG noise", "default": 4.0, "value": 4.0, "minRange": 0.0, "maxRange": 60.0, "step": 0.5, "category": CAT, "menu_pos": 2, "tooltip": "Grain amount over the NVG image. Lower is cleaner. Vanilla is fixed at 10."})
	cfg.set_value("Float", "nvg_white", {"name": "NVG brightness", "default": 1.0, "value": 1.0, "minRange": 0.05, "maxRange": 1.0, "step": 0.05, "category": CAT, "menu_pos": 3, "tooltip": "Brightness of the NVG image. 1 = full brightness; lower darkens the whole overlay."})
	cfg.set_value("Bool", "thermal_enabled", {"name": "Thermal vision", "default": false, "value": false, "category": CAT, "menu_pos": 4, "tooltip": "Master switch for the thermal vision layer: bot heat glow and mines. Plain green NVG is unaffected while this is off."})
	cfg.set_value("Bool", "thermal_mines", {"name": "Mine highlighting", "default": true, "value": true, "category": CAT, "menu_pos": 5, "tooltip": "Highlight mines while thermal vision is on."})
	cfg.set_value("Dropdown", "thermal_palette", {"default": "classic", "value": "classic", "options": {"classic": "Classic", "amber": "Amber", "forest": "Forest", "ice": "Ice"}, "category": CAT, "menu_pos": 8, "tooltip": "World thermal palette.", "name": "World palette"})
	cfg.set_value("Float", "thermal_world", {"default": 1.70, "value": 1.70, "minRange": 1.0, "maxRange": 4.0, "step": 0.05, "category": CAT, "menu_pos": 9, "tooltip": "How bright the surrounding world reads in thermal.", "name": "World brightness"})

	var CAT2 := "02. Contour ESP"
	cfg.set_value("Bool", "outline_enabled", {"name": "Contour ESP", "default": true, "value": true, "category": CAT2, "menu_pos": 0, "tooltip": "Draw state-coloured body outlines over NPCs. Off = full-screen thermal only."})
	cfg.set_value("Bool", "outline_body_fill", {"name": "Body fill", "default": true, "value": true, "category": CAT2, "menu_pos": 1, "tooltip": "Fill the NPC body with its state colour inside the outline."})
	cfg.set_value("Float", "fill_opacity", {"name": "Fill opacity", "default": 0.4, "value": 0.4, "minRange": 0.0, "maxRange": 1.0, "step": 0.05, "category": CAT2, "menu_pos": 2, "tooltip": "How solid the body fill is. 0 = outline only."})
	cfg.set_value("Float", "corpse_decay", {"name": "Corpse cooling time", "default": 8.0, "value": 8.0, "minRange": 0.0, "maxRange": 30.0, "step": 1.0, "category": CAT2, "menu_pos": 3, "tooltip": "Seconds a dead NPC's outline takes to cool from warm to cold."})
	cfg.set_value("Float", "outline_thickness", {"name": "Outline thickness", "default": 0.006, "value": 0.006, "minRange": 0.0, "maxRange": 0.05, "step": 0.001, "category": CAT2, "menu_pos": 4, "tooltip": "How far the outline band grows beyond the body."})
	cfg.set_value("Float", "outline_brightness", {"name": "Outline brightness", "default": 0.6, "value": 0.6, "minRange": 0.1, "maxRange": 3.0, "step": 0.1, "category": CAT2, "menu_pos": 5, "tooltip": "Brightness multiplier on the outline colour."})

	var CAT3 := "03. Outline Colours"
	cfg.set_value("Color", "state_normal", {"name": "Normal / idle", "default": Color(1.0, 0.72, 0.28), "value": Color(1.0, 0.72, 0.28), "allowAlpha": false, "category": CAT3, "menu_pos": 0, "tooltip": "Colour for NPCs that are idle, patrolling, looting or guarding."})
	cfg.set_value("Color", "state_alerted", {"name": "Alerted", "default": Color(1.0, 0.9, 0.25), "value": Color(1.0, 0.9, 0.25), "allowAlpha": false, "category": CAT3, "menu_pos": 1, "tooltip": "Colour for NPCs taking cover, defending or taking a vantage point."})
	cfg.set_value("Color", "state_hunting", {"name": "Hunting", "default": Color(1.0, 0.5, 0.1), "value": Color(1.0, 0.5, 0.1), "allowAlpha": false, "category": CAT3, "menu_pos": 2, "tooltip": "Colour for NPCs hunting, hiding, ambushing or lurking."})
	cfg.set_value("Color", "state_combat", {"name": "In combat", "default": Color(0.95, 0.18, 0.15), "value": Color(0.95, 0.18, 0.15), "allowAlpha": false, "category": CAT3, "menu_pos": 3, "tooltip": "Colour for NPCs in combat, attacking or throwing grenades."})
	cfg.set_value("Color", "nomad_color", {"name": "Friendly nomads", "default": Color(0.30, 1.0, 0.35), "value": Color(0.30, 1.0, 0.35), "allowAlpha": false, "category": CAT3, "menu_pos": 4, "tooltip": "Colour for friendly nomads. Their state is ignored."})

	var CAT4 := "04. Contour Range"
	cfg.set_value("Float", "outline_distance", {"name": "Outline distance", "default": 150.0, "value": 150.0, "minRange": 0.0, "maxRange": 300.0, "step": 10.0, "category": CAT4, "menu_pos": 0, "tooltip": "Maximum distance for an outline. Past half of this the outline fades out."})
	cfg.set_value("Float", "outline_through_walls", {"name": "See through walls", "default": 5.0, "value": 5.0, "minRange": 0.0, "maxRange": 30.0, "step": 5.0, "category": CAT4, "menu_pos": 1, "tooltip": "NPCs closer than this show through walls. 0 = only when in direct line of sight."})

	var CAT5 := "05. Diagnostics"
	cfg.set_value("Bool", "debug_log", {"name": "Debug log", "default": false, "value": false, "category": CAT5, "menu_pos": 0, "tooltip": "Write a diagnostic log of the contour ESP to user://MCM/thermal-vtk/debug.log. For troubleshooting; leave off for normal play."})

	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "version", _mod_version())
	cfg.set_value("Info", "author", "CaptiveAI and opencode")
	DirAccess.make_dir_recursive_absolute(CONFIG_DIR)
	_sync_config(cfg)
	MCM.RegisterConfiguration(MOD_ID, MOD_NAME, CONFIG_DIR, "NVG thermal overlay: bot, mine and Nomad highlighting", _mcm_apply, self)
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
	if _saved_palette >= 0:
		_nvg.set_palette = _saved_palette
	else:
		_nvg.set_palette = _palette_mode_from_cfg(cfg)
	_nvg.set_world = float(_mcm_key_val(cfg, "Float", "thermal_world", 1.70))
	_nvg.set_thermal_enabled(_thermal_enabled)
	_nvg.set_mines_enabled(_mines_enabled)
	_ensure_esp()
	if _esp != null and is_instance_valid(_esp):
		_esp.p_decay = float(_mcm_key_val(cfg, "Float", "corpse_decay", 8.0))
		_esp.p_dist = float(_mcm_key_val(cfg, "Float", "outline_distance", 150.0))
		_esp.p_through = float(_mcm_key_val(cfg, "Float", "outline_through_walls", 5.0))
		_esp.p_thickness = float(_mcm_key_val(cfg, "Float", "outline_thickness", 0.006))
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
		_esp.p_fill = bool(_mcm_key_val(cfg, "Bool", "outline_body_fill", true))
		_esp.p_fill_alpha = float(_mcm_key_val(cfg, "Float", "fill_opacity", 0.4))
		_esp.p_brightness = float(_mcm_key_val(cfg, "Float", "outline_brightness", 0.6))
		_nvg.set_outline_brightness = _esp.p_brightness
		_nvg.set_state_colors({
			"state_normal": _mcm_color_val(cfg, "state_normal", States.DEFAULT_NORMAL),
			"state_alerted": _mcm_color_val(cfg, "state_alerted", States.DEFAULT_ALERTED),
			"state_hunting": _mcm_color_val(cfg, "state_hunting", States.DEFAULT_HUNTING),
			"state_combat": _mcm_color_val(cfg, "state_combat", States.DEFAULT_COMBAT),
			"nomad_color": _mcm_color_val(cfg, "nomad_color", States.DEFAULT_NOMAD),
		})
	_outline_enabled = bool(_mcm_key_val(cfg, "Bool", "outline_enabled", true))
	_apply_mode()

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
