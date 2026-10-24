extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const Daylight = preload("res://mods/ThermalVTK/VTKDaylight.gd")

# Owns the NVG overlay shader, plus the thermal/mines layer that rides on it.
#
# Architecture (ported from the ThermalVision reference mod):
#   1. Our own shader REPLACES the vanilla one on the NVG ColorRect. Because
#      vanilla only ever calls set_shader_parameter("tint", ...) on that same
#      ShaderMaterial, plain green NVG keeps working untouched -- we only get
#      a "noise" uniform we can actually drive (vanilla's own shader declares
#      noise as a `const`, which is why BetterNVG's set_shader_parameter
#      calls there did nothing).
#   2. Mines carry a fixed emissive "key" colour and are painted by
#      material_override, so the whole on-screen shell IS the key pixel. The
#      contour's state-key ring (normal/combat/defend) is a
#      separate unshaded layer owned by VTKOutline.
#   3. The shader samples the screen, finds whichever key is nearest, and
#      substitutes a display color. Everything else goes through the
#      false-color thermal palette.
#
# Detection is event-driven (SceneTree.node_added) rather than a full scene
# walk, and per-entity work is only a reference swap between pre-built
# materials -- no shader or material allocation after startup.

const GAME_DATA_RES := Paths.GAME_DATA
const NVG_SCRIPT_SUFFIX := "NVG.gd"
const SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const KEY_GAIN_PARAM := &"vtk_key_gain"

# Сколько кадров подряд пробовать поставить шейдер, если NVG-узел уже найден,
# но его Overlay ещё не готов (ванильный _ready ждёт ~0.1 c). ~60 кадров.
const INSTALL_RETRY_FRAMES := 60

const TICK := 0.1

# Detector key for mines. Fixed by design and kept in lockstep with the
# shader's mineKey uniform and the unshaded overlay material that emits it.
const MINE_KEY := Color(0.0, 0.0, 1.0)

# Detection target, NOT the emitted key. The vanilla NVG WorldEnvironment
# (glow + tonemap) desaturates the unshaded key colour toward white BEFORE the
# frame reaches our screen shader, so matching the raw key always misses.
# This is the measured post-NVG value for the emitted mine key (calibration
# band, F8 / F9 screenshot): mine (0,0,1)->(0.50,0.06,0.94). The material still
# EMITS the raw key; only the detector compares against it.
const DET_MINE := Color(0.50, 0.06, 0.94)

# Contour state keys (emitted by VTKStates.KEY_*; these are the measured post-NVG
# values from the F7 ring probe). The unshaded ring is thin, so its on-screen
# colour is the key blended with the background by glow/tonemap -- matching the
# raw keys misses. Probe averages (motion-gated, 3 runs): normal (1,0,0)->
# (1.00,0.21,0.16), combat (0,1,1)->(0.82,1.00,1.00), defend (1,0,1)->
# (1.00,0.34,1.00). The ring still EMITS the raw keys; only the detector
# compares against these.
const DET_ST_NORMAL := Color(1.00, 0.21, 0.16)
const DET_ST_COMBAT := Color(0.82, 1.00, 1.00)
const DET_ST_DEFEND := Color(1.00, 0.34, 1.00)

# Fill / nomad detector targets. The nomad value was calibrated in-game
# against the vanilla NVG palette (a probe measured the raw nomad key after the
# wash). It is the measured post-NVG colour of KEY_NOMAD in VTKStates.gd, so the
# nomad detector cannot sit inside another key's radius.
const DET_NOMAD := Color(0.580, 0.973, 0.584)

# settings
var set_nvg_noise: float = 0.0
var set_nvg_white: float = 1.0
var set_thermal: bool = false
var set_mines: bool = true
# Mirrors the MCM outline distance; gates mine glow.
var set_glow_distance: float = 60.0
var set_palette: int = 0
var set_world: float = 1.70
# Daylight highlight rolloff knee (shader "highlightKnee"); 1.0 = off.
var set_highlight_knee: float = 0.6
var set_daylight: bool = true
# Brightness of the state key the ESP outlines emit; the overlay uses it to
# scale the substituted state colour.
var set_state_brightness: float = 0.6
# Display colour of the friendly-nomad marker.
var set_nomad_color: Color = Color(0.30, 1.0, 0.35)
var _state_colors: Dictionary = {}
var _game_data: Resource = null
var _shader: Shader = null
var _nvg_root: Node = null
var _nvg_mat_node: Node = null
var _installed: bool = false
var _install_retry: int = 0

var _mat_mine: StandardMaterial3D = null

var _mines: Dictionary = {}
var _mine_watch: Dictionary = {}
var _pending: Array[int] = []
var _tick_cd: float = 0.0
var _scene_ref: Node = null
# прошлое значение on, нужно ровно для перехода on->off (снять покраску один раз).
var _was_on: bool = false
# PIP off + magnifying scope rotates colour channels, so the overlay detector
# matches a key's orbit; pushed only on change (see _process).
var _scope_rotate: bool = false

# Daylight compensation. `_last_exposure` is the value WE last wrote; if the
# environment reads something else, the vanilla ResetCheck has written it and
# that value becomes the new vanilla baseline.
var _day_factor: float = 1.0
var _day_mix: float = 0.0
var _key_gain: float = 1.0
# Winter snow trim on the background (see VTKDaylight.snow_trim). Not part of
# the keys: substitution reads the washed pixel before the palette.
var _snow_trim: float = 1.0
var _vanilla_exposure: float = 3.0
var _last_exposure: float = -1.0
var _key_gain_registered: bool = false
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

	# Key materials emit the detector pixels. Mines use a plain
	# unshaded+emission StandardMaterial3D.
	_mat_mine = _key_material(MINE_KEY)
	_register_key_gain()

	get_tree().node_added.connect(_on_node_added)
	_scene_ref = get_tree().current_scene
	_reseed(get_tree().current_scene)


# A single diamond quad reads as a glyph. Billboarded via the material, so the
# exact winding does not matter (cull is disabled anyway).
func _reseed(scene: Node) -> void:
	if scene == null:
		return
	_scan_node(scene)


func _scan_node(n: Node) -> void:
	if n == null:
		return
	var s = n.get_script()
	var path: String = "" if s == null else String(s.resource_path)
	if path.ends_with(NVG_SCRIPT_SUFFIX) and (_nvg_root == null or not is_instance_valid(_nvg_root)):
		_nvg_root = n
		_try_install_shader()
		if not _installed:
			_install_retry = INSTALL_RETRY_FRAMES
	elif path.ends_with("Mine.gd"):
		_register_mine(n)
	for c in n.get_children():
		_scan_node(c)


func _key_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.0
	return m


# Repaint an existing key material. Must mirror _key_material exactly, otherwise
# the emitted pixel stops matching the shader key and the category disappears.
# The daylight gain lives here too: the key is scaled BEFORE the tonemap, and
# the reduced exposure divides it back, so the detector sees the same pixel.
func _key_set(m: StandardMaterial3D, c: Color) -> void:
	if m == null:
		return
	m.albedo_color = Color(c.r * _key_gain, c.g * _key_gain, c.b * _key_gain, c.a)
	m.emission = c
	m.emission_energy_multiplier = _key_gain


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
	var s = n.get_script()
	var path: String = "" if s == null else String(s.resource_path)

	if path.ends_with(NVG_SCRIPT_SUFFIX):
		_nvg_root = n
		_try_install_shader()
		if not _installed:
			_install_retry = INSTALL_RETRY_FRAMES
		return
	if path.ends_with("Mine.gd"):
		_register_mine(n)
		return


# The shader lives on a ColorRect under the NVG node's "Overlay" child. Vanilla
# captures exactly that ShaderMaterial in its own _ready() and only ever calls
# set_shader_parameter("tint", ...) on it -- so swapping .shader here keeps
# plain NVG working while giving us a drivable "noise" uniform.
func _try_install_shader() -> void:
	# /root/Map пересобирается на каждой смене карты: пропатченный NVG-узел
	# освобождается, а на его месте появляется новый с ванильным шейдером.
	# Ловим это событием (node_added / _reseed), а не проверкой каждого кадра;
	# если Overlay ещё не готов (await-based _ready) — ограниченный ретрай.
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
		return
	if mat == null or not (mat is ShaderMaterial):
		_installed = false
		return
	mat.shader = _shader
	_installed = true
	_apply_uniforms()


func _apply_uniforms() -> void:
	# The key materials are what actually emit the detector's key pixels on
	# screen, pinned to the key constants.
	#
	# Kept ahead of the _installed check on purpose -- if this were gated on the
	# shader being live, the two sides could desync during startup.
	_key_set(_mat_mine, MINE_KEY)
	if not _installed or _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var nvg_mat = _nvg_mat_node.get("material")
	if nvg_mat == null or not (nvg_mat is ShaderMaterial):
		return
	nvg_mat.set_shader_parameter("noise", set_nvg_noise)
	nvg_mat.set_shader_parameter("thermalMode", set_thermal and _nvg_active())
	nvg_mat.set_shader_parameter("thermalDarken", set_world * _snow_trim)
	nvg_mat.set_shader_parameter("dayMix", _day_mix)
	nvg_mat.set_shader_parameter("worldPaletteMode", set_palette)
	nvg_mat.set_shader_parameter("highlightKnee", set_highlight_knee)
	nvg_mat.set_shader_parameter("nvgWhite", set_nvg_white)
	nvg_mat.set_shader_parameter("mineKey", DET_MINE)
	nvg_mat.set_shader_parameter("stNormalKey", DET_ST_NORMAL)
	nvg_mat.set_shader_parameter("stCombatKey", DET_ST_COMBAT)
	nvg_mat.set_shader_parameter("stDefendKey", DET_ST_DEFEND)
	nvg_mat.set_shader_parameter("stNormalColor", _state_colors.get("state_normal", Color(1.0, 0.72, 0.28)))
	nvg_mat.set_shader_parameter("stCombatColor", _state_colors.get("state_combat", Color(0.95, 0.18, 0.15)))
	nvg_mat.set_shader_parameter("stDefendColor", _state_colors.get("state_defend", Color(0.62, 0.30, 0.95)))
	nvg_mat.set_shader_parameter("stateBright", set_state_brightness)
	nvg_mat.set_shader_parameter("nomadKey", DET_NOMAD)
	nvg_mat.set_shader_parameter("nomadColor", set_nomad_color)
	nvg_mat.set_shader_parameter("scopeRotate", _scope_rotate)


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
		_mines.clear()
		_mine_watch.clear()
		_nvg_root = null
		_installed = false
		_install_retry = 0
		_reseed(_scene_ref)
		_tick_cd = 0.0
		_reset_daylight()
	# Ограниченный ретрай: NVG-узел найден, но ванильный await-based _ready ещё
	# не создал Overlay/материал. Ставим шейдер только по событию обнаружения,
	# с коротким добором кадров, а не проверкой каждый кадр.
	if _install_retry > 0:
		_install_retry -= 1
		_try_install_shader()
		if _installed:
			_install_retry = 0
	var worn := _nvg_active()
	var on := set_thermal and worn
	# PIP off + aiming a magnifying scope is the only path that rotates colour
	# channels; flag the overlay then so it matches whole key orbits. Cache and
	# push on change only: _apply_uniforms is not called per frame.
	var want := false
	if _game_data != null and _game_data.has_method("get"):
		want = bool(_game_data.get("isScoped"))
		if want:
			var pip = _game_data.get("PIP")
			if pip == null or bool(pip):
				want = false
	if want != _scope_rotate:
		_scope_rotate = want
		if _installed and _nvg_mat_node != null and is_instance_valid(_nvg_mat_node):
			var sm = _nvg_mat_node.get("material")
			if sm is ShaderMaterial:
				(sm as ShaderMaterial).set_shader_parameter("scopeRotate", _scope_rotate)
	if worn != _was_worn:
		_was_worn = worn
		if not worn:
			_reset_daylight()
	if worn:
		_daylight_tick(delta)
	# Player position, fetched once per frame.
	var ppos := _player_pos()

	if on:
		for id in _mines.keys():
			_update_mine(id, true, ppos)
	elif _was_on:
		_clear_paint()
	_was_on = on

	if not on:
		# Покой при off: только дешёвый присмотр (см. _off_frame_upkeep).
		_off_frame_upkeep()

	if _tick_cd > 0.0:
		_tick_cd -= delta
		return
	_tick_cd = TICK

	_apply_uniforms()

	_retry_mines()


# Write the compensated exposure every frame. The vanilla ResetCheck runs in
# _physics_process and re-applies the device power on its own cadence; _process
# runs after physics, so this value is the one the frame is rendered with.
func _daylight_tick(delta: float) -> void:
	if not set_daylight or not _installed:
		return
	var env := _environment()
	if env == null:
		return
	var cur := env.tonemap_exposure
	if _last_exposure < 0.0 or absf(cur - _last_exposure) > 0.002:
		# The vanilla NVG only ever writes 2.0/2.5/3.0 while worn. A 1.0 here
		# means its _ready has not run Activate() yet (save load): keep the
		# last baseline instead of dropping the exposure for one frame.
		if cur >= 1.9:
			_vanilla_exposure = cur
	var light := Daylight.light_level(
		float(_sim_value("time", 1200.0)),
		String(_sim_value("weather", "Neutral")),
		int(_sim_value("season", 1)),
		_game_flag("indoor"),
		_game_flag("shelter"))
	var target := Daylight.day_factor(light)
	_day_factor = target if _last_exposure < 0.0 else Daylight.step(_day_factor, target, delta)
	var want := _vanilla_exposure * _day_factor
	if absf(want - cur) > 0.002:
		env.tonemap_exposure = want
	_last_exposure = want
	var gain := Daylight.key_gain(_day_factor)
	if absf(gain - _key_gain) > 0.001:
		_set_key_gain(gain)
	var mix := Daylight.day_mix(_day_factor)
	if absf(mix - _day_mix) > 0.001:
		_day_mix = mix
		_push_day_mix()
	var trim: float = Daylight.snow_trim(int(_sim_value("season", 1)), _game_flag("indoor"), _game_flag("shelter"), light)
	if absf(trim - _snow_trim) > 0.001:
		_snow_trim = trim
		_apply_uniforms()


# Called on NVG off / map change. No environment write: vanilla Deactivate()
# already restores 1.0, and a map change frees the old environment.
func _reset_daylight() -> void:
	_last_exposure = -1.0
	_day_factor = 1.0
	_day_mix = 0.0
	_snow_trim = 1.0
	_sim = null
	_world = null
	_env = null
	_set_key_gain(1.0)
	_push_day_mix()


# MCM toggle off while NVG is worn: hand the exposure back immediately instead
# of waiting for the next vanilla ResetCheck (up to ~0.17 s of dark picture).
func _restore_exposure() -> void:
	if _last_exposure >= 0.0:
		var env := _environment()
		if env != null and absf(env.tonemap_exposure - _last_exposure) <= 0.004:
			env.tonemap_exposure = _vanilla_exposure
	_reset_daylight()


func _register_key_gain() -> void:
	var names := RenderingServer.global_shader_parameter_get_list()
	if not names.has(KEY_GAIN_PARAM):
		RenderingServer.global_shader_parameter_add(KEY_GAIN_PARAM, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
	_key_gain_registered = true
	RenderingServer.global_shader_parameter_set(KEY_GAIN_PARAM, _key_gain)


func _set_key_gain(g: float) -> void:
	_key_gain = clampf(g, 0.01, 10.0)
	_key_set(_mat_mine, MINE_KEY)
	if _key_gain_registered:
		RenderingServer.global_shader_parameter_set(KEY_GAIN_PARAM, _key_gain)


func _push_day_mix() -> void:
	if not _installed or _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var mat = _nvg_mat_node.get("material")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("dayMix", _day_mix)


# The vanilla script reaches the environment through Map/World.environment.
# Resolve it lazily and re-read the resource pointer: a map change may replace
# it while the World node itself survives.
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


func _game_flag(name: String) -> bool:
	if _game_data == null or not _game_data.has_method("get"):
		return false
	return bool(_game_data.get(name))


# Покой при выключенном тепловизоре. Регистрация (node_added) продолжает идти
# и при off, поэтому мёртвые записи мин всё равно надо чистить, иначе _mines рос бы
# без границы.
func _off_frame_upkeep() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null or not is_instance_valid(e.get("node")):
			_mines.erase(id)


# Снимает покраску на переходе on->off ровно один раз: material_override в null
# на меши мин. Дальше кадр при off мешей не обходит вовсе.
func _clear_paint() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null:
			continue
		e["painted"] = false
		for m in e.get("meshes", []):
			if is_instance_valid(m):
				(m as GeometryInstance3D).material_override = null


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
	# The visual usually lives under an exported "mine" Node3D, but not every
	# mine has one -- fall back to the node itself so those still get picked up.
	# The exported "mine" points at the INNER detail (the tiny orange piece that
	# pops out on detonation), NOT the visible shell: a mine node holds LOD0/LOD1
	# (the shell you actually see) plus Mine (interior) plus Area. Sweeping from
	# the exported property alone highlighted only the interior, so the shell
	# stayed invisible while still being the thing you want spotted. So we always
	# sweep the whole mine node: that covers the shell LODs and the interior, and
	# the Area3D is skipped automatically because it isn't geometry.
	var visual: Node = node
	var meshes: Array = []
	_collect_meshes(visual, meshes)
	if meshes.is_empty():
		# A freshly spawned mine can still be building its visual (own _ready, a
		# timer, an async load), so an empty sweep is not proof there is nothing
		# to paint. Park it and retry on later ticks instead of dropping it.
		_mine_watch[id] = node
		return
	_mine_watch.erase(id)
	_mines[id] = {"node": node, "meshes": meshes}


func _retry_mines() -> void:
	if _mine_watch.is_empty():
		return
	for id in _mine_watch.keys():
		var n = _mine_watch[id]
		if not is_instance_valid(n):
			_mine_watch.erase(id)
			continue
		_register_mine(n)


func _collect_meshes(node: Node, out: Array) -> void:
	# GeometryInstance3D rather than MeshInstance3D: some visuals are MultiMesh
	# or CSG, and material_override lives on the base class.
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect_meshes(child, out)


func _update_mine(id: int, thermal_on: bool, ppos: Vector3) -> void:
	var e = _mines.get(id)
	if e == null:
		return
	if not is_instance_valid(e["node"]):
		_mines.erase(id)
		return
	# Mines read as scenery past the shared outline distance.
	var node = e["node"]
	var dist := ppos.distance_to(node.global_position)
	var show := thermal_on and set_mines and dist <= maxf(set_glow_distance, 1.0)
	# material_override writes mark the instance dirty every frame. The paint
	# only changes on a range crossing, so skip the write while it holds.
	if bool(e.get("painted", false)) == show:
		return
	e["painted"] = show
	for mesh in e["meshes"]:
		if is_instance_valid(mesh):
			mesh.material_override = _mat_mine if show else null


func set_thermal_enabled(on: bool) -> void:
	set_thermal = on
	_apply_uniforms()
	_tick_cd = 0.0


# MCM snapshot in, settings out. Headless-safe: every setter here is a var
# write, and _apply_uniforms guards against the missing tree.
func apply_config(rec) -> void:
	var was_daylight := set_daylight
	set_daylight = rec.daylight_compensation
	if was_daylight and not set_daylight:
		_restore_exposure()
	set_nvg_noise = rec.nvg_noise
	set_nvg_white = rec.nvg_white
	set_world = rec.world
	set_highlight_knee = rec.highlight_knee
	set_state_brightness = rec.outline_brightness
	set_glow_distance = rec.outline_distance
	set_mines = rec.thermal_mines
	set_state_colors(rec.state_colors())
	_apply_uniforms()
	_tick_cd = 0.0


func set_mines_enabled(on: bool) -> void:
	set_mines = on
	_tick_cd = 0.0


func set_state_colors(colors: Dictionary) -> void:
	_state_colors = colors
	_apply_uniforms()


func set_palette_mode(mode: int) -> void:
	set_palette = mode
	_apply_uniforms()
	_tick_cd = 0.0


# Hide the NVG overlay for a single frame. The overlay paints the thermal
# palette (or the green tint) over the whole frame, so a screen readback of a
# key pixel shows the painted colour, not the scene colour the key detector
# compares against. Hiding the rect leaves the raw scene visible.
func set_overlay_visible(v: bool) -> void:
	if _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	if _nvg_mat_node is CanvasItem:
		(_nvg_mat_node as CanvasItem).visible = v