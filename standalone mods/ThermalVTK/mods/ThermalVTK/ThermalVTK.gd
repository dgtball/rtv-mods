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
const KEY_MODE := KEY_F6
# TEMP CALIBRATION (Task 6): press while looking at an NPC in Mode A to log the
# washed contour-ring colours. Remove after Task 6.
const KEY_PROBE := KEY_F7

var _nvg: Node = null
var _esp: Node = null
var _key_thermal_toggle: int = 0
var _thermal_enabled: bool = false
var _mines_enabled: bool = true
var _mcm_thermal_seen: int = -1
var _mode_full_thermal: bool = false
var _outline_enabled: bool = true
var _nvg_worn: bool = false

func _ready() -> void:
	var saved_mode = _read_state("full_thermal_mode", false)
	_mode_full_thermal = bool(saved_mode) if saved_mode != null else false
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
	if k.physical_keycode == KEY_MODE:
		_toggle_mode()
		get_viewport().set_input_as_handled()
		return
	if k.physical_keycode == KEY_PROBE:
		_run_ring_probe()
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

func _toggle_mode() -> void:
	_mode_full_thermal = not _mode_full_thermal
	_apply_mode()
	_notify("Thermal mode: " + ("FULL" if _mode_full_thermal else "CONTOUR"),
		Color(0.6, 0.8, 1.0) if _mode_full_thermal else Color(1, 0.7, 0.3))
	_save_state("full_thermal_mode", _mode_full_thermal)

func _apply_mode() -> void:
	if _nvg != null and is_instance_valid(_nvg):
		# Mode B = v1: bots carry the detector keys the NVG screen reads.
		# Mode A: keys off, contour ESP on.
		_nvg.set_bot_paint(_mode_full_thermal)
	if _esp != null and is_instance_valid(_esp):
		_esp.set_enabled(_thermal_enabled and _outline_enabled and not _mode_full_thermal and _nvg_active())

func _nvg_active() -> bool:
	if _nvg == null or not is_instance_valid(_nvg):
		return false
	return _nvg.nvg_active()

# The contour lives in world space, so it does not follow vanilla NVG by itself.
# Watch the worn state and re-apply on change, or outlines would keep drawing
# with the helmet off and only appear on the next mode/hotkey change.
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

# TEMP CALIBRATION (Task 6): the ring emits a detector key that the vanilla NVG
# world processing washes, so its on-screen colour cannot be read by eye (and
# the washed value differs per key). Press F7 facing an NPC in Mode A: the probe
# cycles every state key (plus mine as a control) across all rings, and for each
# captures a raw frame with the ESP on and one with it off, diffing them with a
# magnitude-weighted average so the ring dominates the world drift. Logs the
# washed colour of each key. Remove after Task 6.
const CAL_KEYS := [
	["normal", Color(1.0, 0.0, 0.0)],
	["alerted", Color(1.0, 1.0, 0.0)],
	["hunting", Color(1.0, 0.0, 1.0)],
	["combat", Color(0.0, 1.0, 1.0)],
	["nomad", Color(0.0, 1.0, 0.0)],
	["mine(ctrl)", Color(0.0, 0.0, 1.0)],
]
var _probe_busy: bool = false

func _run_ring_probe() -> void:
	if _probe_busy:
		return
	if _nvg == null or not is_instance_valid(_nvg) or _esp == null or not is_instance_valid(_esp):
		VTKDebug.log("PROBE", "nvg/esp missing")
		return
	if not _esp.enabled:
		VTKDebug.log("PROBE", "esp off: set thermal ON, mode CONTOUR, wear NVG")
		return
	var vp := get_viewport()
	if vp == null:
		return
	_probe_busy = true
	_nvg.set_debug_raw(true)
	var old_thick: float = _esp.p_thickness
	_esp.p_thickness = 0.02
	for idx in CAL_KEYS.size():
		var label: String = CAL_KEYS[idx][0]
		_esp.key_override_on = true
		_esp.key_override = CAL_KEYS[idx][1]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img_a := vp.get_texture().get_image()
		await RenderingServer.frame_post_draw
		var img_ref := vp.get_texture().get_image()
		_esp.set_enabled(false)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img_off := vp.get_texture().get_image()
		_esp.set_enabled(true)
		await RenderingServer.frame_post_draw
		if img_a == null or img_ref == null or img_off == null:
			VTKDebug.log("PROBE", "%s: no frame image" % label)
			continue
		_probe_diff(label, img_a, img_ref, img_off)
	_esp.p_thickness = old_thick
	_esp.key_override_on = false
	_nvg.set_debug_raw(false)
	_probe_busy = false
	VTKDebug.log("PROBE", "calibration done")

# Diff two ESP-on frames (img_a vs img_ref, one frame apart) to reject pixels
# whose WORLD moved, then diff the surviving static pixels against an ESP-off
# frame (img_off). Only the ring differs between a static on/off pair, so the
# kept pixels are ring pixels and their colour is the washed key. Without the
# motion gate the world drift injects RGB fringing that swamps the ring.
func _probe_diff(label: String, img_a: Image, img_ref: Image, img_off: Image) -> void:
	var w := img_a.get_width()
	var h := img_a.get_height()
	if img_ref.get_width() != w or img_off.get_width() != w \
			or img_ref.get_height() != h or img_off.get_height() != h:
		VTKDebug.log("PROBE", "%s: size mismatch" % label)
		return
	var a := img_a.get_data()
	var ref := img_ref.get_data()
	var b := img_off.get_data()
	if a.size() != ref.size() or a.size() != b.size():
		VTKDebug.log("PROBE", "%s: data size mismatch" % label)
		return
	var changed := 0
	var moving := 0
	var maxd := 0
	var wsum := 0.0
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var buckets: Dictionary = {}
	var n := a.size()
	var i := 0
	while i + 3 < n:
		var mr := absi(int(a[i]) - int(ref[i]))
		var mg := absi(int(a[i + 1]) - int(ref[i + 1]))
		var mb := absi(int(a[i + 2]) - int(ref[i + 2]))
		if mr + mg + mb > 24:
			moving += 1
			i += 4
			continue
		var dr := absi(int(a[i]) - int(b[i]))
		var dg := absi(int(a[i + 1]) - int(b[i + 1]))
		var dbl := absi(int(a[i + 2]) - int(b[i + 2]))
		var d := dr + dg + dbl
		if d > maxd:
			maxd = d
		if d > 24:
			var r := float(a[i]) / 255.0
			var g := float(a[i + 1]) / 255.0
			var bl := float(a[i + 2]) / 255.0
			changed += 1
			wsum += float(d)
			sr += r * float(d)
			sg += g * float(d)
			sb += bl * float(d)
			var bk := "%d_%d_%d" % [int(r * 16.0), int(g * 16.0), int(bl * 16.0)]
			var bkt = buckets.get(bk)
			if bkt == null:
				buckets[bk] = [r, g, bl, 1]
			else:
				bkt[0] += r
				bkt[1] += g
				bkt[2] += bl
				bkt[3] += 1
		i += 4
	if changed == 0:
		VTKDebug.log("PROBE", "%s: no static ring pixels (moving=%d maxd=%d)" % [label, moving, maxd])
		return
	VTKDebug.log("PROBE", "%s: stable=%d moving=%d maxd=%d washed=(%.3f, %.3f, %.3f)" % [label, changed, moving, maxd, sr / wsum, sg / wsum, sb / wsum])
	var keys := buckets.keys()
	keys.sort_custom(func(x, y): return int(buckets[x][3]) > int(buckets[y][3]))
	var shown: int = min(keys.size(), 4)
	for j in shown:
		var v: Array = buckets[keys[j]]
		var cnt := int(v[3])
		VTKDebug.log("PROBE", "  %s top n=%d avg=(%.3f, %.3f, %.3f)" % [label, cnt, v[0] / cnt, v[1] / cnt, v[2] / cnt])

# Persist hotkey/mode choices in our own state file. MCM keeps an in-memory copy
# and rewrites its config wholesale, so writing the toggle there gets clobbered.
# Read-modify-write so the two keys (thermal_enabled, full_thermal_mode) do not
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
	cfg.set_value("Float", "nvg_noise", {"name": "NVG noise", "default": 4.0, "value": 4.0, "minRange": 0.0, "maxRange": 60.0, "step": 0.5, "category": CAT, "menu_pos": 1, "tooltip": "Grain amount over the NVG image. Lower is cleaner. Vanilla is fixed at 10."})
	cfg.set_value("Float", "nvg_white", {"name": "NVG brightness", "default": 1.0, "value": 1.0, "minRange": 0.05, "maxRange": 1.0, "step": 0.05, "category": CAT, "menu_pos": 2, "tooltip": "Brightness of the NVG image. 1 = full brightness; lower darkens the whole overlay."})
	cfg.set_value("Bool", "thermal_enabled", {"name": "Thermal vision", "default": false, "value": false, "category": CAT, "menu_pos": 3, "tooltip": "Master switch for the thermal vision layer: bot heat glow and mines. Plain green NVG is unaffected while this is off."})
	cfg.set_value("Bool", "thermal_mines", {"name": "Mine highlighting", "default": true, "value": true, "category": CAT, "menu_pos": 4, "tooltip": "Highlight mines while thermal vision is on."})
	cfg.set_value("Dropdown", "thermal_palette", {"default": "classic", "value": "classic", "options": {"classic": "Classic", "amber": "Amber", "forest": "Forest", "ice": "Ice"}, "category": CAT, "menu_pos": 9, "tooltip": "World thermal palette.", "name": "World palette"})
	cfg.set_value("Float", "thermal_world", {"default": 1.70, "value": 1.70, "minRange": 1.0, "maxRange": 4.0, "step": 0.05, "category": CAT, "menu_pos": 10, "tooltip": "How bright the surrounding world reads in thermal.", "name": "World brightness"})
	cfg.set_value("Int", "thermal_bot_preset", {"default": 0, "value": 0, "minRange": 0, "maxRange": 3, "step": 1, "category": CAT, "menu_pos": 11, "tooltip": "0 = Amber, 1 = White, 2 = Orange, 3 = Red. Living bots glow in this colour; a corpse cools from the head down before disappearing.", "name": "Bot colour"})
	cfg.set_value("Float", "thermal_far_distance", {"default": 45.0, "value": 45.0, "minRange": 5.0, "maxRange": 300.0, "step": 5.0, "category": CAT, "menu_pos": 12, "tooltip": "Bots and mines only glow within this distance; past it they read as ordinary scenery. 5 = only right beside you, 300 = the whole map.", "name": "Distance"})

	var CAT2 := "02. Contour ESP"
	cfg.set_value("Bool", "outline_enabled", {"name": "Contour ESP", "default": true, "value": true, "category": CAT2, "menu_pos": 0, "tooltip": "Draw state-coloured body outlines over NPCs. Off = full-screen thermal only."})
	cfg.set_value("Bool", "outline_body_fill", {"name": "Body fill", "default": true, "value": true, "category": CAT2, "menu_pos": 1, "tooltip": "Fill the NPC body with a warm-to-cold thermal gradient inside the outline."})
	cfg.set_value("Float", "corpse_decay", {"name": "Corpse cooling time", "default": 8.0, "value": 8.0, "minRange": 0.0, "maxRange": 30.0, "step": 1.0, "category": CAT2, "menu_pos": 2, "tooltip": "Seconds a dead NPC's outline takes to cool from warm to cold."})
	cfg.set_value("Float", "outline_thickness", {"name": "Outline thickness", "default": 0.006, "value": 0.006, "minRange": 0.0, "maxRange": 0.05, "step": 0.001, "category": CAT2, "menu_pos": 3, "tooltip": "How far the outline band grows beyond the body."})
	cfg.set_value("Float", "outline_brightness", {"name": "Outline brightness", "default": 0.6, "value": 0.6, "minRange": 0.1, "maxRange": 3.0, "step": 0.1, "category": CAT2, "menu_pos": 4, "tooltip": "Brightness multiplier on the outline colour."})
	cfg.set_value("Bool", "outline_pvisible", {"name": "Spotted flash", "default": true, "value": true, "category": CAT2, "menu_pos": 5, "tooltip": "Flash the body when the NPC's own sensors currently see you."})
	cfg.set_value("Color", "pvisible_color", {"name": "Flash colour", "default": Color(1, 1, 1), "value": Color(1, 1, 1), "allowAlpha": false, "category": CAT2, "menu_pos": 6, "tooltip": "Colour the body flashes when the NPC sees you."})

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
	_nvg.set_palette = _palette_mode_from_cfg(cfg)
	_nvg.set_world = float(_mcm_key_val(cfg, "Float", "thermal_world", 1.70))
	_nvg.set_bot_preset = int(_mcm_key_val(cfg, "Int", "thermal_bot_preset", 0))
	_nvg.set_far_distance = float(_mcm_key_val(cfg, "Float", "thermal_far_distance", 45.0))
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
		_esp.p_flash = bool(_mcm_key_val(cfg, "Bool", "outline_pvisible", true))
		_esp.p_flash_color = _mcm_color_val(cfg, "pvisible_color", Color.WHITE)
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
