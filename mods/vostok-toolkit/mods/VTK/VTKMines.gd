extends Node
# NPC-мины и дым после взрыва. Узел живёт под /root/VTKUI (его создаёт
# VTKFeatureHost) и держит две вещи: Area3D-зоны, которые подрывают мину под
# подошедшим NPC, и пул систем дыма, который поднимается после срабатывания.
# Тумблеры приходят из MCM через VTKConfig -> VTKMCMBridge -> VTKFeatureHost.

const Log = preload("res://mods/VTK/VTKLog.gd")
const KC = preload("res://mods/VTK/VTKKillCounter.gd")

const DETECTOR_NAME := "VTK_NPC_Detector"
const DETECTOR_GROUP := "VTKMineDetector"
const DETECTION_HEIGHT := 1.5
# Слой Area3D `ID` у агента (AI_Bandit.tscn: Identifier/ID), а не слой тела
# (2). Тело NPC — StaticBody3D, и Area3D его не видит, когда AI телепортирует
# узел кадр за кадром: перекрытие считается только в момент регистрации тела
# в пространстве. Area3D-о-Area3D же пересчитывается каждый шаг, и на этом же
# стоит ванильный Explosion.CheckID.
const DETECTOR_MASK := 4096
# Высота взрыва при взводе наступившим NPC: ванильный Detonate поднимает
# мину на detonationHeight (2.0) и рвёт уже сверху.
const TRIP_BLAST_HEIGHT := 2.0
# Godot поднимает area_entered для зон, которые уже пересекаются в момент
# подключения, поэтому ретрофит зоны на карте подорвал бы мину под стоящим NPC.
const TRIGGER_GRACE_FRAMES := 2
const SMOKE_SCENE := "res://Effects/Grenade_Smoke.tscn"
const SMOKE_POOL_SIZE := 5
const SMOKE_LIFE_SEC := 26.0
const SMOKE_RISE_SEC := 32.0

var _enabled := false
var _radius := 1.5
var _smoke_on := false
var _smoke_pool: Array = []
var _smoke_idx := 0
# VTKHooks: запись взвода в кольцо и сигнал дыма. Пустой узел — мины всё равно
# рвутся, просто взрыв не попадёт в ленту (атрибуция живёт в хуках).
var _hooks: Node = null

# Мина опознаётся по паре «метод Detonate + свойство isDetonated», а не по
# `is Mine` или resource_path: класса Mine в стенде нет, а путь ломается на
# апдейте игры. Одного Detonate мало — Grenade.gd тоже его объявляет.
static func _is_mine(node: Node) -> bool:
	return node != null and node.has_method("Detonate") and "isDetonated" in node

# Подходит ли агент под взвод: ID-зона есть и у игрока, и у трупа, поэтому
# своего отсеиваем по отсутствию variant, мёртвого — по dead.
static func _fires_on_agent(ai: Node) -> bool:
	if not KC._is_agent(ai):
		return false
	return not ("dead" in ai and bool(ai.get("dead")))

func bind_hooks(hooks: Node) -> void:
	_hooks = hooks

func set_enabled(v: bool) -> void:
	if v == _enabled:
		return
	_enabled = v
	var tree := get_tree()
	if v:
		if tree != null and not tree.node_added.is_connected(_mines_on_node_added):
			tree.node_added.connect(_mines_on_node_added)
		_mines_scan_existing()
	else:
		if tree != null and tree.node_added.is_connected(_mines_on_node_added):
			tree.node_added.disconnect(_mines_on_node_added)
		_mines_remove_detectors()

func set_radius(r: float) -> void:
	_radius = r
	var tree := get_tree()
	if tree == null:
		return
	for det in tree.get_nodes_in_group(DETECTOR_GROUP):
		if det == null or not is_instance_valid(det):
			continue
		var cs := det.get_child(0) as CollisionShape3D
		if cs == null:
			continue
		var sh = cs.shape
		if sh is CylinderShape3D:
			sh.radius = float(r)

func set_smoke(v: bool) -> void:
	if v == _smoke_on:
		return
	_smoke_on = v
	if v:
		_mines_ensure_smoke_pool()
		return
	for s in _smoke_pool:
		if s != null and is_instance_valid(s):
			s.queue_free()
	_smoke_pool.clear()
	_smoke_idx = 0

func _mines_scan_existing() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var start: Node = tree.current_scene
	if start == null:
		start = tree.root
	if start != null:
		_mines_scan(start)

func _mines_scan(node: Node) -> void:
	if _is_mine(node) and not node.has_node(DETECTOR_NAME):
		_mines_attach(node)
	for c in node.get_children():
		_mines_scan(c)

func _mines_on_node_added(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not _is_mine(node) or node.has_node(DETECTOR_NAME):
		return
	# node_added приходит до того, как у мины появился трансформ: зона, взятая
	# сразу, встала бы в мировой ноль.
	if node.is_inside_tree():
		_mines_attach(node)
	else:
		_mines_attach.call_deferred(node)

func _mines_attach(mine: Node) -> void:
	if mine == null or not is_instance_valid(mine) or not (mine is Node3D):
		return
	if mine.has_node(DETECTOR_NAME):
		return
	var area := Area3D.new()
	area.name = DETECTOR_NAME
	# Слой 0: зону не должны видеть ванильный Explosion.CheckID/CheckAlert и
	# чужие детекторы. Маска 4096 — слой Area3D `ID` живого агента.
	area.collision_layer = 0
	area.collision_mask = DETECTOR_MASK
	area.monitoring = true
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = float(_radius)
	shape.height = DETECTION_HEIGHT
	cs.shape = shape
	cs.position = Vector3(0, DETECTION_HEIGHT * 0.5, 0)
	area.add_child(cs)
	area.add_to_group(DETECTOR_GROUP)
	# Зона — ребёнок мины: мировая позиция наследуется, а выключение фичи
	# убирает зону вместе с миной, не оставляя сирот.
	mine.add_child(area)
	area.set_meta("vtk_born", Engine.get_physics_frames())
	area.area_entered.connect(_mines_on_area.bind(area, mine))

func _mines_on_area(agent_area: Node3D, detector: Area3D, mine: Node) -> void:
	if detector == null or not is_instance_valid(detector):
		return
	if Engine.get_physics_frames() - int(detector.get_meta("vtk_born", 0)) < TRIGGER_GRACE_FRAMES:
		return
	if mine == null or not is_instance_valid(mine):
		return
	if not _fires_on_agent(KC.agent_root(agent_area)):
		return
	_mines_trigger(mine)

# Взвод фиксируется здесь, а не хуком Mine.gd: этот скрипт в skip-list
# модлоадера (queue_free после взрыва), и хуки на него не встают вовсе.
# Запись в кольцо нужна до ExplosionDamage — иначе взрыв с id == null
# останется без убийцы и килл не попадёт ни в ленту, ни в счётчик.
func _mines_trigger(mine: Node) -> void:
	if mine.has_meta("vtk_mine_armed"):
		return
	mine.set_meta("vtk_mine_armed", true)
	if _hooks != null and is_instance_valid(_hooks) and _hooks.has_method("arm_mine_blast"):
		_hooks.call("arm_mine_blast", mine.global_position, TRIP_BLAST_HEIGHT, false)
	if mine.has_method("Detonate"):
		mine.call("Detonate")

func _mines_remove_detectors() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for det in tree.get_nodes_in_group(DETECTOR_GROUP):
		if det != null and is_instance_valid(det):
			det.queue_free()

func _mines_ensure_smoke_pool() -> void:
	if not _smoke_pool.is_empty():
		return
	if not ResourceLoader.exists(SMOKE_SCENE):
		Log.warn_once("vtk_mines_smoke", "mine smoke: Grenade_Smoke.tscn missing")
		return
	var tree := get_tree()
	if tree == null:
		return
	var scene = load(SMOKE_SCENE)
	if scene == null:
		return
	var scale_tex := CurveTexture.new()
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.185))
	sc.add_point(Vector2(0.25, 0.925))
	sc.add_point(Vector2(1.0, 1.48))
	sc.add_point(Vector2(2.2, 0.74))
	sc.add_point(Vector2(3.0, 0.0185))
	scale_tex.curve = sc
	var alpha_tex := CurveTexture.new()
	var ac := Curve.new()
	ac.add_point(Vector2(0.0, 0.01))
	ac.add_point(Vector2(0.25, 0.08))
	ac.add_point(Vector2(0.5, 0.1))
	ac.add_point(Vector2(1.95, 0.75))
	ac.add_point(Vector2(3.0, 1.0))
	alpha_tex.curve = ac
	for _i in SMOKE_POOL_SIZE:
		var smoke = scene.instantiate()
		if smoke == null:
			return
		smoke.set_script(null)
		tree.root.add_child(smoke)
		smoke.amount = 17
		smoke.lifetime = 2.8
		smoke.speed_scale = 0.3
		smoke.local_coords = false
		smoke.one_shot = true
		smoke.emitting = false
		smoke.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
		# Каждая настройка материала под гардом: на другом апдейте игры
		# process_material/draw_pass_1 могут оказаться null или другим типом,
		# и прямое обращение оборвало бы первое включение дыма.
		var pm = smoke.process_material
		if pm is ParticleProcessMaterial:
			var mat = pm.duplicate()
			if mat is ParticleProcessMaterial:
				mat.scale_curve = scale_tex
				mat.alpha_curve = alpha_tex
				mat.turbulence_influence_max = 1.5
				mat.gravity = -0.7
				smoke.process_material = mat
		var dp = smoke.draw_pass_1
		if dp != null and dp.get("material") != null:
			var mesh_mat = dp.get("material")
			if mesh_mat is StandardMaterial3D:
				mesh_mat.emission_enabled = true
				mesh_mat.emission = Color(1.38, 1.38, 1.38, 0.92)
				mesh_mat.backlight_enabled = true
		smoke.process_mode = Node.PROCESS_MODE_DISABLED
		smoke.visible = false
		smoke.global_position = Vector3(0, -1000, 0)
		_smoke_pool.append(smoke)

func on_detonated(pos: Vector3) -> void:
	if not _smoke_on or _smoke_pool.is_empty():
		return
	var smoke = _smoke_pool[_smoke_idx % _smoke_pool.size()]
	_smoke_idx = (_smoke_idx + 1) % _smoke_pool.size()
	if smoke == null or not is_instance_valid(smoke):
		return
	var tree := get_tree()
	if tree == null:
		return
	smoke.global_position = pos + Vector3(0, 10, 0)
	smoke.process_mode = Node.PROCESS_MODE_INHERIT
	smoke.visible = true
	# Цель твина — абсолютная точка: в референсе позиция прибавлялась дважды, и
	# дым улетал на ~130 м вверх.
	var target := pos + Vector3(randf_range(-10.0, 10.0), 65.0, randf_range(-10.0, 10.0))
	var tw: Tween = smoke.create_tween()
	if tw != null:
		tw.tween_property(smoke, "global_position", target, SMOKE_RISE_SEC).set_ease(Tween.EASE_OUT)
	smoke.restart()
	smoke.emitting = true
	tree.create_timer(SMOKE_LIFE_SEC).timeout.connect(_mines_retire_smoke.bind(smoke))

func _mines_retire_smoke(smoke) -> void:
	if smoke == null or not is_instance_valid(smoke):
		return
	smoke.visible = false
	smoke.process_mode = Node.PROCESS_MODE_DISABLED
	smoke.global_position = Vector3(0, -1000, 0)
