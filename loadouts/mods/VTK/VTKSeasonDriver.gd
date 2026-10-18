extends RefCounted
class_name VTKSeasonDriver

const LOG := preload("res://mods/VTK/VTKLog.gd")
const SEASONS := preload("res://mods/VTK/VTKSeasons.gd")

# Материалы растительности: их шейдерный параметр tint перекрашивает всю листву
# и траву разом, потому что ресурсы общие. Пути жёсткие, поэтому грузим только
# существующие и тихо пропускаем остальные - при апдейте игры тянет одна правка.
const TREE_MATS := [
	"res://Nature/Trees/Files/MT_Tree_Branch.tres",
	"res://Nature/Trees/Files/MT_Tree_Billboard.tres",
	"res://Nature/Trees/Files/MT_Tree_Damaged.tres",
]
const GRASS_MATS := [
	"res://Nature/Grass/Files/MT_Grass.tres",
]
# Тон воздуха слабее тона листвы и берётся долей, чтобы не пережечь небо.
const AIR_STRENGTH := 0.55
const AIR_PROPS := ["ambient_light_color"]
# Кроссфейд тона: ваниль плавно сходит снег (глобальный Snow), а тон должен
# приходить так же - за фиксированное реальное время, а не скачком.
const TRANSITION_SECS := 8.0

var _last_index := -1
var _visuals := true
var _bound := false
var _tree_entries: Array = []
var _grass_entries: Array = []
var _air_entries: Array = []
var _world: Node = null
var _fade_active := false
var _fade_t := 0.0
var _fade_from_index := -1
var _fade_mats: Array = []
var _fade_airs: Array = []

func _init() -> void:
	_last_index = -1

func _get_sim() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null("/root/Simulation")

# set_season пишет ванильный сезон в Simulation (лето/зима) и, если включён
# визуал, перекрашивает общие материалы растительности и тон воздуха.
func set_season(index: int, is_dynamic_run: bool = true, visuals: bool = true) -> void:
	if not is_dynamic_run:
		return
	_visuals = visuals
	var sim := _get_sim()
	if sim == null:
		return
	_set_prop(sim, "season", 2 if index == 3 else 1)
	var first := _last_index < 0
	if not _visuals:
		_cancel_fade()
		_restore_foliage()
		_restore_air_all()
	elif first or TRANSITION_SECS <= 0.0:
		_cancel_fade()
		_apply_tint(index)
	else:
		_begin_fade(index)
	_last_index = index

func tick(delta: float) -> void:
	if not _fade_active:
		return
	_fade_t = minf(1.0, _fade_t + delta / TRANSITION_SECS)
	for e in _fade_mats:
		_set_mat(e, SEASONS.blend(e["from"], e["to"], _fade_t))
	for a in _fade_airs:
		_set_air_value(a, SEASONS.blend(a["from"], a["to"], _fade_t))
	if _fade_t >= 1.0:
		_cancel_fade()

func _begin_fade(index: int) -> void:
	if not _bound:
		_bind()
	_fade_from_index = _last_index
	_fade_mats.clear()
	for e in _tree_entries:
		_add_fade_mat(_fade_mats, e, SEASONS.tree_tint(index) if SEASONS.uses_tint(index) else e["orig"])
	for e in _grass_entries:
		_add_fade_mat(_fade_mats, e, SEASONS.grass_tint(index) if SEASONS.uses_tint(index) else e["orig"])
	_fade_airs = _air_pairs(index, _fade_from_index)
	_air_entries_clear_and_fill(_fade_airs)
	_fade_t = 0.0
	_fade_active = true

func _add_fade_mat(list: Array, e: Dictionary, to: Color) -> void:
	var mat = e["mat"]
	if mat == null or not is_instance_valid(mat):
		return
	var from = mat.get_shader_parameter("tint")
	if not (from is Color):
		from = Color(1, 1, 1, 1)
	list.append({"mat": mat, "from": from, "to": to})

func _cancel_fade() -> void:
	_fade_active = false
	_fade_t = 0.0
	_fade_from_index = -1
	_fade_mats.clear()
	_fade_airs.clear()

# season у Simulation может быть как свойством, так и методом-сеттером:
# сначала пробуем метод, иначе пишем свойство - как делал прежний код.
func _set_prop(obj: Object, name: String, value: Variant) -> void:
	if obj.has_method(name):
		obj.call(name, value)
		return
	obj.set(name, value)

# Карта пересобралась (Compiler.Spawn): материалы растительности глобальны и уже
# тонированы, а узел воздуха новый, поэтому его надо найти и покрасить заново.
func on_world_ready() -> void:
	_world = null
	if not _visuals or _last_index < 0:
		return
	if _fade_active:
		_fade_airs = _air_pairs(_last_index, _fade_from_index)
		_air_entries_clear_and_fill(_fade_airs)
		for a in _fade_airs:
			_set_air_value(a, SEASONS.blend(a["from"], a["to"], _fade_t))
	else:
		_apply_air(_last_index)

func restore() -> void:
	_cancel_fade()
	_restore_foliage()
	_restore_air_all()
	_last_index = -1
	_world = null

func _apply_tint(index: int) -> void:
	if not _bound:
		_bind()
	if SEASONS.uses_tint(index):
		var tree := SEASONS.tree_tint(index)
		var grass := SEASONS.grass_tint(index)
		for e in _tree_entries:
			_set_mat(e, tree)
		for e in _grass_entries:
			_set_mat(e, grass)
	else:
		_restore_foliage()
	_apply_air(index)

func _bind() -> void:
	_bound = true
	for path in TREE_MATS:
		_add_mat(_tree_entries, path)
	for path in GRASS_MATS:
		_add_mat(_grass_entries, path)
	LOG.log("[VTK] season materials bound: tree=" + str(_tree_entries.size()) + " grass=" + str(_grass_entries.size()))

func _add_mat(list: Array, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var mat = load(path)
	if not (mat is ShaderMaterial):
		return
	var orig = mat.get_shader_parameter("tint")
	if orig == null:
		orig = Color(1, 1, 1, 1)
	list.append({"mat": mat, "orig": orig})

func _set_mat(e: Dictionary, color: Color) -> void:
	var mat = e["mat"]
	if mat != null and is_instance_valid(mat):
		mat.set_shader_parameter("tint", color)

func _restore_foliage() -> void:
	for e in (_tree_entries + _grass_entries):
		var mat = e["mat"]
		if mat != null and is_instance_valid(mat):
			mat.set_shader_parameter("tint", e["orig"])

# Тон воздуха аддитивный: к исходному цвету карты добавляется отклонение палитры.
# Пары from/to считаются от ванильного цвета, снятого метой с объекта, поэтому
# переживают пересборку драйвера и перезагрузку карты.
func _air_pairs(to_index: int, from_index: int) -> Array:
	var out: Array = []
	var world := _find_world()
	if world == null:
		return out
	var env_node = world.get("environment")
	if env_node != null and is_instance_valid(env_node):
		var env_res = env_node.get("environment")
		if env_res != null:
			for prop in AIR_PROPS:
				_air_pair(out, env_res, prop, to_index, from_index, AIR_STRENGTH)
	var sun = world.get("sunLight")
	if sun == null:
		sun = world.get_node_or_null("Planet/Sun/Light")
	if sun != null and is_instance_valid(sun):
		_air_pair(out, sun, "light_color", to_index, from_index, AIR_STRENGTH * 0.6)
	return out

func _air_pair(out: Array, obj: Object, prop: String, to_index: int, from_index: int, strength: float) -> void:
	if not obj.has_meta(_vanilla_key(prop)):
		var cur = obj.get(prop)
		if not (cur is Color):
			return
		obj.set_meta(_vanilla_key(prop), cur)
	var vanilla: Color = obj.get_meta(_vanilla_key(prop))
	out.append({
		"obj": obj,
		"prop": prop,
		"from": _tint_color(vanilla, SEASONS.air_tint(from_index), strength),
		"to": _tint_color(vanilla, SEASONS.air_tint(to_index), strength),
	})

func _apply_air(index: int) -> void:
	var pairs := _air_pairs(index, -1)
	for a in pairs:
		_set_air_value(a, a["to"])
	_air_entries_clear_and_fill(pairs)

func _set_air_value(a: Dictionary, color: Color) -> void:
	var obj = a["obj"]
	if obj != null and is_instance_valid(obj):
		obj.set(a["prop"], color)

func _air_entries_clear_and_fill(pairs: Array) -> void:
	_air_entries.clear()
	for a in pairs:
		_air_entries.append({"obj": a["obj"], "prop": a["prop"]})

func _restore_air_all() -> void:
	for e in _air_entries:
		var obj = e["obj"]
		var prop: String = e["prop"]
		if obj != null and is_instance_valid(obj) and obj.has_meta(_vanilla_key(prop)):
			obj.set(prop, obj.get_meta(_vanilla_key(prop)))
	_air_entries.clear()

func _vanilla_key(prop: String) -> String:
	return "vtk_tint_vanilla_" + prop

func _tint_color(vanilla: Color, tint: Color, strength: float) -> Color:
	var t := clampf(strength, 0.0, 1.0)
	return Color(
		clampf(vanilla.r + (tint.r - 1.0) * t, 0.0, 4.0),
		clampf(vanilla.g + (tint.g - 1.0) * t, 0.0, 4.0),
		clampf(vanilla.b + (tint.b - 1.0) * t, 0.0, 4.0),
		vanilla.a)

func _find_world() -> Node:
	if _world != null and is_instance_valid(_world):
		return _world
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return null
	_world = _scan_named(tree.current_scene, "World")
	return _world

func _scan_named(parent: Node, target: String) -> Node:
	if parent == null:
		return null
	if str(parent.name) == target:
		return parent
	for c in parent.get_children():
		var found := _scan_named(c, target)
		if found != null:
			return found
	return null
