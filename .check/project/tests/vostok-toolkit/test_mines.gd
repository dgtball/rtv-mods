extends SceneTree

const Mines = preload("res://mods/VTK/VTKMines.gd")

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
	t_mine_is_recognised()
	t_grenade_is_not_a_mine()
	t_partial_match_is_not_a_mine()
	t_detector_masks_agent_id_area()
	t_area_trigger_fires_on_live_agent()
	t_area_trigger_skips_dead_and_player()
	t_trigger_is_armed_once()
	print("")
	if fails == 0:
		print("Mines tests passed")
		quit(0)
	else:
		print("Mines tests failed: ", fails)
		quit(1)

class FakeMine extends Node3D:
	var isDetonated := false
	var detonated := 0

	func Detonate() -> void:
		detonated += 1
		isDetonated = true

# Ванильная граната тоже объявляет Detonate(), но isDetonated у неё нет.
class FakeGrenade extends Node3D:
	func Detonate() -> void:
		pass

class FakeBomb extends Node3D:
	var isDetonated := false

# Свойство без метода и метод без свойства — не мина: иначе зона превратила бы
# гранату в мину с дистанционным взрывателем.
func t_mine_is_recognised() -> void:
	var mine := FakeMine.new()
	ck(Mines._is_mine(mine), "Detonate + isDetonated -> мина")
	mine.free()

func t_grenade_is_not_a_mine() -> void:
	var grenade := FakeGrenade.new()
	ck(not Mines._is_mine(grenade), "один Detonate без isDetonated -> не мина")
	grenade.free()

func t_partial_match_is_not_a_mine() -> void:
	var bomb := FakeBomb.new()
	ck(not Mines._is_mine(bomb), "isDetonated без Detonate -> не мина")
	bomb.free()
	ck(not Mines._is_mine(null), "null -> не мина")

# --- Детектор: Area3D агента (слой 4096), а не тело (слой 2) ---
# Тело NPC — StaticBody3D, и Area3D не замечает его перемещение: перекрытие
# считается только при регистрации тела в пространстве. ID-зона агента
# пересчитывается каждый шаг, поэтому зона мины смотрит именно на неё.

const KC = preload("res://mods/VTK/VTKKillCounter.gd")

class FakeAgent extends Node3D:
	var variant = null
	var dead := false

class FakeHooks extends Node:
	var calls := 0
	var last_h := 0.0
	var last_player := true

	func arm_mine_blast(_pos: Vector3, h: float, player: bool) -> void:
		calls += 1
		last_h = h
		last_player = player

# Ровно та вложенность, что у AI_Bandit: Identifier/ID под скелетом модели.
func _id_area(agent: Node) -> Area3D:
	var ident := Node3D.new()
	ident.name = "Identifier"
	agent.add_child(ident)
	var id := Area3D.new()
	id.name = "ID"
	ident.add_child(id)
	return id

func t_detector_masks_agent_id_area() -> void:
	var mine := FakeMine.new()
	var mines := Mines.new()
	root.add_child(mines)
	mines._mines_attach(mine)
	var area: Area3D = mine.get_node_or_null(Mines.DETECTOR_NAME)
	ck(area != null, "зона создана ребёнком мины")
	if area != null:
		ck(area.collision_mask == 4096, "маска зоны — слой ID-зоны агента")
		ck(area.collision_layer == 0, "слой зоны пуст: ванильные детекторы её не видят")
		ck(area.monitoring, "зона мониторит")
	mines._mines_attach(mine)
	ck(mine.get_node_or_null(Mines.DETECTOR_NAME) == area, "повторный attach не плодит зон")
	mines.queue_free()
	mine.queue_free()

func t_area_trigger_fires_on_live_agent() -> void:
	var mines := Mines.new()
	root.add_child(mines)
	var hooks := FakeHooks.new()
	root.add_child(hooks)
	mines.bind_hooks(hooks)
	var mine := FakeMine.new()
	root.add_child(mine)
	var agent := FakeAgent.new()
	root.add_child(agent)
	var id := _id_area(agent)
	ck(KC.agent_root(id) == agent, "agent_root поднимается от ID к агенту")

	var detector := Area3D.new()
	detector.set_meta("vtk_born", Engine.get_physics_frames() - 10)
	mines._mines_on_area(id, detector, mine)
	ck(mine.detonated == 1, "живой NPC взводит мину")
	ck(hooks.calls == 1, "взвод пишет запись в кольцо")
	ck(is_equal_approx(hooks.last_h, 2.0), "высота взрыва от NPC — 2 м")
	ck(not hooks.last_player, "взвод от NPC не приписан игроку")

	mines.queue_free()
	hooks.queue_free()
	mine.queue_free()
	agent.queue_free()

func t_area_trigger_skips_dead_and_player() -> void:
	var mines := Mines.new()
	root.add_child(mines)
	var hooks := FakeHooks.new()
	root.add_child(hooks)
	mines.bind_hooks(hooks)
	var detector := Area3D.new()
	detector.set_meta("vtk_born", Engine.get_physics_frames() - 10)

	var corpse := FakeAgent.new()
	corpse.dead = true
	root.add_child(corpse)
	var corpse_id := _id_area(corpse)
	var mine := FakeMine.new()
	root.add_child(mine)
	mines._mines_on_area(corpse_id, detector, mine)
	ck(mine.detonated == 0, "труп не взводит мину")

	var player := Node3D.new()
	root.add_child(player)
	var player_id := _id_area(player)
	mines._mines_on_area(player_id, detector, mine)
	ck(mine.detonated == 0, "Y-зона не-агента (игрок) не взводит мину")
	ck(hooks.calls == 0, "ни труп, ни игрок не пишут в кольцо")

	# Свежесозданная зона молчит: иначе ретрофит подрывал бы мину под NPC.
	var agent := FakeAgent.new()
	root.add_child(agent)
	var fresh := Area3D.new()
	fresh.set_meta("vtk_born", Engine.get_physics_frames())
	var fresh_id := _id_area(agent)
	mines._mines_on_area(fresh_id, fresh, mine)
	ck(mine.detonated == 0, "в grace-окне зона не срабатывает")

	mines.queue_free()
	hooks.queue_free()
	mine.queue_free()
	corpse.queue_free()
	player.queue_free()
	agent.queue_free()

func t_trigger_is_armed_once() -> void:
	var mines := Mines.new()
	root.add_child(mines)
	var hooks := FakeHooks.new()
	root.add_child(hooks)
	mines.bind_hooks(hooks)
	var mine := FakeMine.new()
	root.add_child(mine)
	mines._mines_trigger(mine)
	mines._mines_trigger(mine)
	ck(hooks.calls == 1, "повторный взвод не пишет вторую запись")
	ck(mine.detonated == 1, "Detonate вызван один раз")
	mines.queue_free()
	hooks.queue_free()
	mine.queue_free()
