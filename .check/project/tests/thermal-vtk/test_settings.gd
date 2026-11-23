extends SceneTree

# VTKSettings is the single source of truth: the descriptor table drives the
# MCM registration AND the typed record the feature nodes consume through
# apply_config(). These tests pin the table-to-record plumbing and the field
# maps on both consumer modules, so a renamed key or a forgotten field fails
# fast instead of silently keeping the old value.

const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const ESP = preload("res://mods/ThermalVTK/VTKESP.gd")
const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")

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
	t_unified_outline_defaults_and_no_fill_toggle()
	t_read_reads_values()
	t_read_defaults()
	t_read_coerces_scalars()
	t_mcm_config_shape()
	t_defaults_consistency()
	t_distance_tooltip_is_honest()
	t_esp_apply_maps_fields()
	t_nvg_apply_maps_fields()
	print("")
	if fails == 0:
		print("Settings tests passed")
		quit(0)
	else:
		print("Settings tests failed: ", fails)
		quit(1)

# The outline has one rendering path, so its three tunables have one default
# set shared by the settings record and the MCM registration. The removed
# full-body toggle must not linger in either.
func t_unified_outline_defaults_and_no_fill_toggle() -> void:
	ck(absf(Settings.OUTLINE_THICKNESS - 0.005) < 0.000001, "unified thickness default")
	ck(absf(Settings.OUTLINE_BRIGHTNESS - 0.6) < 0.000001, "unified brightness default")
	ck(absf(Settings.FILL_ALPHA - 0.2) < 0.000001, "unified fill alpha default")
	var rec := Settings.Rec.new()
	ck(rec.get("body_fill") == null, "the record has no full-body fill field")
	var registered := false
	for r in Settings.DESCRIPTORS:
		if str(r["key"]) == "body_fill":
			registered = true
	ck(not registered, "no body_fill descriptor remains")
	ck(not Settings.mcm_config().has_section_key("Bool", "body_fill"), "MCM no longer registers the fill toggle")
	ck(absf(rec.outline_thickness - Settings.OUTLINE_THICKNESS) < 0.000001, "record thickness uses the constant")
	ck(absf(rec.outline_brightness - Settings.OUTLINE_BRIGHTNESS) < 0.000001, "record brightness uses the constant")
	ck(absf(rec.fill_alpha - Settings.FILL_ALPHA) < 0.000001, "record fill alpha uses the constant")

func t_read_reads_values() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("Float", "outline_brightness", {"name": "Brightness", "value": 2.5})
	cfg.set_value("Float", "corpse_decay", {"name": "Cooling time", "value": 44.0})
	cfg.set_value("Bool", "outline_xray", {"name": "X-ray Triggers", "value": false})
	cfg.set_value("Bool", "daylight_compensation", {"name": "Daylight compensation", "value": false})
	cfg.set_value("Keycode", "key_thermal_toggle", {"name": "Hotkey", "value": 4194436})
	cfg.set_value("Keycode", "key_live_panel", {"name": "Live panel", "value": KEY_F5})
	cfg.set_value("Color", "state_combat", {"name": "In combat", "value": Color(0.0, 1.0, 0.0)})
	var rec = Settings.read(cfg)
	ck(absf(rec.outline_brightness - 2.5) < 0.001, "read takes the value payload from the profile")
	ck(rec.corpse_decay == 44.0, "read takes the cooling time from the profile")
	ck(rec.outline_xray == false, "read takes the x-ray toggle from the profile")
	ck(rec.daylight_compensation == false, "read takes the daylight toggle from the profile")
	ck(rec.key_thermal_toggle == 4194436, "read takes the hotkey from the profile")
	ck(rec.key_live_panel == KEY_F5, "read takes the live panel key from the profile")
	ck(rec.color_combat == Color(0.0, 1.0, 0.0), "read takes the state colour from the profile")

func t_read_defaults() -> void:
	var rec = Settings.read(ConfigFile.new())
	ck(rec.get("outline_rim") == null, "the removed Rim setting has no record field")
	ck(rec.get("thermal_mix") == null, "the removed thermal mix has no record field")
	# The reveal radii follow the outline-semantics: 0 = the source is off.
	for k in ["fire", "voice", "idle", "move", "run", "reload", "pain", "nade"]:
		var rk = ("trigger_%s_dist" % k)
		var hit := {}
		for r in Settings.DESCRIPTORS:
			if r["key"] == rk:
				hit = r
		ck(typeof(hit.get("min", null)) == TYPE_FLOAT and float(hit["min"]) == 0.0,
			"%s min range is 0 (source off)" % rk)
	ck(rec.outline_distance == 90.0, "missing distance falls back to the registered default")
	ck(Settings.OUTLINE_DISTANCE == 90.0, "the declared distance default is 90")
	var drow := {}
	for r in Settings.DESCRIPTORS:
		if r["key"] == "outline_distance":
			drow = r
	ck(drow.get("def") == Settings.OUTLINE_DISTANCE, "the distance descriptor default matches the constant")
	ck(rec.nvg_noise == 0.0, "missing noise falls back to the registered default")
	ck(rec.nvg_white == 1.0, "missing NVG brightness falls back to the registered default")
	ck(rec.world == 1.70, "missing world brightness falls back to the registered default")
	ck(absf(rec.outline_thickness - 0.005) < 0.000001, "missing thickness falls back to the registered default")
	ck(absf(rec.outline_brightness - 0.6) < 0.001, "missing brightness falls back to the registered default")
	ck(absf(rec.fill_alpha - 0.2) < 0.001, "missing fill alpha falls back to the registered default")
	ck(rec.fire_d == 80.0 and rec.fire_s == 2.0, "trigger defaults: fire 80 m / 2 s")
	ck(rec.idle_d == 5.0 and rec.idle_s == 1.0, "trigger defaults: idle voice 5 m / 1 s")
	ck(rec.move_d == 5.0 and rec.move_s == 1.0, "trigger defaults: walk 5 m / 1 s")
	ck(rec.voice_d == 5.0 and rec.voice_s == 2.0, "trigger defaults: combat voice 5 m / 2 s")
	ck(rec.run_d == 8.0, "trigger defaults: sprint 8 m")
	ck(rec.reload_d == 2.0 and rec.reload_s == 1.0, "trigger defaults: reload 2 m / 1 s")
	ck(rec.pain_d == 10.0 and rec.pain_s == 2.0, "trigger defaults: pain 10 m / 2 s")
	ck(rec.nade_d == 50.0 and rec.nade_s == 2.0, "trigger defaults: grenade 50 m / 2 s")
	ck(rec.corpse_decay == 70.0, "cooling time default 70 s")
	ck(rec.outline_enabled and rec.thermal_mines and rec.nomad_marker, "toggles default on")
	ck(rec.outline_xray == false, "x-ray trigger default off")
	ck(rec.daylight_compensation, "daylight compensation defaults on")
	ck(rec.debug_log == false, "debug log defaults off")
	ck(rec.npc_labels == true, "npc labels default on")
	ck(rec.key_thermal_toggle == 0, "thermal hotkey defaults unbound")
	ck(rec.key_palette_cycle == KEY_F6 and rec.key_esp_panel == KEY_F8, "diagnostic hotkeys default to the F keys")
	ck(rec.key_live_panel == KEY_F9, "live panel key defaults to F9")
	ck(absf(rec.daylight_strength - 1.0) < 0.001, "daylight strength defaults to 1.0")
	ck(absf(rec.highlight_knee - 0.55) < 0.001, "highlight knee defaults to 0.55")
	ck(absf(rec.palette_strength - 0.58) < 0.001, "palette strength default")
	ck(absf(rec.red_hold - 0.72) < 0.001, "red hold default")
	ck(rec.color_normal == States.DEFAULT_NORMAL, "normal colour default")
	ck(rec.color_combat == States.DEFAULT_COMBAT, "combat colour default")
	ck(rec.color_defend == States.DEFAULT_DEFEND, "defend colour default")
	ck(rec.color_mine == Color8(205, 0, 255), "mine colour default")

# Hand-written scalars (a bare value instead of the {..: ..} entry) must still
# land: the profile file is player-writable.
func t_read_coerces_scalars() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("Float", "outline_thickness", 0.0125)
	cfg.set_value("Bool", "thermal_mines", false)
	cfg.set_value("Keycode", "key_palette_cycle", KEY_F1)
	cfg.set_value("Color", "state_normal", Color(0.1, 0.2, 0.3))
	cfg.set_value("Float", "outline_distance", 35.0)
	var rec = Settings.read(cfg)
	ck(absf(rec.outline_thickness - 0.0125) < 0.001, "a bare float value still reads")
	ck(rec.outline_distance == 35.0, "a saved distance still overrides the new default")
	ck(rec.thermal_mines == false, "a bare bool value still reads")
	ck(rec.key_palette_cycle == KEY_F1, "a bare hotkey still reads")
	ck(rec.color_normal == Color(0.1, 0.2, 0.3), "a bare colour still reads")

func t_mcm_config_shape() -> void:
	var cfg = Settings.mcm_config()
	ck(cfg.has_section_key("Float", "outline_brightness"), "the brightness is declared")
	ck(cfg.has_section_key("Float", "fill_alpha"), "fill alpha is declared")
	ck(not cfg.has_section_key("Float", "thermal_mix"), "thermal mix is not declared")
	ck(cfg.has_section_key("Keycode", "key_thermal_toggle"), "the thermal hotkey is declared")
	ck(cfg.has_section_key("Keycode", "key_esp_panel"), "the ESP panel hotkey is declared")
	ck(cfg.has_section_key("Keycode", "key_live_panel"), "the live panel hotkey is declared")
	ck(cfg.has_section_key("Color", "state_defend"), "the defend colour is declared")
	ck(cfg.has_section_key("Color", "mine_color"), "the mine colour is declared")
	var bright = cfg.get_value("Float", "outline_brightness", {})
	ck(bright.get("name") == "Brightness", "the registration carries the label")
	ck(absf(float(bright.get("default")) - 0.6) < 0.001, "the registration carries the default")
	ck(float(bright.get("minRange")) == 0.1 and float(bright.get("maxRange")) == 3.0 and float(bright.get("step")) == 0.1, "the registration carries the float range")
	var fill = cfg.get_value("Float", "fill_alpha", {})
	ck(absf(float(fill.get("default")) - 0.2) < 0.001, "fill alpha default is registered")
	ck(float(fill.get("minRange")) == 0.05 and float(fill.get("maxRange")) == 1.0, "fill alpha range is registered")
	var tint = cfg.get_value("Color", "state_defend", {})
	ck(bool(tint.get("allowAlpha")) == false, "colour entries forbid alpha")
	var key = cfg.get_value("Keycode", "key_thermal_toggle", {})
	ck(str(key.get("type")) == "Key" and str(key.get("default_type")) == "Keycode", "hotkey entries carry the keycode shape")

# Reading the freshly generated registration and reading an empty file must
# agree: there is exactly one default per setting, so the menu can never show
# a value the module treats differently.
func t_defaults_consistency() -> void:
	var rec = Settings.read(ConfigFile.new())
	var cfg = Settings.mcm_config()
	for r in Settings.DESCRIPTORS:
		var sect: String = r["sect"]
		var key: String = r["key"]
		var def = r["def"]
		var entry = cfg.get_value(sect, key, {})
		ck(typeof(entry) == TYPE_DICTIONARY, "descriptor %s lands in the registration" % key)
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		ck(entry.get("default") == def, "registered default equals the descriptor default for %s" % key)
		ck(entry.get("value") == def, "registered value equals the descriptor default for %s" % key)
	# Spot-check the record side of the same contract.
	ck(absf(rec.outline_brightness - float(Settings.mcm_config().get_value("Float", "outline_brightness", {}).get("default"))) < 0.001, "the record and the registration share the brightness default")

# The Distance slider hides the outline past the setting, it does not fade it.
func t_distance_tooltip_is_honest() -> void:
	for r in Settings.DESCRIPTORS:
		if r["key"] == "outline_distance":
			var tip: String = r["tip"]
			ck(not tip.contains("fades"), "the Distance tooltip does not promise a fade")
			ck(tip.contains("hidden"), "the Distance tooltip describes the hard cutoff")

func t_esp_apply_maps_fields() -> void:
	var rec = Settings.Rec.new()
	rec.corpse_decay = 44.0
	rec.outline_distance = 35.0
	rec.outline_thickness = 0.009
	rec.outline_brightness = 1.5
	rec.fill_alpha = 0.2
	rec.outline_xray = false
	rec.fire_d = 90.0
	rec.fire_s = 4.0
	rec.voice_d = 18.0
	rec.voice_s = 4.0
	rec.idle_d = 5.0
	rec.idle_s = 1.5
	rec.move_d = 9.0
	rec.move_s = 1.25
	rec.run_d = 19.0
	rec.reload_d = 11.0
	rec.reload_s = 1.5
	rec.pain_d = 14.0
	rec.pain_s = 2.5
	rec.nade_d = 55.0
	rec.nade_s = 5.5
	var esp = ESP.new()
	esp.apply_config(rec)
	ck(esp.p_decay == 44.0, "ESP maps corpse_decay")
	ck(esp.p_dist == 35.0, "ESP maps outline_distance")
	ck(esp.p_thickness == 0.009, "ESP maps outline_thickness")
	ck(absf(esp.p_brightness - 1.5) < 0.001, "ESP maps outline_brightness")
	ck(absf(esp.p_fill_alpha - 0.2) < 0.001, "ESP maps fill_alpha")
	ck(esp.get("p_body_fill") == null, "ESP has no body fill field")
	ck(esp.get("p_thermal_mix") == null, "ESP has no thermal mix field")
	ck(esp.p_trig == false, "ESP maps the x-ray toggle")
	ck(esp.p_fire_d == 90.0 and esp.p_fire_s == 4.0, "ESP maps the fire window")
	ck(esp.p_voice_d == 18.0 and esp.p_voice_s == 4.0, "ESP maps the voice window")
	ck(esp.p_idle_d == 5.0 and esp.p_idle_s == 1.5, "ESP maps the idle window")
	ck(esp.p_move_d == 9.0 and esp.p_move_s == 1.25, "ESP maps the move window")
	ck(esp.p_run_d == 19.0, "ESP maps the run window")
	ck(esp.p_reload_d == 11.0 and esp.p_reload_s == 1.5, "ESP maps the reload window")
	ck(esp.p_pain_d == 14.0 and esp.p_pain_s == 2.5, "ESP maps the pain window")
	ck(esp.p_nade_d == 55.0 and esp.p_nade_s == 5.5, "ESP maps the grenade window")
	esp.free()

func t_nvg_apply_maps_fields() -> void:
	var rec = Settings.Rec.new()
	rec.nvg_noise = 12.5
	rec.nvg_white = 0.5
	rec.world = 2.5
	rec.outline_brightness = 1.5
	rec.outline_distance = 80.0
	rec.thermal_mines = false
	rec.daylight_compensation = false
	rec.daylight_strength = 0.5
	rec.highlight_knee = 0.4
	rec.palette_strength = 0.33
	rec.red_hold = 0.44
	rec.color_combat = Color(0.0, 1.0, 0.0)
	rec.color_mine = Color(0.25, 0.5, 0.75)
	var nvg = NVG.new()
	nvg.apply_config(rec)
	ck(nvg.set_nvg_noise == 12.5, "NVG maps nvg_noise")
	ck(nvg.set_nvg_white == 0.5, "NVG maps nvg_white")
	ck(nvg.set_world == 2.5, "NVG maps world brightness")
	ck(nvg.set_glow_distance == 80.0, "NVG maps the glow distance")
	ck(nvg.set_mines == false, "NVG maps the mines toggle")
	ck(nvg.set_daylight == false, "NVG maps the daylight toggle")
	ck(nvg.set_strength == 0.5, "NVG maps daylight strength")
	ck(absf(nvg.set_highlight_knee - 0.4) < 0.001, "NVG maps highlight knee")
	ck(absf(nvg.set_palette_strength - 0.33) < 0.001, "NVG maps palette strength")
	ck(absf(nvg.set_red_hold - 0.44) < 0.001, "NVG maps red hold")
	ck(nvg.mine_color() == Color(0.25, 0.5, 0.75), "NVG maps the mine colour")
	nvg.free()
