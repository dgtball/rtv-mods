extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")
const Settings = preload("res://mods/ThermalVTK/VTKSettings.gd")
const Daylight = preload("res://mods/ThermalVTK/VTKDaylight.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")
const Dbg = preload("res://mods/ThermalVTK/VTKDebug.gd")
const SceneProbe = preload("res://mods/ThermalVTK/VTKSceneProbe.gd")

# Owns the NVG overlay shader, contour ESP key substitution (transitional), and
# mine ESP buffer rendering.
#
# Contour ESP visuals currently emit fixed detection keys in the 3D pass; the
# NVG shader detects washed keys in screen space and substitutes display colours.
# Mine ESP renders as direct-colour shell meshes into the shared NVG ESP buffer
# (layer 20) and is composited over the palettized background, never as a
# key-substitution material_override on source meshes.

const GAME_DATA_RES := Paths.GAME_DATA
const NVG_SCRIPT_SUFFIX := "NVG.gd"
const SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const KEY_GAIN_PARAM := &"vtk_key_gain"

const TICK := 0.1
const ESP_BUFFER_LAYER := 20
const ESP_BUFFER_LAYER_BIT := 1 << 19
const MINE_SHELL_META := "vtk_mine_shell"
const NO_CONTOUR_META := "vtk_no_contour"

# Legacy mine detector key/uniform values kept for transitional shader/runtime
# compatibility (mine rendering no longer emits/substitutes this key).
const MINE_KEY := Color(0.0, 0.0, 1.0)
const DET_MINE := Color(0.50, 0.06, 0.94)
# Detection targets, NOT the emitted keys. The vanilla NVG world processing
# washes bright keys before the screen shader sees them.
const DET_ST_NORMAL := Color(1.00, 0.21, 0.16)
const DET_ST_COMBAT := Color(0.82, 1.00, 1.00)
const DET_ST_DEFEND := Color(1.00, 0.34, 1.00)

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
var set_highlight_knee: float = 0.55
var set_daylight: bool = true
var set_strength: float = 1.0
# Live-panel levers (the F9 instrument): probe values, never persisted. The
# defaults ARE the shipped constants, so without the panel the picture does
# not move.
var set_day_target: float = Daylight.TARGET
var set_day_floor: float = Daylight.FLOOR
var set_day_trim: float = Daylight.DAY_TRIM
var set_frame_level: float = Daylight.DAY_LEVEL
var set_frame_cadence: float = Daylight.FRAME_CADENCE
# Time acceleration of the day/night cycle (F9 "Time scale" lever; testing).
var set_time_scale: float = 1.0
# Brightness of ESP state display colours in NVG substitution.
var set_state_brightness: float = 0.6
var set_esp_fill_alpha: float = 0.6
var set_esp_body_fill: bool = true
var set_vrcets_strength: float = 0.58
var set_vrcets_red_hold: float = 0.72

var _state_colors: Dictionary = {}
# Direct display colour of mine ESP buffer shells (MCM "Mine" colour).
var _mine_color: Color = States.DEFAULT_MINE
var _game_data: Resource = null
var _shader: Shader = null
var _nvg_root: Node = null
var _nvg_mat_node: Node = null
var _installed: bool = false

var _mat_mine: StandardMaterial3D = null
# `_esp_on` is the layer switch (armed by ThermalVTK._apply_mode through
# set_esp_layer); `_esp_demand` is whether a contour is actually on screen this
# frame (ThermalVTK pushes it from VTKESP.wants_contour). The shader substitutes
# when both hold.
var _esp_on: bool = false
var _esp_demand: bool = false

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
# PIP off + magnifying scope rotates colour channels, so the overlay detector
# matches a key's orbit; pushed only on change (see _process).
var _scope_rotate: bool = false

# ESP buffer pass (NVG-on compositor): a shared-world SubViewport rendered by a
# layer-20-only camera and composited over the palettized background.
var _esp_vp: SubViewport = null
var _esp_cam: Camera3D = null
var _esp_env: Environment = null
var _esp_main_cam: Camera3D = null
var _esp_main_cam_mask: int = 0
var _esp_main_cam_mask_saved: bool = false

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
var _probe_interval: float = Daylight.FRAME_CADENCE
var _frame_l_prev: float = 0.0
var _probe_stable: int = 0
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
# rebuilt VTKNVG must not add it twice. Static because there is no usable
# existence probe in a shipping build.
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

	# Direct mine display material for ESP buffer shells (no key emission).
	_mat_mine = _mine_display_material(_mine_color)
	_register_key_gain()

	get_tree().node_added.connect(_on_node_added)
	_scene_ref = get_tree().current_scene
	_reseed(get_tree().current_scene)


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


func _mine_display_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = false
	return m


func _refresh_mine_material() -> void:
	if _mat_mine == null:
		_mat_mine = _mine_display_material(_mine_color)
		return
	_mat_mine.albedo_color = _mine_color


# The global is a render-global uniform: every shader that declares
# `global uniform float vtk_key_gain` reads this value without a per-frame
# push from GDScript. Registered once per process.
func _register_key_gain() -> void:
	if _key_gain_registered:
		RenderingServer.global_shader_parameter_set("vtk_key_gain", _key_gain)
		return
	_key_gain_registered = true
	RenderingServer.global_shader_parameter_add("vtk_key_gain", RenderingServer.GLOBAL_VAR_TYPE_FLOAT, _key_gain)


func _push_key_gain() -> void:
	var gain := Daylight.key_gain(_day_factor)
	if is_equal_approx(gain, _key_gain):
		return
	_key_gain = gain
	RenderingServer.global_shader_parameter_set("vtk_key_gain", _key_gain)
	Dbg.log("DAY", "key_gain=%.3f factor=%.3f exp=%.3f" % [_key_gain, _day_factor, _last_exposure])


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
# plain NVG working while giving us a drivable "noise" uniform.
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
	_dirty = false
	_refresh_mine_material()
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
	nvg_mat.set_shader_parameter("vrcetsStrength", set_vrcets_strength)
	nvg_mat.set_shader_parameter("vrcetsRedHold", set_vrcets_red_hold)
	nvg_mat.set_shader_parameter("mineKey", DET_MINE)
	_push_esp_on()
	nvg_mat.set_shader_parameter("stNormalColor", _state_colors.get("state_normal", States.DEFAULT_NORMAL))
	nvg_mat.set_shader_parameter("stCombatColor", _state_colors.get("state_combat", States.DEFAULT_COMBAT))
	nvg_mat.set_shader_parameter("stDefendColor", _state_colors.get("state_defend", States.DEFAULT_DEFEND))
	nvg_mat.set_shader_parameter("mineColor", _mine_color)
	nvg_mat.set_shader_parameter("stateBright", set_state_brightness)
	nvg_mat.set_shader_parameter("stNormalKey", DET_ST_NORMAL)
	nvg_mat.set_shader_parameter("stCombatKey", DET_ST_COMBAT)
	nvg_mat.set_shader_parameter("stDefendKey", DET_ST_DEFEND)
	nvg_mat.set_shader_parameter("espFillAlpha", set_esp_fill_alpha)
	nvg_mat.set_shader_parameter("espBodyFill", set_esp_body_fill)
	nvg_mat.set_shader_parameter("scopeRotate", _scope_rotate)
	_push_esp_composite()


# Direct display colour of mine ESP buffer shells. Stored even before the
# overlay material is installed and applied to the shared mine shell material.
func set_mine_color(c: Color) -> void:
	_mine_color = c
	_refresh_mine_material()
	if _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var mat = _nvg_mat_node.get("material")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("mineColor", _mine_color)

func mine_color() -> Color:
	return _mine_color

# The contour asks for the screen through ThermalVTK._apply_mode: this arms the
# layer switch. The per-frame demand below decides whether the substitution runs.
func set_esp_layer(on: bool) -> void:
	if _esp_on == on:
		return
	_esp_on = on
	_push_esp_on()

# A contour is on screen this frame (ThermalVTK polls VTKESP.wants_contour). Turning
# the layer off here also turns the shader substitution off, so the last frame
# can never linger on screen.
func set_esp_demand(on: bool) -> void:
	if _esp_demand == on:
		return
	_esp_demand = on
	_push_esp_on()

func _push_esp_on() -> void:
	if _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var mat = _nvg_mat_node.get("material")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("espOn", _esp_render_on())
	_push_esp_composite()


func set_state_colors(colors: Dictionary) -> void:
	_state_colors = colors
	_dirty = true

func set_esp_brightness(v: float) -> void:
	if is_equal_approx(set_state_brightness, v):
		return
	set_state_brightness = v
	_dirty = true


func set_esp_fill(alpha: float, body_fill: bool) -> void:
	var a := clampf(alpha, 0.0, 1.0)
	if is_equal_approx(set_esp_fill_alpha, a) and set_esp_body_fill == body_fill:
		return
	set_esp_fill_alpha = a
	set_esp_body_fill = body_fill
	_dirty = true


func esp_buffer_layer() -> int:
	return ESP_BUFFER_LAYER

func esp_composite_active() -> bool:
	return _esp_render_on() or _mine_buffer_wanted()

func esp_buffer_viewport() -> SubViewport:
	return _esp_vp

func _esp_render_on() -> bool:
	return _esp_on and _esp_demand

func _mine_buffer_wanted() -> bool:
	return set_thermal and _nvg_active() and set_mines

func _ensure_esp_buffer() -> bool:
	if _esp_vp != null and is_instance_valid(_esp_vp):
		return true
	if not is_inside_tree():
		return false
	var main: Viewport = get_viewport()
	if main == null:
		return false
	_esp_vp = SubViewport.new()
	_esp_vp.name = "VTKESPBuffer"
	_esp_vp.own_world_3d = false
	_esp_vp.world_3d = main.world_3d
	_esp_vp.transparent_bg = true
	_esp_vp.handle_input_locally = false
	_esp_vp.msaa_3d = Viewport.MSAA_DISABLED
	_esp_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_esp_vp.use_taa = false
	_esp_vp.use_debanding = false
	_esp_vp.positional_shadow_atlas_size = 0
	_esp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_esp_vp.size = main.size
	add_child(_esp_vp)

	_esp_env = Environment.new()
	_esp_env.background_mode = Environment.BG_CLEAR_COLOR
	_esp_env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	_esp_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_esp_env.ambient_light_color = Color(0.0, 0.0, 0.0, 1.0)
	_esp_env.ambient_light_energy = 0.0
	_esp_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_esp_env.tonemap_exposure = 1.0
	_esp_env.tonemap_white = 1.0
	_esp_env.glow_enabled = false
	_esp_env.fog_enabled = false
	_esp_env.volumetric_fog_enabled = false
	_esp_env.adjustment_enabled = false

	_esp_cam = Camera3D.new()
	_esp_cam.name = "VTKESPCamera"
	_esp_cam.cull_mask = ESP_BUFFER_LAYER_BIT
	_esp_cam.environment = _esp_env
	_esp_vp.add_child(_esp_cam)
	_esp_cam.current = true
	return true

func _restore_main_cam_mask() -> void:
	if _esp_main_cam_mask_saved and _esp_main_cam != null and is_instance_valid(_esp_main_cam):
		_esp_main_cam.cull_mask = _esp_main_cam_mask
	_esp_main_cam = null
	_esp_main_cam_mask = 0
	_esp_main_cam_mask_saved = false

func _sync_esp_buffer(active: bool) -> void:
	if not active:
		if _esp_vp != null and is_instance_valid(_esp_vp):
			_esp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_restore_main_cam_mask()
		return
	if not _ensure_esp_buffer():
		_restore_main_cam_mask()
		return
	var main: Viewport = get_viewport()
	var cam: Camera3D = null if main == null else main.get_camera_3d()
	if main == null or cam == null:
		_esp_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_restore_main_cam_mask()
		return
	if _esp_vp.size != main.size and main.size.x > 0 and main.size.y > 0:
		_esp_vp.size = main.size
	_esp_vp.world_3d = main.world_3d
	_esp_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_esp_cam.global_transform = cam.global_transform
	_esp_cam.projection = cam.projection
	_esp_cam.fov = cam.fov
	_esp_cam.size = cam.size
	_esp_cam.near = cam.near
	_esp_cam.far = cam.far
	_esp_cam.keep_aspect = cam.keep_aspect
	_esp_cam.h_offset = cam.h_offset
	_esp_cam.v_offset = cam.v_offset
	_esp_cam.frustum_offset = cam.frustum_offset
	_esp_cam.cull_mask = ESP_BUFFER_LAYER_BIT
	if _esp_main_cam != cam:
		_restore_main_cam_mask()
		_esp_main_cam = cam
		_esp_main_cam_mask = cam.cull_mask
		_esp_main_cam_mask_saved = true
	else:
		var want := _esp_main_cam_mask & ~ESP_BUFFER_LAYER_BIT
		if cam.cull_mask != want:
			# External code changed the camera mask while compositing: adopt the
			# new mask as the restorable state, but keep layer 20 excluded.
			_esp_main_cam_mask = cam.cull_mask
	cam.cull_mask = _esp_main_cam_mask & ~ESP_BUFFER_LAYER_BIT

func _push_esp_composite() -> void:
	if _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var mat = _nvg_mat_node.get("material")
	if not (mat is ShaderMaterial):
		return
	var sm := mat as ShaderMaterial
	var active := esp_composite_active() and _installed
	_sync_esp_buffer(active)
	sm.set_shader_parameter("espComposite", active and _esp_vp != null and is_instance_valid(_esp_vp))
	if active and _esp_vp != null and is_instance_valid(_esp_vp):
		sm.set_shader_parameter("espTex", _esp_vp.get_texture())


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
		_restore_main_cam_mask()
		_reseed(_scene_ref)
		_tick_cd = 0.0
		_reset_daylight()
	var worn := _nvg_active()
	var on := set_thermal and worn
	# PIP off + aiming a magnifying scope is the only path that rotates colour
	# channels; flag the overlay then so it matches whole key orbits.
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
	_push_esp_composite()
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
	if _frame_l > 0.0:
		_u = _frame_l / maxf(_day_factor, Daylight.EPS)
		_ceiling = Daylight.frame_ceiling(_frame_l, _day_factor, set_frame_level, set_day_floor)
	else:
		_u = 0.0
		_ceiling = _factor_a


func _target_factor() -> float:
	var raw := maxf(_factor_a, _ceiling)
	return Daylight.strength_factor(Daylight.night_gate(raw, _sun_down), set_strength)


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


func _ensure_probe() -> Node:
	if _probe != null and is_instance_valid(_probe):
		return _probe
	_probe = SceneProbe.new()
	_probe.measured.connect(_on_probe_measured)
	add_child(_probe)
	return _probe


func _on_probe_measured(stats: Dictionary) -> void:
	if stats.is_empty():
		return
	var measured := float(stats.get("p50", 0.0))
	_frame_l = measured
	_adapt_probe(measured)


func _adapt_probe(measured: float) -> void:
	if _frame_l_prev <= 0.0 or absf(measured - _frame_l_prev) > Daylight.PROBE_STABLE_TOL:
		_probe_stable = 1
		_probe_interval = set_frame_cadence
	else:
		_probe_stable += 1
	if _probe_stable >= Daylight.PROBE_STABLE_FRAMES:
		_probe_interval = Daylight.adaptive_interval(set_frame_cadence, _probe_stable, _probe_interval)
		_probe_stable = 0
	_frame_l_prev = measured


func _sync_probe() -> void:
	var want := set_daylight and set_thermal and not _sun_down and _installed and _nvg_active()
	if not want:
		if _probe != null and is_instance_valid(_probe):
			_probe.set_auto(0.0)
		return
	_ensure_probe().set_auto(_probe_interval)


func measure_frame() -> Dictionary:
	var probe := _ensure_probe()
	if probe == null:
		return {}
	return await probe.measure(get_viewport())


func _daylight_tick(delta: float) -> void:
	_apply_time_scale(delta)
	if not set_daylight or not _installed:
		return
	var env := _environment()
	if env == null:
		return
	var cur := env.tonemap_exposure
	if _last_exposure < 0.0 or absf(cur - _last_exposure) > 0.002:
		if cur >= 1.9:
			_vanilla_exposure = cur
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
	_day_factor = target if _last_exposure < 0.0 else Daylight.step(_day_factor, target, delta)
	_daylight_apply(env, cur)
	_push_daylight_trims(_day_mix)


func _daylight_apply(env: Environment, cur: float) -> void:
	var want := _vanilla_exposure * _day_factor
	if absf(want - cur) > 0.002:
		env.tonemap_exposure = want
	_last_exposure = want
	_push_key_gain()
	var mix := Daylight.day_mix(_day_factor)
	if absf(mix - _day_mix) > 0.001:
		_day_mix = mix
		_push_day_mix()


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
	_daylight_apply(env, env.tonemap_exposure)
	_push_daylight_trims(_day_mix)
	_dirty = true
	_apply_uniforms()


func _reset_daylight() -> void:
	_last_exposure = -1.0
	_day_factor = 1.0
	_day_mix = 0.0
	_snow_trim = 1.0
	_day_trim = 1.0
	_light_est = 0.0
	_factor_a = 1.0
	_frame_l = 0.0
	_probe_interval = Daylight.FRAME_CADENCE
	_probe_stable = 0
	_frame_l_prev = 0.0
	_sun_down = false
	_ceiling = 1.0
	_u = 0.0
	_sim_cd = 0.0
	_sim = null
	_world = null
	_env = null
	set_day_target = Daylight.TARGET
	set_day_floor = Daylight.FLOOR
	set_day_trim = Daylight.DAY_TRIM
	set_frame_level = Daylight.DAY_LEVEL
	set_frame_cadence = Daylight.FRAME_CADENCE
	set_time_scale = 1.0
	Engine.time_scale = 1.0
	if has_meta("_vtk_time_frozen"):
		remove_meta("_vtk_time_frozen")
		remove_meta("_vtk_frozen_time")
		remove_meta("_vtk_frozen_day")
	_day_factor = 1.0
	_key_gain = 1.0
	RenderingServer.global_shader_parameter_set("vtk_key_gain", _key_gain)
	_push_day_mix()
	_dirty = true


func _restore_exposure() -> void:
	if _last_exposure >= 0.0:
		var env := _environment()
		if env != null and absf(env.tonemap_exposure - _last_exposure) <= 0.004:
			env.tonemap_exposure = _vanilla_exposure
	_reset_daylight()


func _push_day_mix() -> void:
	if not _installed or _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	var mat = _nvg_mat_node.get("material")
	if mat is ShaderMaterial:
		(mat as ShaderMaterial).set_shader_parameter("dayMix", _day_mix)


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
		_clear_source_overrides(e)
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
	var entry := {"node": node, "meshes": meshes, "shells": [], "painted": false}
	_clear_source_overrides(entry)
	_rebuild_mine_shells(entry)
	return entry


func _clear_source_overrides(e: Dictionary) -> void:
	for m in e.get("meshes", []):
		if is_instance_valid(m):
			(m as GeometryInstance3D).material_override = null


func _mine_shells(entry: Dictionary) -> Array:
	var s = entry.get("shells", [])
	return s if s is Array else []


func _sync_mine_shell(shell: MeshInstance3D, src: MeshInstance3D) -> void:
	if not is_instance_valid(src) or not src.is_inside_tree():
		return
	if not is_instance_valid(shell) or not shell.is_inside_tree():
		return
	shell.global_transform = src.global_transform
	shell.visible = src.visible
	shell.layers = ESP_BUFFER_LAYER_BIT


func _make_mine_shell(src: MeshInstance3D) -> MeshInstance3D:
	var shell := MeshInstance3D.new()
	shell.set_meta(NO_CONTOUR_META, true)
	shell.set_meta(MINE_SHELL_META, true)
	shell.top_level = true
	shell.mesh = src.mesh
	shell.skin = src.skin
	shell.skeleton = src.skeleton
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.material_override = _mat_mine
	shell.visible = false
	src.add_sibling(shell)
	_sync_mine_shell(shell, src)
	shell.visible = false
	return shell


func _rebuild_mine_shells(entry: Dictionary) -> void:
	_free_mine_shells(entry)
	var shells: Array = []
	for m in entry.get("meshes", []):
		var src := m as MeshInstance3D
		if src == null or not is_instance_valid(src):
			continue
		shells.append(_make_mine_shell(src))
	entry["shells"] = shells
	_apply_mine_paint(entry, bool(entry.get("painted", false)))


func _free_mine_shells(entry: Dictionary) -> void:
	for s in _mine_shells(entry):
		var shell := s as MeshInstance3D
		if shell != null and is_instance_valid(shell):
			shell.queue_free()
	entry["shells"] = []


func _set_mine_painted(entry: Dictionary, show: bool) -> void:
	if bool(entry.get("painted", false)) == show:
		if show:
			_apply_mine_paint(entry, true)
		return
	entry["painted"] = show
	if show:
		_mine_painted += 1
	else:
		_mine_painted = maxi(_mine_painted - 1, 0)
	_apply_mine_paint(entry, show)


func _apply_mine_paint(entry: Dictionary, show: bool) -> void:
	var meshes: Array = entry.get("meshes", [])
	var shells: Array = _mine_shells(entry)
	for i in shells.size():
		var shell := shells[i] as MeshInstance3D
		if shell == null or not is_instance_valid(shell):
			continue
		if i < meshes.size():
			var src := meshes[i] as MeshInstance3D
			if src != null and is_instance_valid(src):
				_sync_mine_shell(shell, src)
		shell.material_override = _mat_mine
		shell.visible = show


func _remove_mine(id: int) -> void:
	var e = _mines.get(id)
	if e != null:
		if bool(e.get("painted", false)):
			_mine_painted = maxi(_mine_painted - 1, 0)
		_clear_source_overrides(e)
		_free_mine_shells(e)
	_mines.erase(id)


func _clear_mine_state() -> void:
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null:
			continue
		_clear_source_overrides(e)
		_free_mine_shells(e)
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
	# or CSG. Shell rendering uses MeshInstance3D copies; sources never receive
	# a key-substitution override.
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
	_clear_source_overrides(e)


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
	var was_daylight := set_daylight
	set_daylight = rec.daylight_compensation
	if was_daylight and not set_daylight:
		_restore_exposure()
	set_strength = rec.daylight_strength
	set_nvg_noise = rec.nvg_noise
	set_nvg_white = rec.nvg_white
	set_world = rec.world
	set_highlight_knee = rec.highlight_knee
	set_glow_distance = rec.outline_distance
	set_mines = rec.thermal_mines
	set_mine_color(rec.color_mine)
	set_state_colors(rec.state_colors())
	set_state_brightness = rec.outline_brightness
	set_vrcets_strength = rec.vrcets_thermal_strength
	set_vrcets_red_hold = rec.vrcets_red_hold
	_dirty = true
	_tick_cd = 0.0


func set_palette_mode(mode: int) -> void:
	set_palette = mode
	_dirty = true
	_tick_cd = 0.0


func set_vrcets_tuning(strength: float, red_hold: float) -> void:
	set_vrcets_strength = clampf(strength, 0.0, 1.0)
	set_vrcets_red_hold = clampf(red_hold, 0.0, 1.0)
	_dirty = true
	_tick_cd = 0.0


func _exit_tree() -> void:
	_clear_mine_state()
	_restore_main_cam_mask()

# Hide the NVG overlay for a single frame. The overlay paints the thermal
# palette (or the green tint) over the whole frame, so a screen readback of a
# key pixel shows the painted colour, not the scene colour the key detector
# compares against. Hiding the rect leaves the raw scene visible.
func set_overlay_visible(v: bool) -> void:
	if _nvg_mat_node == null or not is_instance_valid(_nvg_mat_node):
		return
	if _nvg_mat_node is CanvasItem:
		(_nvg_mat_node as CanvasItem).visible = v
