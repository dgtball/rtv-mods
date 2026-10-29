extends SceneTree

const ThermalMod = preload("res://mods/ThermalVTK/ThermalVTK.gd")

const PROFILE_PATH := "user://thermal-vtk-profile-test.ini"
const MODCFG_PATH := "user://mod_config.cfg"

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
	t_profile_paths()
	t_active_profile_name()
	t_merge_refreshes_labels_keeps_values()
	t_apply_reads_active_profile()
	t_apply_mode_splits_layers()
	_cleanup()
	print("")
	if fails == 0:
		print("Profile tests passed")
		quit(0)
	else:
		print("Profile tests failed: ", fails)
		quit(1)

func _cleanup() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	if FileAccess.file_exists(MODCFG_PATH):
		DirAccess.remove_absolute(MODCFG_PATH)

# The mod loader can run several profiles and MCM stores the settings of the
# active one next to the default "config.ini". The menu writes that file, so
# the mod has to read the same one.
func t_profile_paths() -> void:
	var mod = ThermalMod.new()
	ck(mod._config_path_for_profile("TVVKT") == "user://MCM/thermal-vtk/TVVKT.ini",
		"the active profile file is <profile>.ini next to config.ini")
	ck(mod._config_path_for_profile("config") == "user://MCM/thermal-vtk/config.ini",
		"the default profile is config.ini")
	mod.free()

func t_active_profile_name() -> void:
	var mod = ThermalMod.new()
	var mc := ConfigFile.new()
	mc.set_value("settings", "active_profile", "TVVKT")
	mc.save(MODCFG_PATH)
	ck(mod._active_profile_name() == "TVVKT", "the mod loader profile is picked up")
	mc.set_value("settings", "active_profile", "Default")
	mc.save(MODCFG_PATH)
	ck(mod._active_profile_name() == "config", "the Default profile maps to config.ini")
	DirAccess.remove_absolute(MODCFG_PATH)
	ck(mod._active_profile_name() == "config", "a missing mod_config.cfg falls back to config.ini")
	mod.free()

# MCM creates the profile file once and never refreshes it, so the menu kept
# showing entries we removed or renamed. The mod merges its registration into
# the profile: labels, ranges and defaults come from the code, the player's
# value and their modifier flags stay.
func t_merge_refreshes_labels_keeps_values() -> void:
	var mod = ThermalMod.new()
	var stale := ConfigFile.new()
	stale.set_value("Float", "outline_rim", {"name": "Outline rim", "default": 1.0, "value": 1.7, "minRange": 0.0, "maxRange": 6.0, "step": 0.1, "category": "02. Contour ESP", "menu_pos": 2, "tooltip": "old"})
	stale.set_value("Bool", "thermal_enabled", {"name": "Thermal vision", "default": false, "value": true, "category": "01. ThermalVision", "menu_pos": 4, "tooltip": "old"})
	stale.set_value("Keycode", "key_thermal_toggle", {"name": "Hotkey: Toggle thermal vision", "default": 0, "default_type": "Keycode", "type": "Key", "value": 4194436, "shiftPressed": true, "altPressed": false, "controlPressed": false, "metaPressed": false, "category": "01. ThermalVision", "menu_pos": 0, "tooltip": "old"})
	stale.save(PROFILE_PATH)

	var reg := ConfigFile.new()
	reg.set_value("Float", "outline_rim", {"name": "Rim", "default": 2.0, "value": 2.0, "minRange": 0.0, "maxRange": 6.0, "step": 0.5, "category": "02. ESP", "menu_pos": 2, "tooltip": "new"})
	reg.set_value("Keycode", "key_thermal_toggle", {"name": "Hotkey: Toggle thermal vision", "default": 0, "default_type": "Keycode", "type": "Key", "value": 0, "category": "01. ThermalVision", "menu_pos": 0, "tooltip": "new"})
	mod._sync_config(reg, PROFILE_PATH)

	var out := ConfigFile.new()
	out.load(PROFILE_PATH)
	ck(not out.has_section_key("Bool", "thermal_enabled"), "a removed setting is dropped from the profile")
	ck(out.has_section_key("Float", "outline_rim"), "the renamed setting stays")
	var rim = out.get_value("Float", "outline_rim", {})
	ck(rim.get("name") == "Rim", "the label comes from the code")
	ck(rim.get("category") == "02. ESP", "the category comes from the code")
	ck(rim.get("default") == 2.0, "the default comes from the code")
	ck(rim.get("step") == 0.5, "the step comes from the code")
	ck(rim.get("value") == 1.7, "the player's value survives the merge")
	var kc = out.get_value("Keycode", "key_thermal_toggle", {})
	ck(kc.get("value") == 4194436, "the player's hotkey survives the merge")
	ck(kc.get("shiftPressed") == true, "the player's modifier flags survive the merge")
	mod.free()

class FakeESP extends Node:
	var p_decay: float = 30.0
	var p_dist: float = 60.0
	var p_thickness: float = 0.006
	var p_brightness: float = 0.6
	var p_rim: float = 2.0
	var p_trig: bool = true
	var p_fire_s: float = 5.0
	var p_fire_d: float = 100.0
	var p_voice_s: float = 5.0
	var p_voice_d: float = 20.0
	var p_idle_s: float = 2.0
	var p_idle_d: float = 6.0
	var p_move_s: float = 1.5
	var p_move_d: float = 10.0
	var p_run_d: float = 20.0
	var p_reload_s: float = 2.0
	var p_reload_d: float = 12.0
	var p_pain_s: float = 3.0
	var p_pain_d: float = 15.0
	var p_nade_s: float = 6.0
	var p_nade_d: float = 60.0
	var contour_layer: bool = false
	var xray_layer: bool = false
	var marker_visible: bool = false
	func set_layers(contour: bool, xray: bool) -> void:
		contour_layer = contour
		xray_layer = xray
		marker_visible = contour
	# Mirrors the real module's field map: this is the seam the rewrite left.
	func apply_config(rec: Variant) -> void:
		p_decay = rec.corpse_decay
		p_dist = rec.outline_distance
		p_trig = rec.outline_xray
		p_fire_s = rec.fire_s
		p_fire_d = rec.fire_d
		p_voice_s = rec.voice_s
		p_voice_d = rec.voice_d
		p_idle_s = rec.idle_s
		p_idle_d = rec.idle_d
		p_move_s = rec.move_s
		p_move_d = rec.move_d
		p_run_d = rec.run_d
		p_reload_s = rec.reload_s
		p_reload_d = rec.reload_d
		p_pain_s = rec.pain_s
		p_pain_d = rec.pain_d
		p_nade_s = rec.nade_s
		p_nade_d = rec.nade_d
		p_thickness = rec.outline_thickness
		p_brightness = rec.outline_brightness
		p_rim = rec.outline_rim

class FakeNVG extends Node:
	var set_nvg_noise: float = 10.0
	var set_nvg_white: float = 1.0
	var set_world: float = 1.0
	var set_state_brightness: float = 1.0
	var set_glow_distance: float = 0.0
	var set_mines: bool = true
	var palette_mode: int = 0
	var thermal_on: bool = false
	var mines_on: bool = false
	func apply_config(rec: Variant) -> void:
		set_nvg_noise = rec.nvg_noise
		set_nvg_white = rec.nvg_white
		set_world = rec.world
		set_state_brightness = rec.outline_brightness
		set_glow_distance = rec.outline_distance
		set_mines = rec.thermal_mines
	func set_palette_mode(v: int) -> void:
		palette_mode = v
	func set_thermal_enabled(v: bool) -> void:
		thermal_on = v
	func set_mines_enabled(v: bool) -> void:
		mines_on = v
	func set_state_colors(v: Dictionary) -> void:
		pass
	func nvg_active() -> bool:
		return true

# The mod has to read the file the menu writes, otherwise the settings the
# player set in the menu are gone after a restart.
func t_apply_reads_active_profile() -> void:
	var mod = ThermalMod.new()
	var esp := FakeESP.new()
	var nvg := FakeNVG.new()
	mod._esp = esp
	mod._nvg = nvg
	var profile := ConfigFile.new()
	profile.set_value("Float", "outline_brightness", {"name": "Brightness", "default": 0.6, "value": 1.23, "tooltip": "x"})
	profile.set_value("Float", "outline_rim", {"name": "Rim", "default": 2.0, "value": 3.5, "tooltip": "x"})
	profile.save(PROFILE_PATH)
	mod._config_path = PROFILE_PATH
	mod._mcm_apply(ConfigFile.new())
	ck(esp.p_brightness == 1.23, "the value comes from the active profile")
	ck(esp.p_rim == 3.5, "the rim comes from the active profile")
	ck(esp.p_decay == 90.0, "a missing ESP setting falls back to the registered default")
	ck(nvg.set_glow_distance == 60.0, "a missing NVG setting falls back to the registered default")
	ck(nvg.set_nvg_noise == 0.0, "a missing noise default reaches the NVG side")
	mod.free()
	esp.free()
	nvg.free()

func t_apply_mode_splits_layers() -> void:
	var mod = ThermalMod.new()
	var esp := FakeESP.new()
	var nvg := FakeNVG.new()
	mod._esp = esp
	mod._nvg = nvg
	mod._thermal_enabled = true
	mod._outline_enabled = true
	mod._xray_enabled = true
	mod._apply_mode()
	ck(esp.contour_layer and esp.xray_layer, "both layers follow their toggles")
	mod._outline_enabled = false
	mod._apply_mode()
	ck(not esp.contour_layer and esp.xray_layer, "x-ray survives the contour toggle")
	mod._xray_enabled = false
	mod._apply_mode()
	ck(not esp.contour_layer and not esp.xray_layer, "both toggles off")
	mod.free()
	esp.free()
	nvg.free()