extends Node
const Paths = preload("res://mods/ThermalVTK/VTKPaths.gd")

# Owns the NVG overlay shader, plus the thermal/mines layer that rides on it.
#
# Architecture (ported from the ThermalVision reference mod):
#   1. Our own shader REPLACES the vanilla one on the NVG ColorRect. Because
#      vanilla only ever calls set_shader_parameter("tint", ...) on that same
#      ShaderMaterial, plain green NVG keeps working untouched -- we only get
#      a "noise" uniform we can actually drive (vanilla's own shader declares
#      noise as a `const`, which is why BetterNVG's set_shader_parameter
#      calls there did nothing).
#   2. Bots, mines and the friendly Nomad marker each carry fixed emissive
#      "key" colours. Mines are painted by material_override, so the whole
#      on-screen shell IS the key pixel. A bot's key body is a DUPLICATE of its
#      real mesh (a sibling carrying VTKBot.gdshader) with the real mesh hidden,
#      because the game's own bot geometry ignores an external material_override;
#      that shader picks the key by pixel height so a corpse can cool from the
#      extremities inward. The marker is a separate small billboarded key mesh
#      over a Nomad's head.
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

# A body stays highlighted for DEATH_COOLDOWN seconds after death, cooling from
# the head down, then the glow hides entirely.
const DEATH_COOLDOWN := 120.0
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
# (1.00,0.21,0.16), alerted (1,1,0)->(1.00,0.97,0.46), hunting (1,0,1)->
# (1.00,0.34,1.00), combat (0,1,1)->(0.82,1.00,1.00), nomad (0,1,0)->
# (0.77,1.00,0.53). The ring still EMITS the raw keys; only the detector
# compares against these.
const DET_ST_NORMAL := Color(1.00, 0.21, 0.16)
const DET_ST_ALERTED := Color(1.00, 0.97, 0.46)
const DET_ST_HUNTING := Color(1.00, 0.34, 1.00)
const DET_ST_COMBAT := Color(0.82, 1.00, 1.00)
const DET_ST_NOMAD := Color(0.77, 1.00, 0.53)

# settings
var set_nvg_noise: float = 4.0
var set_nvg_white: float = 1.0
var set_thermal: bool = false
var set_mines: bool = true
# Mirrors the MCM outline distance; gates mine glow (and, before the ESP took over, bot glow).
var set_glow_distance: float = 150.0
var set_palette: int = 0
var set_world: float = 1.70
var set_outline_brightness: float = 0.6
var _state_colors: Dictionary = {}
var _game_data: Resource = null
var _shader: Shader = null
var _nvg_root: Node = null
var _nvg_mat_node: Node = null
var _installed: bool = false
var _install_retry: int = 0

var _mat_mine: StandardMaterial3D = null

var _bots: Dictionary = {}
var _mines: Dictionary = {}
var _mine_watch: Dictionary = {}
var _pending: Array[int] = []
var _tick_cd: float = 0.0
var _scene_ref: Node = null
# true, если прошлый _process что-то покрасил (гейт перехода on->off).
var _paint_on: bool = false
# прошлое значение on, нужно ровно для перехода on->off (снять покраску один раз).
var _was_on: bool = false
# PIP off + magnifying scope rotates colour channels, so the overlay detector
# matches a key's orbit; pushed only on change (see _process).
var _scope_rotate: bool = false


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

	get_tree().node_added.connect(_on_node_added)
	_scene_ref = get_tree().current_scene
	_reseed(get_tree().current_scene)


# A single downward-pointing triangle reads as ▼. Billboarded via the material,
# so the exact winding does not matter (cull is disabled anyway).
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
	elif _is_bot(n):
		_register_bot(n)
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
func _key_set(m: StandardMaterial3D, c: Color) -> void:
	if m == null:
		return
	m.albedo_color = c
	m.emission = c


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
	if _is_bot(n):
		_register_bot(n)


# AI.gd extends Node3D, not CharacterBody3D. Signature: has Activate(), exposes
# a "dead" flag and an exported MeshInstance3D "mesh". Trader.gd also has
# Activate() but no "dead", so it stays out of the bot set.
func _is_bot(n: Node) -> bool:
	return n is Node3D and n.has_method("Activate") and "dead" in n and "mesh" in n


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
	var mat = target.get("material")
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == _shader:
		_nvg_mat_node = target
		_installed = true
		return
	if mat == null or not (mat is ShaderMaterial):
		_installed = false
		return
	mat.shader = _shader
	_nvg_mat_node = target
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
	nvg_mat.set_shader_parameter("thermalDarken", set_world)
	nvg_mat.set_shader_parameter("worldPaletteMode", set_palette)
	nvg_mat.set_shader_parameter("nvgWhite", set_nvg_white)
	nvg_mat.set_shader_parameter("mineKey", DET_MINE)
	nvg_mat.set_shader_parameter("stNormalKey", DET_ST_NORMAL)
	nvg_mat.set_shader_parameter("stAlertedKey", DET_ST_ALERTED)
	nvg_mat.set_shader_parameter("stHuntingKey", DET_ST_HUNTING)
	nvg_mat.set_shader_parameter("stCombatKey", DET_ST_COMBAT)
	nvg_mat.set_shader_parameter("stNomadKey", DET_ST_NOMAD)
	nvg_mat.set_shader_parameter("stNormalColor", _state_colors.get("state_normal", Color(1.0, 0.72, 0.28)))
	nvg_mat.set_shader_parameter("stAlertedColor", _state_colors.get("state_alerted", Color(1.0, 0.9, 0.25)))
	nvg_mat.set_shader_parameter("stHuntingColor", _state_colors.get("state_hunting", Color(1.0, 0.5, 0.1)))
	nvg_mat.set_shader_parameter("stCombatColor", _state_colors.get("state_combat", Color(0.95, 0.18, 0.15)))
	nvg_mat.set_shader_parameter("stNomadColor", _state_colors.get("nomad_color", Color(0.30, 1.0, 0.35)))
	nvg_mat.set_shader_parameter("stateBright", set_outline_brightness)
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
		_bots.clear()
		_mines.clear()
		_mine_watch.clear()
		_nvg_root = null
		_installed = false
		_install_retry = 0
		_reseed(_scene_ref)
		_tick_cd = 0.0
	# Ограниченный ретрай: NVG-узел найден, но ванильный await-based _ready ещё
	# не создал Overlay/материал. Ставим шейдер только по событию обнаружения,
	# с коротким добором кадров, а не проверкой каждый кадр.
	if _install_retry > 0:
		_install_retry -= 1
		_try_install_shader()
		if _installed:
			_install_retry = 0
	var on := set_thermal and _nvg_active()
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
	# Player position, fetched once per frame.
	var ppos := _player_pos()

	if on:
		_paint_on = false
		for id in _mines.keys():
			_update_mine(id, true, ppos)
	elif _was_on or _paint_on:
		_clear_paint()
		_paint_on = false
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


func _cdist(a: Color, b: Color) -> float:
	return sqrt(pow(a.r - b.r, 2.0) + pow(a.g - b.g, 2.0) + pow(a.b - b.b, 2.0))


func _register_bot(node: Node) -> void:
	var id := node.get_instance_id()
	if _bots.has(id):
		return
	# The bot's visual (variant skin, LODs, gear) is assembled by AI.Initialize()
	# at runtime as a whole subtree, and the exported node.mesh is only ONE inner
	# piece of it -- duplicating that single mesh highlighted just the sliver that
	# pokes past the real skin, so the body read as scenery. Instead we paint the
	# bot's own geometry directly, exactly like mines: sweep every
	# GeometryInstance3D under the node and override its material. The sweep is
	# (re)done lazily on the tick, because the subtree does not exist yet at
	# registration and AI.Initialize() can rewire it later.
	_bots[id] = {
		"node": node,
		"meshes": [],
		"mat": null,
		"painted": false,
		"paint": null,
		"friendly": _is_friendly(node),
		"friendly_resolved": false,
		"death": 0.0,
		"recorded": false,
		"child_count": -1,
	}


# Sweeps the bot's whole visual subtree and returns its geometry nodes. The
# exported node.mesh is only an inner piece of the rig -- the visible skin is
# separate LOD/gear meshes -- so painting that one node (or a duplicate of it)
# left the real body as scenery with just a key sliver at the silhouette. This
# is the same route mines already take.
func _sweep_bot_meshes(node: Node) -> Array:
	var all: Array = []
	_collect_meshes(node, all)
	var out: Array = []
	for m in all:
		if is_instance_valid(m):
			out.append(m)
	return out


func _is_friendly(node: Node) -> bool:
	# Faction comes from the AIData variant picked in AI.Initialize(), which can
	# be null at registration time, so the result is only cached once the variant
	# resolves. Falls back to the pooled node name, since AISpawner names them
	# AI_Nomad, AI_Nomad_2.
	var v = node.get("variant")
	if v != null and v.get("faction") != null:
		return int(v.get("faction")) == 0
	return String(node.name).contains("Nomad")


# Покой при выключенном тепловизоре. Регистрация (node_added) продолжает идти
# и при off, поэтому мёртвые записи всё равно надо чистить, иначе _mines рос бы
# без границы. Заодно лэтчим death clock: иначе труп, убитый при выключенном
# тепловизоре, при включении получил бы death="now" и светился бы лишние
# DEATH_COOLDOWN секунд.
func _off_frame_upkeep() -> void:
	var now := float(Time.get_ticks_msec()) / 1000.0
	for id in _bots.keys():
		var e = _bots.get(id)
		if e == null:
			continue
		var node = e.get("node")
		if node == null or not is_instance_valid(node):
			_bots.erase(id)
			continue
		if bool(node.get("dead")):
			if not e["recorded"]:
				e["recorded"] = true
				e["death"] = now
		else:
			e["recorded"] = false
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null or not is_instance_valid(e.get("node")):
			_mines.erase(id)


# Снимает покраску на переходе on->off ровно один раз: material_override в null
# на все меши ботов и мин. Дальше кадр при off ботов и мешей не обходит вовсе.
func _clear_paint() -> void:
	for id in _bots.keys():
		var e = _bots.get(id)
		if e == null:
			continue
		for m in e.get("meshes", []):
			if is_instance_valid(m):
				(m as GeometryInstance3D).material_override = null
		e["painted"] = false
		e["paint"] = null
	for id in _mines.keys():
		var e = _mines.get(id)
		if e == null:
			continue
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
	for mesh in e["meshes"]:
		if is_instance_valid(mesh):
			mesh.material_override = _mat_mine if show else null


func set_thermal_enabled(on: bool) -> void:
	set_thermal = on
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