extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const Daylight = preload("res://mods/ThermalVTK/VTKDaylight.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const EspMask = preload("res://mods/ThermalVTK/VTKEspMask.gd")
const SceneProbe = preload("res://mods/ThermalVTK/VTKSceneProbe.gd")

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

# Contour state keys are gone since 2.4.0: the ring writes a category colour
# into the ESP mask viewport (VTKEspMask) and this overlay substitutes the
# display colour from the mask, so no key has to survive the tonemap.

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
var set_strength: float = 1.0
# Live-panel levers (the F9 instrument): probe values, never persisted. The
# defaults ARE the shipped constants, so without the panel the picture does
# not move.
var set_day_target: float = Daylight.TARGET
var set_day_floor: float = Daylight.FLOOR
var set_day_trim: float = Daylight.DAY_TRIM
# Daylight source: 0 folds the game's light state and the measured-frame
# ceiling (hybrid, default), 1 keeps the game's light state only, 2 keeps the
# measured frame only. The flag is a panel choice, not a persisted setting, so
# a reset leaves it alone.
var set_daylight_source: int = 0
var set_frame_level: float = Daylight.DAY_LEVEL
var set_frame_cadence: float = Daylight.FRAME_CADENCE
# Brightness of the state key the ESP outlines emit; the overlay uses it to
# scale the substituted state colour.
var set_state_brightness: float = 0.6

var _state_colors: Dictionary = {}
var _game_data: Resource = null
var _shader: Shader = null
var _nvg_root: Node = null
var _nvg_mat_node: Node = null
var _installed: bool = false
var _install_retry: int = 0

var _mat_mine: StandardMaterial3D = null
# ESP mask viewport: owns the second world pass the contour shells draw into.
# Created here because this module owns the overlay material that samples it.
var _mask: Node = null
# `_esp_on` is the layer switch (armed by ThermalVTK._apply_mode); `_esp_demand`
# is whether a ring is actually on screen this frame. The mask only renders
# when both hold, so an empty map pays nothing for the second world pass.
var _esp_on: bool = false
var _esp_demand: bool = false
var _esp_reach: float = 0.0
var _mask_scale: float = 1.0
var _mask_cadence_int: int = 1
var _mask_counter: int = 0
var _esp_demand_prev: bool = false

var _mines: Dictionary = {}
var _mine_watch: Dictionary = {}
var _dirty: bool = true
var _script_kind: Dictionary = {}
const MINE_RETRY_LIMIT := 50
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
# Source A: the scene level folded from the game's light state (see _snapshot)
# and the RAW factor it produced -- no strength here, strength is applied once
# in _target_factor. _factor_a is kept current under every source so the panel
# can show what source A would give.
var _light_est: float = 0.0
var _factor_a: float = 1.0
# The last measured frame level (raw p50, our compensation included). Kept
# current under every source so the panel can show what the ceiling would give.
var _frame_l: float = 0.0
# Hybrid layer: the night gate (the game culls the sun) and the frame ceiling
# (releases the factor so the uncompensated frame level never drops below
# DAY_LEVEL). `_u` is the uncompensated frame level the panel reads.
var _sun_down: bool = false
var _ceiling: float = 1.0
var _u: float = 0.0
var _probe: Node = null
var _sim_cd: float = 0.0
var _sim_season: int = 1
var _sim_indoor: bool = false
var _sim_shelter: bool = false
# Winter snow trim on the background (see VTKDaylight.snow_trim). Not part of
# the keys: substitution reads the washed pixel before the palette.
var _snow_trim: float = 1.0
# Daylight trim currently applied (see VTKDaylight.day_trim); 1.0 = off.
var _day_trim: float = 1.0
var _vanilla_exposure: float = 3.0
var _last_exposure: float = -1.0
# Process-wide, not per instance: the global lives in RenderingServer, so a
# rebuilt VTKNVG must not add it twice (a second add pushes "Condition
# global_shader_variables.has(p_name) is true"). Static because there is no
# usable existence probe in a shipping build: global_shader_parameter_get_list()
# and global_shader_parameter_get() both log "This function should never be used
# outside the editor" and the get() returns null even for a registered name.
static var _key_gain_registered: bool = false
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

	# The contour's second view. Added as our child so it shares the main tree
	# (and therefore the game's World3D) and dies with the overlay.
	_mask = EspMask.new()
	add_child(_mask)
	_sync_mask()

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
	var kind := _script_kind_for(n)
	if kind == 1 and (_nvg_root == null or not is_instance_valid(_nvg_root)):
		_nvg_root = n
		_try_install_shader()
		if not _installed:
			_install_retry = INSTALL_RETRY_FRAMES
	elif kind == 2:
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
	var kind := _script_kind_for(n)

	if kind == 1:
		_nvg_root = n
		_try_install_shader()
		if not _installed:
			_install_retry = INSTALL_RETRY_FRAMES
		return
	if kind == 2:
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
		_dirty = true
		return
	if mat == null or not (mat is ShaderMaterial):
		_installed = false
		return
	mat.shader = _shader
	_installed = true
	_apply_uniforms()


func _apply_uniforms() -> void:
	_dirty = false
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
	nvg_mat.set_shader_parameter("thermalDarken", set_world * _snow_trim * _day_trim)
	nvg_mat.set_shader_parameter("dayMix", _day_mix)
	nvg_mat.set_shader_parameter("worldPaletteMode", set_palette)
	nvg_mat.set_shader_parameter("highlightKnee", set_highlight_knee)
	nvg_mat.set_shader_parameter("nvgWhite", set_nvg_white)
	nvg_mat.set_shader_parameter("mineKey", DET_MINE)
	_push_mask(nvg_mat)
	# Fallbacks are the VTKStates defaults, not copies: a profile without a
	# colour section and a fresh profile paint the same three colours.
	nvg_mat.set_shader_parameter("stNormalColor", _state_colors.get("state_normal", States.DEFAULT_NORMAL))
	nvg_mat.set_shader_parameter("stCombatColor", _state_colors.get("state_combat", States.DEFAULT_COMBAT))
	nvg_mat.set_shader_parameter("stDefendColor", _state_colors.get("state_defend", States.DEFAULT_DEFEND))
	nvg_mat.set_shader_parameter("stateBright", set_state_brightness)

	nvg_mat.set_shader_parameter("scopeRotate", _scope_rotate)


# The contour asks for the mask through ThermalVTK._apply_mode: this arms the
# layer switch. The per-frame demand below decides whether the pass runs.
func set_esp_mask(on: bool) -> void:
	if _esp_on == on:
		return
	_esp_on = on
	_sync_mask()

# A ring is on screen this frame (ThermalVTK polls VTKESP.wants_mask). Turning
# the mask off here also turns the shader substitution off, so the frozen
# texture from the last rendered frame can never linger on screen.
func set_esp_demand(on: bool) -> void:
	if _esp_demand == on:
		return
	_esp_demand = on
	_sync_mask()

# Longest ring distance; the mask camera clips its world pass there.
func set_esp_reach(distance: float) -> void:
	distance = maxf(distance, 0.0)
	if is_equal_approx(distance, _esp_reach):
		return
	_esp_reach = distance
	if _mask != null and is_instance_valid(_mask):
		_mask.set_reach(_esp_reach)

func set_mask_scale(scale: float) -> void:
	if scale < 0.5:
		scale = 0.5
	if scale > 1.0:
		scale = 1.0
	if is_equal_approx(scale, _mask_scale):
		return
	_mask_scale = scale
	if _mask != null and is_instance_valid(_mask):
		_mask.set_scale(scale)
	_dirty = true

func set_mask_cadence(n: int) -> void:
	if n < 1:
		n = 1
	if n > 4:
		n = 4
	if n == _mask_cadence_int:
		return
	_mask_cadence_int = n

# chord keeping espOn uniform in sync even before the 0.1 s tick.
func _push_esp_on() -> void:
	if _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var mat = _nvg_mat_node.get("material")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("espOn", _esp_render_on())

func _sync_mask() -> void:
	var force_first := _esp_demand and not _esp_demand_prev
	_esp_demand_prev = _esp_demand
	var render: bool = _esp_render_on()
	if render and not force_first:
		render = (_mask_counter % max(_mask_cadence_int, 1) == 0)
	if _mask != null and is_instance_valid(_mask):
		_mask.set_reach(_esp_reach)
		_mask.set_scale(_mask_scale)
		_mask.set_enabled(render)
	_push_esp_on()
	_dirty = true

# The uniform tick is 0.1 s; a demand edge must not wait for it, or the ring
# would blink on the first frames of every NPC.
func _esp_render_on() -> bool:
	return _esp_on and _esp_demand

# Bind the mask texture and its switch. The texture is a ViewportTexture that
# stays valid across frames, so this only runs on a dirty material.
func _push_mask(nvg_mat) -> void:
	nvg_mat.set_shader_parameter("espOn", _esp_render_on())
	if _mask == null or not is_instance_valid(_mask):
		return
	var tex: Texture2D = _mask.texture()
	if tex != null:
		nvg_mat.set_shader_parameter("esp_mask", tex)


func _nvg_active() -> bool:
	if _game_data == null or not _game_data.has_method("get"):
		return false
	return bool(_game_data.get("NVG"))

# Public read for the coordinator (ThermalVTK), which gates the contour ESP on
# the vanilla NVG being worn. See ThermalVTK._process.
func nvg_active() -> bool:
	return _nvg_active()


func _process(delta: float) -> void:
	_mask_counter += 1
	# The mask camera mirrors the picture camera every frame: fov, offsets and
	# transform are what the scope animates, so this is the only place that has
	# to know about the optic. Only while demand says a ring is visible.
	if _esp_render_on() and _mask != null and is_instance_valid(_mask):
		_mask.sync(get_viewport())
	if get_tree().current_scene != _scene_ref:
		_scene_ref = get_tree().current_scene
		_mines.clear()
		_mine_watch.clear()
		_script_kind.clear()
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
		_dirty = true
		if not worn:
			_reset_daylight()
	if worn:
		_daylight_tick(delta)
	_sync_probe()
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

	if _dirty:
		_apply_uniforms()

	_retry_mines()


# Fold the game's own light state into one scalar (see VTKDaylight.estimate_light).
# The only place in the daylight path that reads the tree and the environment:
# everything downstream works on the number. Reads the World node through
# _environment(), which resolves _world; a missing world returns {} and the
# estimate is 0, i.e. vanilla exposure. Object.get() takes exactly one argument,
# so every read is a plain get() with the default spelled out here.
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
	var mat = _world.get("skyMaterial")
	if mat is ShaderMaterial:
		sky_col = (mat as ShaderMaterial).get_shader_parameter("skyColor")
	elif env.sky != null and env.sky.sky_material is ShaderMaterial:
		sky_col = (env.sky.sky_material as ShaderMaterial).get_shader_parameter("skyColor")
	if sky_col is Color:
		snap["sky_color"] = sky_col
	_snapshot_light(snap, "sun", _world.get("sunLight"))
	_snapshot_light(snap, "moon", _world.get("moonLight"))
	return snap


# sun/moon share one shape: colour, energy and cull mask. A culled light has
# mask 0 and is dropped by estimate_light; a missing light contributes nothing.
func _snapshot_light(snap: Dictionary, prefix: String, light) -> void:
	if light == null:
		return
	snap[prefix + "_color"] = light.get("light_color")
	snap[prefix + "_energy"] = light.get("light_energy")
	snap[prefix + "_mask"] = light.get("light_cull_mask")


# Night gate input: the game itself culls the sun (World.TOD sets
# sunLight.light_cull_mask = 0 outside 06:00-18:00 and lights the moon), so the
# mask is exact at dusk and dawn where the TOD bands lag. Maps without a sun
# fall back to "the moon is lit"; with neither light the gate stays silent and
# source A alone decides.
func _compute_sun_down(snap: Dictionary) -> bool:
	if bool(snap.get("sun_present", false)):
		return int(snap.get("sun_mask", 0)) == 0
	return int(snap.get("moon_mask", 0)) != 0


# Recompute source A and the frame ceiling from the cached snapshot and the
# CURRENT smoothed factor. The ceiling is inert without a measurement (probe
# off or nothing read): then it mirrors source A so the readout shows the
# value the picture actually uses.
func _refresh_daylight_state() -> void:
	_factor_a = Daylight.factor_for_light(_light_est, set_day_target, set_day_floor)
	if _frame_l > 0.0:
		_u = _frame_l / maxf(_day_factor, Daylight.EPS)
		_ceiling = Daylight.frame_ceiling(_frame_l, _day_factor, set_frame_level, set_day_floor)
	else:
		_u = 0.0
		_ceiling = _factor_a


# The factor the active source wants, with the night gate and strength applied.
# 0 Hybrid = the looser of source A and the frame ceiling; 1 Game light = A
# only; 2 Measured frame = the ceiling only. At night the gate returns 1.0
# before strength, so all three modes show vanilla.
func _target_factor() -> float:
	var raw := _factor_a
	if set_daylight_source == 2:
		raw = _ceiling
	elif set_daylight_source == 0:
		raw = maxf(_factor_a, _ceiling)
	return Daylight.strength_factor(Daylight.night_gate(raw, _sun_down), set_strength)


# Lazily create the frame probe and wire its signal. The probe is a child of
# this node (which the ThermalVTK autoload parents under its own tree), so it
# survives a map change along with the rest of the mod.
func _ensure_probe() -> Node:
	if _probe != null and is_instance_valid(_probe):
		return _probe
	_probe = SceneProbe.new()
	_probe.measured.connect(_on_probe_measured)
	add_child(_probe)
	return _probe


# One auto measurement landed: it is the input of the frame ceiling. An empty
# dictionary means there was nothing to measure (no camera, no frame), so the
# last frame is kept.
func _on_probe_measured(stats: Dictionary) -> void:
	if stats.is_empty():
		return
	_frame_l = float(stats.get("p50", 0.0))


# Arm the probe only while the ceiling can matter. Game light does not use it,
# and at night the gate throws the ceiling away, so measuring then is a pure
# waste of the GPU sync. The first morning measurement arrives after Probe
# cadence; until then the ceiling is inert and source A runs.
func _sync_probe() -> void:
	var want := set_daylight and set_daylight_source != 1 and not _sun_down and _installed and _nvg_active()
	if not want:
		if _probe != null and is_instance_valid(_probe):
			_probe.set_auto(0.0)
		return
	_ensure_probe().set_auto(set_frame_cadence)


# The F9 panel's Measure button: one synchronous-request measurement of the
# picture camera's frame. Ownership of the probe lives here (see _ensure_probe).
func measure_frame() -> Dictionary:
	var probe := _ensure_probe()
	if probe == null:
		return {}
	return await probe.measure(get_viewport())


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
	_sim_cd -= delta
	if _sim_cd <= 0.0:
		# The season, the indoor flag and the light state do not change between
		# physics ticks: one tree read per 0.25 s is plenty for all of them.
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
	_day_factor = target if _last_exposure < 0.0 else Daylight.step(_day_factor, target, delta)
	_daylight_apply(env, cur)
	_push_daylight_trims(_day_mix)


# The tail of _daylight_tick: whatever factor sits in _day_factor, write the
# exposure, the shader mix and the key gain. Shared with refresh_daylight_now
# so the tick and the panel lever can never compute different things. `cur`
# is the environment exposure as the caller read it before applying. The mix
# lands before the gain so the [DAY] debug line prints the mix the factor
# produced, not the previous step's.
func _daylight_apply(env: Environment, cur: float) -> void:
	var want := _vanilla_exposure * _day_factor
	if absf(want - cur) > 0.002:
		env.tonemap_exposure = want
	_last_exposure = want
	var mix := Daylight.day_mix(_day_factor)
	if absf(mix - _day_mix) > 0.001:
		_day_mix = mix
		_push_day_mix()
	var gain := Daylight.key_gain(_day_factor)
	if absf(gain - _key_gain) > 0.001:
		_set_key_gain(gain)


# Snow and day trims from one place: the tick pushes them with the fresh day
# mix, the panel refresh reuses the same call. Reads the CACHED sim flags --
# the tick refreshes them on the sim cadence before calling here, so this
# adds no tree lookups. `_sim_indoor`/`_sim_shelter` stay cached for the panel
# and the [DAY] line only: the snow trim deliberately ignores them.
func _push_daylight_trims(mix: float) -> void:
	var snow: float = Daylight.snow_trim(_sim_season, mix)
	if absf(snow - _snow_trim) > 0.001:
		_snow_trim = snow
		_dirty = true
	var day: float = Daylight.day_trim(mix, set_day_trim)
	if absf(day - _day_trim) > 0.001:
		_day_trim = day
		_dirty = true


# Live-panel lever: recompute the daylight state and apply it right now,
# skipping the one-pole smoothing, so a dragged slider answers instantly.
# Guards match the tick, plus _nvg_active(): with the helmet off the vanilla
# Deactivate has already restored the exposure, and writing here would
# fight it.
func refresh_daylight_now() -> void:
	if not set_daylight or not _installed or not _nvg_active():
		return
	var env := _environment()
	if env == null:
		return
	_refresh_daylight_state()
	_day_factor = _target_factor()
	_daylight_apply(env, env.tonemap_exposure)
	_push_daylight_trims(_day_mix)
	_dirty = true
	_apply_uniforms()


# Called on NVG off / map change. No environment write: vanilla Deactivate()
# already restores 1.0, and a map change frees the old environment.
func _reset_daylight() -> void:
	_last_exposure = -1.0
	_day_factor = 1.0
	_day_mix = 0.0
	_snow_trim = 1.0
	_day_trim = 1.0
	_light_est = 0.0
	_factor_a = 1.0
	_frame_l = 0.0
	_sun_down = false
	_ceiling = 1.0
	_u = 0.0
	_sim_cd = 0.0
	_sim = null
	_world = null
	_env = null
	# The instrument levers do not survive a helmet-off or a map change: the
	# panel is a measurement tool, not a persisted setting. The source flag is
	# the exception -- it is a deliberate comparison choice, not a probe value.
	set_day_target = Daylight.TARGET
	set_day_floor = Daylight.FLOOR
	set_day_trim = Daylight.DAY_TRIM
	set_frame_level = Daylight.DAY_LEVEL
	set_frame_cadence = Daylight.FRAME_CADENCE
	_set_key_gain(1.0)
	_push_day_mix()
	_dirty = true


# MCM toggle off while NVG is worn: hand the exposure back immediately instead
# of waiting for the next vanilla ResetCheck (up to ~0.17 s of dark picture).
func _restore_exposure() -> void:
	if _last_exposure >= 0.0:
		var env := _environment()
		if env != null and absf(env.tonemap_exposure - _last_exposure) <= 0.004:
			env.tonemap_exposure = _vanilla_exposure
	_reset_daylight()


func _register_key_gain() -> void:
	if not _key_gain_registered:
		RenderingServer.global_shader_parameter_add(KEY_GAIN_PARAM, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, 1.0)
		_key_gain_registered = true
	RenderingServer.global_shader_parameter_set(KEY_GAIN_PARAM, _key_gain)


func _set_key_gain(g: float) -> void:
	if Dbg.enabled and absf(clampf(g, 0.01, 10.0) - _key_gain) > 0.05:
		Dbg.log("DAY", "gain=%.2f strength=%.2f dayMix=%.2f" % [g, set_strength, _day_mix])
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
	if _mines.is_empty():
		return
	var drop: Array = []
	for id in _mines:
		var e = _mines[id]
		if e == null or not is_instance_valid(e.get("node")):
			drop.append(id)
	for id in drop:
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
	# Do not overwrite an existing parked entry: its retry counter has to
	# survive a re-register while the visual is still building.
	if _mine_watch.has(id):
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
		_mine_watch[id] = {"node": node, "tries": 0}
		return
	_mine_watch.erase(id)
	_mines[id] = {"node": node, "meshes": meshes}


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
			_mines[id] = {"node": n, "meshes": meshes}
			drop.append(id)
			continue
		var tries := int(w.get("tries", 0)) + 1
		w["tries"] = tries
		if tries >= MINE_RETRY_LIMIT:
			drop.append(id)
	for id in drop:
		_mine_watch.erase(id)


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
	_dirty = true
	_tick_cd = 0.0


# MCM snapshot in, settings out. Headless-safe: every setter here is a var
# write, and _apply_uniforms guards against the missing tree.
func apply_config(rec) -> void:
	var was_daylight := set_daylight
	set_daylight = rec.daylight_compensation
	if was_daylight and not set_daylight:
		_restore_exposure()
	# The daylight strength slider used to be declared in MCM and read into
	# the record but never mapped here, so it sat dead.
	set_strength = rec.daylight_strength
	set_nvg_noise = rec.nvg_noise
	set_nvg_white = rec.nvg_white
	set_world = rec.world
	set_highlight_knee = rec.highlight_knee
	set_state_brightness = rec.outline_brightness
	set_glow_distance = rec.outline_distance
	set_mines = rec.thermal_mines
	set_state_colors(rec.state_colors())
	_dirty = true
	_tick_cd = 0.0


func set_mines_enabled(on: bool) -> void:
	set_mines = on
	_tick_cd = 0.0


func set_state_colors(colors: Dictionary) -> void:
	_state_colors = colors
	_dirty = true


func set_palette_mode(mode: int) -> void:
	set_palette = mode
	_dirty = true
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
