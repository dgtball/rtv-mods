extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const Daylight = preload("res://mods/ThermalVTK/VTKDaylight.gd")
const Palettes = preload("res://mods/ThermalVTK/VTKPalettes.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const SceneProbe = preload("res://mods/ThermalVTK/VTKSceneProbe.gd")
const PaletteQuad = preload("res://mods/ThermalVTK/VTKPaletteQuad.gd")
const Shaders = preload("res://mods/ThermalVTK/VTKShaders.gd")

# Owns the NVG overlay shader, the world palette quad and mine highlighting.
#
# The palette is a spatial fullscreen quad in the main 3D view, drawn before
# optics, contours and mine shells so they keep their own colours. The NVG
# canvas shader only carries the vanilla tint, noise and goggle mask. Mines are
# highlighted with main-view shell meshes carrying the configured display colour;
# contours are handled by VTKOutline/VTKESP in the same view.

const GAME_DATA_RES := Paths.GAME_DATA
const NVG_SCRIPT_SUFFIX := "NVG.gd"
const SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"

const TICK := 0.1

# settings
var set_nvg_noise: float = 0.0
var set_nvg_white: float = 1.0
var set_thermal: bool = false
var set_mines: bool = true
# Mirrors the MCM outline distance; gates mine glow.
var set_glow_distance: float = Settings.OUTLINE_DISTANCE
var set_palette: int = 0
var set_world: float = 1.70
# Daylight highlight rolloff knee (shader "inputKnee"); 1.0 = off.
var set_highlight_knee: float = 0.55
var set_daylight: bool = true
var set_strength: float = 1.0
# Live-panel levers (the F9 instrument): probe values, never persisted. The
# defaults ARE the shipped constants, so without the panel the picture does
# not move.
var set_day_target: float = Daylight.TARGET
var set_day_floor: float = Daylight.FLOOR
var set_day_trim: float = Daylight.DAY_TRIM
# Time acceleration of the day/night cycle (F9 "Time scale" lever; testing).
var set_time_scale: float = 1.0
# Direct display colour of mine shells (MCM "Mine" colour).
var _mine_color: Color = States.DEFAULT_MINE
var _game_data: Resource = null
var _shader: Shader = null
var _nvg_root: Node = null
var _nvg_mat_node: Node = null
var _installed: bool = false
var _quad = null

var _mat_mine: StandardMaterial3D = null
var _mat_mine_scoped: ShaderMaterial = null
var _current_mine_material: Material = null
var _mine_scoped: bool = false

var _mines: Dictionary = {}
var _mine_watch: Dictionary = {}
var _mine_painted: int = 0
var _dirty: bool = true
var _script_kind: Dictionary = {}
const MINE_RETRY_LIMIT := 50
var _pending: Array[int] = []
var _tick_cd: float = 0.0
var _scene_ref: Node = null
# прошлое значение on, нужно ровно для перехода on->off (снять покраску один раз).
var _was_on: bool = false

# Daylight compensation is read-only: the vanilla exposure tier is folded into
# _input_gain, never written back to Environment. The game owns that value.
var _day_factor: float = 1.0
var _day_seeded: bool = false
var _day_mix: float = 0.0
# The single number the shader multiplies the frame by before the shoulder.
var _input_gain: float = 1.7
# Scene level folded from the game's light state (see _snapshot) and the raw
# factor it produces; strength is applied once in _target_factor.
var _light_est: float = 0.0
var _factor_a: float = 1.0
# Night gate: when the game culls the sun the vanilla picture is handed back.
var _sun_down: bool = false
var _sim_cd: float = 0.0
var _sim_season: int = 1
var _sim_indoor: bool = false
var _sim_shelter: bool = false
# Winter snow trim on the background (see VTKDaylight.snow_trim).
var _snow_trim: float = 1.0
# Daylight trim currently applied (see VTKDaylight.day_trim); 1.0 = off.
var _day_trim: float = 1.0
var _was_worn: bool = false
var _sim: Node = null
var _world: Node = null
var _env: Environment = null


func _ready() -> void:
	name = "VTKNVG"
	if ResourceLoader.exists(GAME_DATA_RES):
		_game_data = load(GAME_DATA_RES)

	# Shader lives in its own .gdshader file (packed by pack.ps1). load() is
	# runtime, so a missing file leaves _shader null and _try_install_shader
	# simply refuses to patch anything instead of silently breaking vanilla NVG.
	if ResourceLoader.exists(SHADER_RES):
		_shader = load(SHADER_RES) as Shader

	# Direct mine display material for main-view shells. Scoped non-PIP optics
	# swap to a flat shader that crosses the vanilla Mask but still respects
	# opaque depth; both materials are built once and only swapped per state.
	_mat_mine = _mine_display_material(_mine_color)
	_mat_mine_scoped = _scoped_mine_material(_mine_color)
	_current_mine_material = _mat_mine

	# The quad node stays ours; only its mesh is parented to the live camera.
	_quad = PaletteQuad.new()
	add_child(_quad)
	_attach_quad()

	get_tree().node_added.connect(_on_node_added)
	_scene_ref = get_tree().current_scene
	_reseed(get_tree().current_scene)


func _reseed(scene: Node) -> void:
	if scene == null:
		return
	_attach_quad()
	_scan_node(scene)


# The camera is recreated on every map load. Reattach lazily: when no camera is
# current yet the old mesh goes with its parent and attach() rebuilds it.
func _attach_quad() -> void:
	if _quad == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam != null:
		_quad.attach(cam)


func _scan_node(n: Node) -> void:
	if n == null:
		return
	var kind := _script_kind_for(n)
	if kind == 1 and (_nvg_root == null or not is_instance_valid(_nvg_root)):
		_nvg_root = n
		_try_install_shader()
	elif kind == 2:
		_register_mine(n)
	for c in n.get_children():
		_scan_node(c)


func _mine_display_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, 1.0)
	m.emission_enabled = false
	# Transparent queue (priority 20) draws after the full-screen palette quad
	# (-128); the depth test stays on so walls still occlude mine shells.
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.render_priority = 20
	return m


func _scoped_mine_material(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shaders.mine_scoped()
	m.set_shader_parameter("mine_color", Color(c.r, c.g, c.b, 1.0))
	m.render_priority = 20
	return m


func _refresh_mine_material() -> void:
	if _mat_mine == null:
		_mat_mine = _mine_display_material(_mine_color)
	_mat_mine.albedo_color = Color(_mine_color.r, _mine_color.g, _mine_color.b, 1.0)
	if _mat_mine_scoped != null:
		_mat_mine_scoped.set_shader_parameter("mine_color", Color(_mine_color.r, _mine_color.g, _mine_color.b, 1.0))


func _on_node_added(node: Node) -> void:
	# Батчим: загрузчик за кадр добавляет целые поддеревья, и call_deferred на
	# каждый узел — это отдельный instance_from_id + script lookup. Копим id,
	# разбираем одним проходом в начале своего _process.
	_pending.append(node.get_instance_id())


func _drain_pending() -> void:
	if _pending.is_empty():
		return
	for id in _pending:
		_deferred_check(id)
	_pending.clear()


func _deferred_check(node_id: int) -> void:
	var n := instance_from_id(node_id)
	if n == null or not is_instance_valid(n) or not n.is_inside_tree():
		return
	var kind := _script_kind_for(n)

	if kind == 1:
		_nvg_root = n
		_try_install_shader()
		return
	if kind == 2:
		_register_mine(n)
		return
	# Ванильный NVG._ready асинхронный: Overlay и его ColorRect добавляются
	# после самого узла NVG и приходят тем же node_added. Любой новый узел под
	# найденным NVG-корнем — это и есть момент добрать установку; кадрового
	# бюджета больше нет.
	if not _installed and _nvg_root != null and is_instance_valid(_nvg_root) and _nvg_root.is_ancestor_of(n):
		_try_install_shader()


# The shader lives on a ColorRect under the NVG node's "Overlay" child. Vanilla
# captures exactly that ShaderMaterial in its own _ready() and only ever calls
# set_shader_parameter("tint", ...) on it -- so swapping .shader here keeps
# plain NVG working while giving us drivable uniforms.
func _try_install_shader() -> void:
	# /root/Map пересобирается на каждой смене карты: пропатченный NVG-узел
	# освобождается, а на его месте появляется новый с ванильным шейдером.
	# Ловим это событием (node_added / _reseed), а не проверкой каждого кадра;
	# если Overlay ещё не готов (await-based _ready), добор придёт следующим
	# node_added под NVG-корнем (см. _deferred_check).
	if _shader == null:
		_installed = false
		return
	if _nvg_root == null or not is_instance_valid(_nvg_root):
		_nvg_root = get_node_or_null(Paths.NVG)
	if _nvg_root == null or not is_instance_valid(_nvg_root):
		_installed = false
		return
	var overlay = _nvg_root.get_node_or_null("Overlay")
	if overlay == null or overlay.get_child_count() == 0:
		_installed = false
		return
	var target = overlay.get_child(0)
	if not ("material" in target):
		_installed = false
		return
	# Remember the rect even when the material is not ours: the debug probe
	# hides it to read the raw scene under the overlay.
	_nvg_mat_node = target
	var mat = target.get("material")
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == _shader:
		_installed = true
		_dirty = true
		return
	if mat == null or not (mat is ShaderMaterial):
		_installed = false
		return
	mat.shader = _shader
	_installed = true
	_apply_uniforms()


func _apply_uniforms() -> void:
	_refresh_input_gain()
	_dirty = false
	_refresh_mine_material()
	# The quad is independent of the canvas material: push its uniforms before
	# the overlay guards, otherwise a missing ColorRect would freeze the palette
	# while the F8/F9 panels are still changing it.
	if _quad != null:
		_quad.apply(Palettes.stops(set_palette), Palettes.output(), _input_gain, lerpf(1.0, set_highlight_knee, _day_mix))
	if not _installed or _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		if _nvg_mat_node != null and not is_instance_valid(_nvg_mat_node):
			_nvg_mat_node = null
			_installed = false
		return
	var nvg_mat = _nvg_mat_node.get("material")
	if nvg_mat == null or not (nvg_mat is ShaderMaterial):
		_installed = false
		return
	var thermal_on := set_thermal and _nvg_active()
	nvg_mat.set_shader_parameter("noise", set_nvg_noise)
	nvg_mat.set_shader_parameter("thermalMode", thermal_on)
	nvg_mat.set_shader_parameter("nvgWhite", set_nvg_white)
	# All palette math moved to the spatial quad; the canvas pass keeps only
	# the vanilla tint, noise, goggle mask and final NVG brightness.


# One number feeds the palette: world brightness, the day/snow trims, the
# smoothed day factor and the vanilla exposure tier read back from the game.
# The mod never writes Environment.tonemap_exposure.
func _refresh_input_gain() -> void:
	var env := _environment()
	var exposure := Daylight.EXPOSURE_REF
	if env != null:
		exposure = env.tonemap_exposure
	var base := set_world * _snow_trim * _day_trim * Daylight.exposure_norm(exposure)
	# FLOOR/DAY_TRIM/SNOW_TRIM stay on their canvas-era calibration; only the
	# quad's linear-stage level trim is different. Strength 0 (or daylight off)
	# hands the vanilla gain back without a first-frame re-seed.
	var strength := set_strength if set_daylight else 0.0
	var gain := Daylight.quad_gain(base, _light_est, _sun_down, set_day_target, Daylight.QUAD_FLOOR, strength)
	if absf(gain - _input_gain) > 0.0005:
		_input_gain = gain
		_dirty = true


# Direct display colour of mine shells. Stored even before the overlay material
# is installed.
func set_mine_color(c: Color) -> void:
	_mine_color = c
	_refresh_mine_material()

func mine_color() -> Color:
	return _mine_color


# Scoped optics without PIP swap already painted mines to the flat, depth-aware
# shader. PIP and normal view keep the plain transparent shell. Only a state
# change touches the overlays; no counters or materials are recreated.
func set_scope_view(scoped: bool, pip: bool) -> void:
	var want: bool = scoped and not pip
	if want == _mine_scoped:
		return
	_mine_scoped = want
	_current_mine_material = _mat_mine_scoped if want else _mat_mine
	if _current_mine_material == null:
		_current_mine_material = _mat_mine
	for id in _mines.keys():
		var e = _mines.get(id)
		if e != null and bool(e.get("painted", false)):
			_apply_mine_paint(e, true)


func _nvg_active() -> bool:
	if _game_data == null or not _game_data.has_method("get"):
		return false
	return bool(_game_data.get("NVG"))

# Public read for the coordinator (ThermalVTK), which gates the contour ESP on
# the vanilla NVG being worn. See ThermalVTK._process.
func nvg_active() -> bool:
	return _nvg_active()


func _process(delta: float) -> void:
	_drain_pending()
	if get_tree().current_scene != _scene_ref:
		_scene_ref = get_tree().current_scene
		_clear_mine_state()
		_script_kind.clear()
		_nvg_root = null
		_installed = false
		_reseed(_scene_ref)
		_tick_cd = 0.0
		_reset_daylight()
	_attach_quad()
	var worn := _nvg_active()
	var on := set_thermal and worn
	if _quad != null:
		_quad.set_enabled(on)
	if worn != _was_worn:
		_was_worn = worn
		_dirty = true
		if not worn:
			# NVG overlay can be torn down by the game on unequip; avoid touching
			# it. The daylight state stays warm: re-seeding here made the first
			# frame after putting the helmet back on flash, then cut the heat.
			if _nvg_mat_node != null and not is_instance_valid(_nvg_mat_node):
				_nvg_mat_node = null
				_installed = false
	if worn:
		_daylight_tick(delta)
	# Two plain flag reads decide which shared mine material painted shells use.
	set_scope_view(_game_flag("isScoped"), _game_flag("PIP"))
	# Player position, fetched once per frame.
	var ppos := _player_pos()

	if on:
		for id in _mines.keys():
			_update_mine(id, true, ppos)
	elif _was_on:
		_clear_paint()
	_was_on = on

	if not on:
		_off_frame_upkeep()

	if _tick_cd > 0.0:
		_tick_cd -= delta
		return
	_tick_cd = TICK

	if _dirty:
		_apply_uniforms()

	_retry_mines()


func _snapshot() -> Dictionary:
	var env := _environment()
	if env == null or _world == null:
		return {}
	var snap := {
		"ambient_color": env.ambient_light_color,
		"ambient_energy": env.ambient_light_energy,
		"background_energy": env.background_energy_multiplier,
		"fog_density": env.volumetric_fog_density,
		"fog_emission": env.volumetric_fog_emission,
		"shelter": bool(_world.get("shelter")),
		"intro": bool(_world.get("intro")),
		"sun_present": _world.get("sunLight") != null,
	}
	# Sky colour: the World keeps its own ShaderMaterial, but a scene without
	# one falls back to the environment sky. env.sky is null on maps that set
	# no Sky at all -- guard it, or the readback crashes at runtime.
	var sky_col: Variant = null
	var sky_overcast: Variant = null
	var mat = _world.get("skyMaterial")
	if mat is ShaderMaterial:
		sky_col = (mat as ShaderMaterial).get_shader_parameter("skyColor")
		sky_overcast = (mat as ShaderMaterial).get_shader_parameter("overcast")
	elif env.sky != null and env.sky.sky_material is ShaderMaterial:
		sky_col = (env.sky.sky_material as ShaderMaterial).get_shader_parameter("skyColor")
		sky_overcast = (env.sky.sky_material as ShaderMaterial).get_shader_parameter("overcast")
	if sky_col is Color:
		snap["sky_color"] = sky_col
	if sky_overcast != null:
		snap["overcast"] = float(sky_overcast)
	_snapshot_light(snap, "sun", _world.get("sunLight"))
	_snapshot_light(snap, "moon", _world.get("moonLight"))
	return snap


func _snapshot_light(snap: Dictionary, prefix: String, light) -> void:
	if light == null:
		return
	snap[prefix + "_color"] = light.get("light_color")
	snap[prefix + "_energy"] = light.get("light_energy")
	snap[prefix + "_mask"] = light.get("light_cull_mask")


func _compute_sun_down(snap: Dictionary) -> bool:
	if bool(snap.get("sun_present", false)):
		return int(snap.get("sun_mask", 0)) == 0
	return int(snap.get("moon_mask", 0)) != 0


func _refresh_daylight_state() -> void:
	_factor_a = Daylight.factor_for_light(_light_est, set_day_target, set_day_floor)


func _target_factor() -> float:
	return Daylight.strength_factor(Daylight.night_gate(_factor_a, _sun_down), set_strength)


const SIM_MINUTES_PER_REAL_SEC := 1.0 / 6.0


func _sim_time_node() -> Node:
	return get_node_or_null(Paths.SIMULATION)


static func hhmm_to_minutes(t: float) -> float:
	return floorf(t / 100.0) * 60.0 + fmod(floorf(t), 100.0) + fmod(t, 1.0)


static func minutes_to_hhmm(total: float) -> Dictionary:
	var day_inc := 0
	while total >= 1440.0:
		total -= 1440.0
		day_inc += 1
	while total < 0.0:
		total += 1440.0
		day_inc -= 1
	var h := int(floorf(total / 60.0))
	var m := total - float(h * 60)
	return {"time": float(h * 100) + m, "day_inc": day_inc}


func _apply_time_scale(delta: float) -> void:
	Engine.time_scale = 1.0
	var scale := clampf(set_time_scale, 0.0, 10.0)
	if not set_daylight or not _installed or not _nvg_active() or delta <= 0.0:
		return
	var sim := _sim_time_node()
	if sim == null or not is_instance_valid(sim):
		return
	if scale <= 0.0:
		if not has_meta("_vtk_time_frozen"):
			set_meta("_vtk_time_frozen", true)
			set_meta("_vtk_frozen_time", sim.get("time"))
			set_meta("_vtk_frozen_day", sim.get("day"))
		sim.set("time", get_meta("_vtk_frozen_time"))
		sim.set("day", get_meta("_vtk_frozen_day"))
		return
	if has_meta("_vtk_time_frozen"):
		remove_meta("_vtk_time_frozen")
		remove_meta("_vtk_frozen_time")
		remove_meta("_vtk_frozen_day")
	if scale <= 1.0:
		return
	var extra := (scale - 1.0) * SIM_MINUTES_PER_REAL_SEC * delta
	var total := hhmm_to_minutes(float(sim.get("time"))) + extra
	var conv: Dictionary = minutes_to_hhmm(total)
	sim.set("time", conv["time"])
	var day_inc: int = int(conv.get("day_inc", 0))
	if day_inc != 0:
		sim.set("day", int(sim.get("day")) + day_inc)


# The F9 Measure button owns the probe now; there is no auto cadence and no
# signal back into the daylight model. SceneProbe names itself in _ready, so
# the child lookup keeps one probe per NVG without a cached field.
func _ensure_probe() -> Node:
	var existing := get_node_or_null("VTKSceneProbe")
	if existing != null and is_instance_valid(existing):
		return existing
	var probe := SceneProbe.new()
	add_child(probe)
	return probe


func measure_frame() -> Dictionary:
	var probe := _ensure_probe()
	if probe == null:
		return {}
	return await probe.measure(get_viewport())


func _daylight_tick(delta: float) -> void:
	_apply_time_scale(delta)
	if not set_daylight or not _installed:
		_refresh_input_gain()
		return
	if _environment() == null:
		_refresh_input_gain()
		return
	_sim_cd -= delta
	if _sim_cd <= 0.0:
		_sim_cd = 0.25
		_sim_season = int(_sim_value("season", 1))
		_sim_indoor = _game_flag("indoor")
		var snap := _snapshot()
		_sim_shelter = bool(snap.get("shelter", false))
		_light_est = Daylight.estimate_light(snap)
		var was_down := _sun_down
		_sun_down = _compute_sun_down(snap)
		if _sun_down != was_down:
			Dbg.log("DAY", "sunDown=%d E=%.3f indoor=%d" % [1 if _sun_down else 0, _light_est, 1 if _sim_indoor else 0])
	_refresh_daylight_state()
	var target := _target_factor()
	_day_factor = target if not _day_seeded else Daylight.step(_day_factor, target, delta)
	_day_seeded = true
	_day_mix = Daylight.day_mix(_day_factor)
	_push_daylight_trims(_day_mix)
	_refresh_input_gain()


func _push_daylight_trims(mix: float) -> void:
	var snow: float = Daylight.snow_trim(_sim_season, mix, Daylight.SNOW_TRIM_NIGHT, Daylight.SNOW_TRIM_DAY, _day_factor)
	if absf(snow - _snow_trim) > 0.001:
		_snow_trim = snow
		_dirty = true
	var day: float = Daylight.day_trim(mix, set_day_trim)
	if absf(day - _day_trim) > 0.001:
		_day_trim = day
		_dirty = true


func refresh_daylight_now() -> void:
	Engine.time_scale = 1.0
	if not set_daylight or not _installed or not _nvg_active():
		return
	var env := _environment()
	if env == null:
		return
	_refresh_daylight_state()
	_day_factor = _target_factor()
	_day_seeded = true
	_day_mix = Daylight.day_mix(_day_factor)
	_push_daylight_trims(_day_mix)
	_refresh_input_gain()
	_dirty = true
	_apply_uniforms()


func _reset_daylight() -> void:
	_day_factor = 1.0
	_day_seeded = false
	_day_mix = 0.0
	_snow_trim = 1.0
	_day_trim = 1.0
	_light_est = 0.0
	_factor_a = 1.0
	_sun_down = false
	_sim_cd = 0.0
	_sim = null
	_world = null
	_env = null
	set_day_target = Daylight.TARGET
	set_day_floor = Daylight.FLOOR
	set_day_trim = Daylight.DAY_TRIM
	set_time_scale = 1.0
	Engine.time_scale = 1.0
	if has_meta("_vtk_time_frozen"):
		remove_meta("_vtk_time_frozen")
		remove_meta("_vtk_frozen_time")
		remove_meta("_vtk_frozen_day")
	_refresh_input_gain()
	_dirty = true


func _environment() -> Environment:
	if _world == null or not is_instance_valid(_world):
		_world = get_node_or_null(Paths.WORLD)
	if _world == null:
		_env = null
		return null
	var we = _world.get("environment")
	if we == null:
		we = _world.get_node_or_null("WorldEnvironment")
	if we == null:
		_env = null
		return null
	var env = we.get("environment")
	if env == null and we is Environment:
		env = we
	_env = env as Environment
	return _env


func _sim_value(key: String, fallback) -> Variant:
	if _sim == null or not is_instance_valid(_sim):
		_sim = get_node_or_null(Paths.SIMULATION)
	if _sim == null:
		return fallback
	var v = _sim.get(key)
	return fallback if v == null else v


func debug_sim_state() -> Dictionary:
	var sim := _sim_time_node()
	var out := {
		"time": -1.0,
		"day": -1,
		"season": int(_sim_season),
	}
	if sim != null and is_instance_valid(sim):
		var t = sim.get("time")
		if t != null:
			out["time"] = float(t)
		var d = sim.get("day")
		if d != null:
			out["day"] = int(d)
		var s = sim.get("season")
		if s != null:
			out["season"] = int(s)
	var weather := {}
	var probes := ["weather", "currentWeather", "weatherState", "overcast", "fog", "rain", "snow", "precipitation", "storm", "wind", "clouds"]
	for src in [sim, _world]:
		if src == null or not is_instance_valid(src):
			continue
		for key in probes:
			if weather.has(key):
				continue
			var v = src.get(key)
			if v == null:
				continue
			if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME]:
				weather[key] = v
	out["weather"] = weather
	return out


func _game_flag(name: String) -> bool:
	if _game_data == null or not _game_data.has_method("get"):
		return false
	return bool(_game_data.get(name))


func _off_frame_upkeep() -> void:
	if _mines.is_empty():
		return
	var drop: Array = []
	for id in _mines:
		var e = _mines[id]
		if e == null or not is_instance_valid(e.get("node")):
			drop.append(id)
	for id in drop:
		_remove_mine(id)


func _clear_paint() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null:
			continue
		_set_mine_painted(e, false)
	_mine_painted = 0


func _player_pos() -> Vector3:
	if _game_data != null:
		var p = _game_data.get("playerPosition")
		if p != null:
			return p
	return Vector3.ZERO


func _register_mine(node: Node) -> void:
	var id := node.get_instance_id()
	if _mines.has(id):
		return
	# Do not overwrite an existing parked entry: its retry counter has to
	# survive a re-register while the visual is still building.
	if _mine_watch.has(id):
		return
	# Always sweep the whole mine node: that covers the shell LODs and the
	# interior, and the Area3D is skipped automatically because it isn't
	# geometry.
	var meshes: Array = []
	_collect_meshes(node, meshes)
	if meshes.is_empty():
		_mine_watch[id] = {"node": node, "tries": 0}
		return
	_mine_watch.erase(id)
	_mines[id] = _build_mine_entry(node, meshes)


func _retry_mines() -> void:
	if _mine_watch.is_empty():
		return
	var drop: Array = []
	for id in _mine_watch:
		var w: Dictionary = _mine_watch[id]
		var n = w.get("node")
		if n == null or not is_instance_valid(n):
			drop.append(id)
			continue
		var meshes: Array = []
		_collect_meshes(n, meshes)
		if not meshes.is_empty():
			_mines[id] = _build_mine_entry(n, meshes)
			drop.append(id)
			continue
		var tries := int(w.get("tries", 0)) + 1
		w["tries"] = tries
		if tries >= MINE_RETRY_LIMIT:
			drop.append(id)
	for id in drop:
		_mine_watch.erase(id)


func _build_mine_entry(node: Node, meshes: Array) -> Dictionary:
	var entry := {"node": node, "meshes": meshes, "painted": false}
	_clear_source_overrides(entry)
	return entry


func _clear_source_overrides(e: Dictionary) -> void:
	for m in e.get("meshes", []):
		if m == null or not is_instance_valid(m):
			continue
		var gi := m as GeometryInstance3D
		if gi == null:
			continue
		gi.material_overlay = null
		gi.material_override = null


func _set_mine_painted(entry: Dictionary, show: bool) -> void:
	if bool(entry.get("painted", false)) == show:
		return
	entry["painted"] = show
	if show:
		_mine_painted += 1
	else:
		_mine_painted = maxi(_mine_painted - 1, 0)
	_apply_mine_paint(entry, show)


func _apply_mine_paint(entry: Dictionary, show: bool) -> void:
	for m in entry.get("meshes", []):
		if m == null or not is_instance_valid(m):
			continue
		var gi := m as GeometryInstance3D
		if gi == null:
			continue
		gi.material_overlay = (_current_mine_material if _current_mine_material != null else _mat_mine) if show else null


func _remove_mine(id: int) -> void:
	var e = _mines.get(id)
	if e != null:
		if bool(e.get("painted", false)):
			_mine_painted = maxi(_mine_painted - 1, 0)
		_clear_source_overrides(e)
	_mines.erase(id)


func _clear_mine_state() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null:
			continue
		_clear_source_overrides(e)
	_mines.clear()
	_mine_watch.clear()
	_mine_painted = 0


func _script_kind_for(n: Node) -> int:
	var s = n.get_script()
	if s == null:
		return 0
	var sid: int = s.get_instance_id()
	var cached = _script_kind.get(sid)
	if cached != null:
		return int(cached)
	var path := String(s.resource_path)
	var kind := 0
	if path.ends_with(NVG_SCRIPT_SUFFIX):
		kind = 1
	elif path.ends_with("Mine.gd"):
		kind = 2
	_script_kind[sid] = kind
	return kind

func _collect_meshes(node: Node, out: Array) -> void:
	# GeometryInstance3D rather than MeshInstance3D: some visuals are MultiMesh
	# or CSG. Shell rendering uses MeshInstance3D copies; sources stay clean.
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _update_mine(id: int, thermal_on: bool, ppos: Vector3) -> void:
	var e = _mines.get(id)
	if e == null:
		return
	if not is_instance_valid(e["node"]):
		_remove_mine(id)
		return
	# Mines read as scenery past the shared outline distance.
	var node = e["node"]
	var dist := ppos.distance_to(node.global_position)
	var show := thermal_on and set_mines and dist <= maxf(set_glow_distance, 1.0)
	_set_mine_painted(e, show)


func set_thermal_enabled(on: bool) -> void:
	var was_on := set_thermal
	set_thermal = on
	if was_on and not on:
		_clear_paint()
		_was_on = false
	_dirty = true
	_tick_cd = 0.0


# MCM snapshot in, settings out. Headless-safe: every setter here is a var
# write, and _apply_uniforms guards against the missing tree.
func apply_config(rec) -> void:
	set_daylight = rec.daylight_compensation
	set_strength = rec.daylight_strength
	set_nvg_noise = rec.nvg_noise
	set_nvg_white = rec.nvg_white
	set_world = rec.world
	set_highlight_knee = rec.highlight_knee
	set_glow_distance = rec.outline_distance
	set_mines = rec.thermal_mines
	set_mine_color(rec.color_mine)
	_dirty = true
	_tick_cd = 0.0


func set_palette_mode(mode: int) -> void:
	set_palette = posmod(mode, 4)
	_dirty = true
	_tick_cd = 0.0


func _exit_tree() -> void:
	_clear_mine_state()
