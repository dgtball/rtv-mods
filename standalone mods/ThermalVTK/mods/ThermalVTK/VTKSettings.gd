extends RefCounted

const States = preload("res://mods/ThermalVTK/VTKStates.gd")

# Single source of truth for every mod setting. The DESCRIPTORS table drives
# the MCM registration (labels, ranges, defaults), the profile merge
# (ThermalVTK._sync_config) and the typed ConfigRec that the feature nodes
# consume through apply_config(). A setting exists once here, or not at all:
# the triple bookkeeping that previously lived in the registration literals,
# the _mcm_apply fallbacks and the module fields was the recipe for silent
# divergence (nvg_noise 0.0 vs 4.0, outline_rim 2.0 vs 1.0).

class Rec:
	# Hotkeys (0 = unbound; KEY_* fallbacks).
	var key_thermal_toggle: int = 0
	var key_palette_cycle: int = KEY_F6
	var key_debug_probe: int = KEY_F7
	var key_cal_cycle: int = KEY_F8
	# Toggles.
	var debug_log: bool = false
	var outline_enabled: bool = true
	var outline_xray: bool = true
	var thermal_mines: bool = true
	var nomad_marker: bool = true
	var daylight_compensation: bool = true
	# Thermal world.
	var nvg_noise: float = 0.0
	var nvg_white: float = 1.0
	var world: float = 1.70
	# Daylight highlight rolloff knee (1.0 = off).
	var highlight_knee: float = 0.6
	# NPC outlines.
	var corpse_decay: float = 90.0
	var outline_distance: float = 60.0
	var outline_thickness: float = 0.006
	var outline_brightness: float = 0.6
	var outline_rim: float = 2.0
	# X-ray Triggers: reveal window ranges ("_d") and durations ("_s").
	var fire_d: float = 80.0
	var fire_s: float = 2.0
	var voice_d: float = 5.0
	var voice_s: float = 2.0
	var idle_d: float = 5.0
	var idle_s: float = 1.0
	var move_d: float = 5.0
	var move_s: float = 1.0
	var run_d: float = 8.0
	var reload_d: float = 2.0
	var reload_s: float = 1.0
	var pain_d: float = 10.0
	var pain_s: float = 2.0
	var nade_d: float = 50.0
	var nade_s: float = 2.0
	# State colours. The values live in VTKStates only; the shader keys and the
	# defaults are one set, so a tuning change cannot land in half of them.
	var color_normal: Color = States.DEFAULT_NORMAL
	var color_combat: Color = States.DEFAULT_COMBAT
	var color_defend: Color = States.DEFAULT_DEFEND

	func state_colors() -> Dictionary:
		return {
			"state_normal": color_normal,
			"state_combat": color_combat,
			"state_defend": color_defend,
		}

# One row per MCM setting. "sect" selects the registration shape: Float gets
# minRange/maxRange/step, Keycode gets type/default_type, Bool and Color are
# plain entries. "def" is the default and the only place it exists: the MCM
# menu shows it and missing profile keys fall back to it in read().
const DESCRIPTORS: Array[Dictionary] = [
	{"sect": "Keycode", "key": "key_thermal_toggle", "name": "Thermal vision", "def": 0, "cat": "01. ThermalVision", "pos": 0, "tip": "Hotkey: press in game to turn the thermal layer on and off."},
	{"sect": "Keycode", "key": "key_palette_cycle", "name": "World palette", "def": KEY_F6, "cat": "01. ThermalVision", "pos": 1, "tip": "Hotkey: cycle the world thermal palette."},
	# The outline_xray toggle gates only the wall flash: trigger windows
	# (tags and the debug label countdown) run regardless of it.
	{"sect": "Bool", "key": "outline_enabled", "name": "NPC highlighting (ESP)", "def": true, "cat": "NPC ESP", "pos": 2, "tip": "Draw state-coloured body outlines over NPCs while thermal vision is on. Off = full-screen thermal only."},
	{"sect": "Bool", "key": "outline_xray", "name": "X-ray Triggers", "def": true, "cat": "X-ray Triggers", "pos": 3, "tip": "While on, the NPC ring lights up through walls only while a sound event is live: gunfire, shouts, idle chatter, footsteps, reloads, pain cries or grenade throws. Between events the outline stays a normal ring behind walls. The reveal timers themselves show on the debug labels regardless of this toggle."},
	{"sect": "Bool", "key": "thermal_mines", "name": "Mine highlighting", "def": true, "cat": "Mine ESP", "pos": 4, "tip": "Highlight mines while thermal vision is on."},
	{"sect": "Bool", "key": "nomad_marker", "name": "Friendly-nomad diamond", "def": true, "cat": "Nomad ESP", "pos": 10, "tip": "Draw a small diamond over friendly nomads while thermal vision is on. Independent of the debug log."},
	{"sect": "Float", "key": "nvg_noise", "name": "NVG noise", "def": 0.0, "min": 0.0, "max": 60.0, "step": 0.5, "cat": "01. ThermalVision", "pos": 5, "tip": "Grain amount over the NVG image. Lower is cleaner. Vanilla is fixed at 10."},
	{"sect": "Float", "key": "nvg_white", "name": "NVG brightness", "def": 1.0, "min": 0.05, "max": 1.0, "step": 0.05, "cat": "01. ThermalVision", "pos": 6, "tip": "Brightness of the NVG image. 1 = full brightness; lower darkens the whole overlay."},
	{"sect": "Float", "key": "thermal_world", "name": "World brightness", "def": 1.70, "min": 1.0, "max": 4.0, "step": 0.05, "cat": "01. ThermalVision", "pos": 7, "tip": "How bright the surrounding world reads in thermal."},
	{"sect": "Bool", "key": "daylight_compensation", "name": "Daylight compensation", "def": true, "cat": "01. ThermalVision", "pos": 8, "tip": "In bright daylight, lower the game's exposure so snow and sky keep detail instead of washing out. No effect at night; interiors are only slightly trimmed."},
	{"sect": "Float", "key": "thermal_highlight_knee", "name": "Highlight rolloff", "def": 0.6, "min": 0.3, "max": 1.0, "step": 0.05, "cat": "01. ThermalVision", "pos": 9, "tip": "In daylight, background pixels brighter than this (snow, sky, clouds) bend into a softer highlight and keep their detail instead of washing out. Lower = stronger trim. Night is unaffected; 1.0 disables it."},
	{"sect": "Float", "key": "outline_distance", "name": "Distance", "def": 60.0, "min": 0.0, "max": 300.0, "step": 10.0, "cat": "NPC ESP", "pos": 0, "tip": "Maximum distance for an outline. Outlines are hidden past this range."},
	{"sect": "Float", "key": "outline_rim", "name": "Rim", "def": 2.0, "min": 0.0, "max": 6.0, "step": 0.5, "cat": "NPC ESP", "pos": 1, "tip": "Edge sharpness of the outline. 1.0 is a linear falloff; higher values tighten the band toward the silhouette."},
	{"sect": "Float", "key": "outline_thickness", "name": "Thickness", "def": 0.006, "min": 0.001, "max": 0.02, "step": 0.001, "cat": "NPC ESP", "pos": 2, "tip": "How far the outline band grows beyond the body."},
	{"sect": "Float", "key": "outline_brightness", "name": "Brightness", "def": 0.6, "min": 0.1, "max": 3.0, "step": 0.1, "cat": "NPC ESP", "pos": 3, "tip": "Brightness multiplier on the outline colour."},
	{"sect": "Float", "key": "corpse_decay", "name": "Cooling time", "def": 90.0, "min": 0.0, "max": 180.0, "step": 1.0, "cat": "NPC ESP", "pos": 4, "tip": "Seconds a dead NPC's outline takes to cool from warm to cold."},
	{"sect": "Float", "key": "trigger_fire_dist", "name": "Gunfire distance", "def": 80.0, "min": 0.0, "max": 300.0, "step": 5.0, "cat": "X-ray Triggers", "pos": 0, "tip": "Reveal range for a gun-shot."},
	{"sect": "Float", "key": "trigger_voice_dist", "name": "Combat voice distance", "def": 5.0, "min": 0.0, "max": 60.0, "step": 1.0, "cat": "X-ray Triggers", "pos": 1, "tip": "Reveal range for a combat shout."},
	{"sect": "Float", "key": "trigger_idle_dist", "name": "Voice distance", "def": 5.0, "min": 0.0, "max": 30.0, "step": 1.0, "cat": "X-ray Triggers", "pos": 2, "tip": "Reveal range for a calm bot's chatter (the periodic voice cycle)."},
	{"sect": "Float", "key": "trigger_move_dist", "name": "Walk distance", "def": 5.0, "min": 0.0, "max": 40.0, "step": 1.0, "cat": "X-ray Triggers", "pos": 3, "tip": "Reveal range for footsteps from a walking bot."},
	{"sect": "Float", "key": "trigger_run_dist", "name": "Sprint distance", "def": 8.0, "min": 0.0, "max": 60.0, "step": 1.0, "cat": "X-ray Triggers", "pos": 4, "tip": "Reveal range for a sprinting bot's footsteps."},
	{"sect": "Float", "key": "trigger_reload_dist", "name": "Reload distance", "def": 2.0, "min": 0.0, "max": 40.0, "step": 1.0, "cat": "X-ray Triggers", "pos": 5, "tip": "Reveal range for a reload."},
	{"sect": "Float", "key": "trigger_pain_dist", "name": "Pain cry distance", "def": 10.0, "min": 0.0, "max": 40.0, "step": 1.0, "cat": "X-ray Triggers", "pos": 6, "tip": "Reveal range for a pain cry."},
	{"sect": "Float", "key": "trigger_nade_dist", "name": "Grenade distance", "def": 50.0, "min": 0.0, "max": 120.0, "step": 5.0, "cat": "X-ray Triggers", "pos": 7, "tip": "Reveal range for a thrown grenade."},
	{"sect": "Float", "key": "trigger_fire_time", "name": "Gunfire seconds", "def": 2.0, "min": 1.0, "max": 15.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 8, "tip": "How long the gun-shot reveal stays up."},
	{"sect": "Float", "key": "trigger_voice_time", "name": "Combat voice seconds", "def": 2.0, "min": 1.0, "max": 15.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 9, "tip": "How long the combat-shout reveal stays up."},
	{"sect": "Float", "key": "trigger_idle_time", "name": "Voice seconds", "def": 1.0, "min": 1.0, "max": 10.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 10, "tip": "How long the calm-chatter reveal stays up."},
	{"sect": "Float", "key": "trigger_move_time", "name": "Footsteps seconds", "def": 1.0, "min": 1.0, "max": 10.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 11, "tip": "How long the footstep reveal stays up."},
	{"sect": "Float", "key": "trigger_reload_time", "name": "Reload seconds", "def": 1.0, "min": 1.0, "max": 10.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 12, "tip": "How long the reload-sound reveal stays up."},
	{"sect": "Float", "key": "trigger_pain_time", "name": "Pain cry seconds", "def": 2.0, "min": 1.0, "max": 10.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 13, "tip": "How long the pain-cry reveal stays up after the bot takes damage."},
	{"sect": "Float", "key": "trigger_nade_time", "name": "Grenade seconds", "def": 2.0, "min": 1.0, "max": 15.0, "step": 0.5, "cat": "X-ray Triggers", "pos": 14, "tip": "How long the grenade-throw reveal stays up."},
	{"sect": "Color", "key": "state_normal", "name": "Default", "def": States.DEFAULT_NORMAL, "cat": "NPC ESP", "pos": 5, "tip": "Colour for NPCs that are idle, patrolling, looting or guarding."},
	{"sect": "Color", "key": "state_combat", "name": "In combat", "def": States.DEFAULT_COMBAT, "cat": "NPC ESP", "pos": 6, "tip": "Colour for NPCs in combat, hunting, attacking or throwing grenades."},
	{"sect": "Color", "key": "state_defend", "name": "Defending", "def": States.DEFAULT_DEFEND, "cat": "NPC ESP", "pos": 7, "tip": "Colour for NPCs taking cover, defending, ambushing or lurking."},
	{"sect": "Bool", "key": "debug_log", "name": "Debug log", "def": false, "cat": "04. Diagnostics", "pos": 0, "tip": "Write a diagnostic log of the contour ESP to user://MCM/thermal-vtk/debug.log. For troubleshooting; leave off for normal play."},
	{"sect": "Keycode", "key": "key_debug_probe", "name": "Hotkey: Debug key probe", "def": KEY_F7, "cat": "04. Diagnostics", "pos": 20, "tip": "Writes the colour under the crosshair to the debug log. Turn the debug log on first, then press it while aiming at an outlined NPC or the nomad marker. The view blinks for one frame."},
	{"sect": "Keycode", "key": "key_cal_cycle", "name": "Hotkey: Calibration cycle", "def": KEY_F8, "cat": "04. Diagnostics", "pos": 21, "tip": "Debug tool: cycles a test colour for the outline and the nomad marker, so its colour under the night-vision helmet can be measured with the debug probe. Turn the debug log on first, then aim at an outlined NPC and press the probe key. Shift turns the calibration off."},
]

# The seed MCM copies a fresh profile from: every entry the mod declares, with
# the defaults as the values. ThermalVTK adds the Info rows on top.
static func mcm_config() -> ConfigFile:
	var cfg = ConfigFile.new()
	for r in DESCRIPTORS:
		var sect: String = r["sect"]
		var entry := {}
		entry["name"] = r["name"]
		entry["value"] = r["def"]
		entry["category"] = r["cat"]
		entry["menu_pos"] = r["pos"]
		entry["tooltip"] = r["tip"]
		match sect:
			"Keycode":
				entry["type"] = "Key"
				entry["default"] = r["def"]
				entry["default_type"] = "Keycode"
			"Float":
				entry["default"] = r["def"]
				entry["minRange"] = r["min"]
				entry["maxRange"] = r["max"]
				entry["step"] = r["step"]
			_:
				entry["default"] = r["def"]
				if sect == "Color":
					entry["allowAlpha"] = false
		cfg.set_value(sect, r["key"], entry)
	return cfg

# Typed snapshot of a config: profile dictionaries with their "value" payload,
# raw scalars written by hand (coerced), or the Rec defaults for keys the
# profile does not carry.
static func read(cfg: ConfigFile) -> Rec:
	var rec := Rec.new()
	rec.key_thermal_toggle = int(_val(cfg, "Keycode", "key_thermal_toggle", rec.key_thermal_toggle))
	rec.key_palette_cycle = int(_val(cfg, "Keycode", "key_palette_cycle", rec.key_palette_cycle))
	rec.key_debug_probe = int(_val(cfg, "Keycode", "key_debug_probe", rec.key_debug_probe))
	rec.key_cal_cycle = int(_val(cfg, "Keycode", "key_cal_cycle", rec.key_cal_cycle))
	rec.debug_log = bool(_val(cfg, "Bool", "debug_log", rec.debug_log))
	rec.outline_enabled = bool(_val(cfg, "Bool", "outline_enabled", rec.outline_enabled))
	rec.outline_xray = bool(_val(cfg, "Bool", "outline_xray", rec.outline_xray))
	rec.thermal_mines = bool(_val(cfg, "Bool", "thermal_mines", rec.thermal_mines))
	rec.nomad_marker = bool(_val(cfg, "Bool", "nomad_marker", rec.nomad_marker))
	rec.daylight_compensation = bool(_val(cfg, "Bool", "daylight_compensation", rec.daylight_compensation))
	rec.nvg_noise = float(_val(cfg, "Float", "nvg_noise", rec.nvg_noise))
	rec.nvg_white = float(_val(cfg, "Float", "nvg_white", rec.nvg_white))
	rec.world = float(_val(cfg, "Float", "thermal_world", rec.world))
	rec.highlight_knee = float(_val(cfg, "Float", "thermal_highlight_knee", rec.highlight_knee))
	rec.corpse_decay = float(_val(cfg, "Float", "corpse_decay", rec.corpse_decay))
	rec.outline_distance = float(_val(cfg, "Float", "outline_distance", rec.outline_distance))
	rec.outline_thickness = float(_val(cfg, "Float", "outline_thickness", rec.outline_thickness))
	rec.outline_brightness = float(_val(cfg, "Float", "outline_brightness", rec.outline_brightness))
	rec.outline_rim = float(_val(cfg, "Float", "outline_rim", rec.outline_rim))
	rec.fire_d = float(_val(cfg, "Float", "trigger_fire_dist", rec.fire_d))
	rec.fire_s = float(_val(cfg, "Float", "trigger_fire_time", rec.fire_s))
	rec.voice_d = float(_val(cfg, "Float", "trigger_voice_dist", rec.voice_d))
	rec.voice_s = float(_val(cfg, "Float", "trigger_voice_time", rec.voice_s))
	rec.idle_d = float(_val(cfg, "Float", "trigger_idle_dist", rec.idle_d))
	rec.idle_s = float(_val(cfg, "Float", "trigger_idle_time", rec.idle_s))
	rec.move_d = float(_val(cfg, "Float", "trigger_move_dist", rec.move_d))
	rec.move_s = float(_val(cfg, "Float", "trigger_move_time", rec.move_s))
	rec.run_d = float(_val(cfg, "Float", "trigger_run_dist", rec.run_d))
	rec.reload_d = float(_val(cfg, "Float", "trigger_reload_dist", rec.reload_d))
	rec.reload_s = float(_val(cfg, "Float", "trigger_reload_time", rec.reload_s))
	rec.pain_d = float(_val(cfg, "Float", "trigger_pain_dist", rec.pain_d))
	rec.pain_s = float(_val(cfg, "Float", "trigger_pain_time", rec.pain_s))
	rec.nade_d = float(_val(cfg, "Float", "trigger_nade_dist", rec.nade_d))
	rec.nade_s = float(_val(cfg, "Float", "trigger_nade_time", rec.nade_s))
	rec.color_normal = _col(cfg, "state_normal", rec.color_normal)
	rec.color_combat = _col(cfg, "state_combat", rec.color_combat)
	rec.color_defend = _col(cfg, "state_defend", rec.color_defend)
	return rec

# One shape for an MCM entry: {"name": ..., "value": X, ...}. A bare scalar
# (someone hand-inserted the value) still counts; a dictionary without
# "value" counts as nothing.
static func _val(cfg: ConfigFile, sect: String, key: String, fallback: Variant) -> Variant:
	if not cfg.has_section_key(sect, key):
		return fallback
	var d = cfg.get_value(sect, key, {})
	if typeof(d) == TYPE_DICTIONARY:
		if d.has("value"):
			return d["value"]
		return fallback
	return d

static func _col(cfg: ConfigFile, key: String, fallback: Color) -> Color:
	if not cfg.has_section_key("Color", key):
		return fallback
	var d = cfg.get_value("Color", key, {})
	var v = d.get("value") if typeof(d) == TYPE_DICTIONARY else d
	return v if v is Color else fallback
