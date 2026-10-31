extends SceneTree

const Travel = preload("res://mods/VTK/VTKTravel.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

# Заглушка ванильного Interface: те самые поля hover, которые мод зануляет,
# плюс Close(). VTKTravel трогает их через set()/call(), поэтому точные типы
# не важны - важно, что свойства существуют и их можно перезаписать в null.
class FakeIface extends Node:
	var closed := false
	var hoverItem = "item"
	var hoverGrid = "grid"
	var hoverSlot = "slot"
	var canUnequip := true

	func Close() -> void:
		closed = true

# Заглушка ванильного GameData: VTKTravel пишет карту через set(), а снимок
# читает свойствами. Наследуемся от Resource - поле game_data объявлено
# как Resource, и RefCounted сюда не подойдёт.
class FakeGameData extends Resource:
	var currentMap := "Village"
	var previousMap := "Cabin"
	var isCaching := false

# Наследник с пустым _ready(): VTKTravel._ready грузит res://Resources/GameData.tres,
# которого в стенде нет. Логика _close_interfaces от этой загрузки не зависит.
class TestTravel extends "res://mods/VTK/VTKTravel.gd":
	func _ready() -> void:
		pass

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_close_interfaces_clears_hover()
	t_close_interfaces_tolerates_missing_iface()
	t_map_rollback_restores_snapshot()
	t_map_rollback_without_game_data()
	t_map_arrived_needs_matching_scene()
	await t_await_map_ready_confirmed_skips_enter()
	print("")
	if fails == 0:
		print("Travel tests passed")
		quit(0)
	else:
		print("Travel tests failed: ", fails)
		quit(1)

func t_close_interfaces_clears_hover() -> void:
	# Путь обязан совпасть с Paths.INTERFACE = /root/Map/Core/UI/Interface:
	# именно так VTKTravel ищет ванильный узел.
	var map := Node.new()
	map.name = "Map"
	root.add_child(map)
	var core := Node.new()
	core.name = "Core"
	map.add_child(core)
	var ui := Node.new()
	ui.name = "UI"
	core.add_child(ui)
	var iface := FakeIface.new()
	iface.name = "Interface"
	ui.add_child(iface)

	var tr := TestTravel.new()
	root.add_child(tr)
	tr._close_interfaces()

	ck(iface.closed, "Close() вызван на Interface")
	ck(iface.hoverItem == null, "hoverItem занулён (иначе Grab() снимает наведённый предмет)")
	ck(iface.hoverGrid == null, "hoverGrid занулён")
	ck(iface.hoverSlot == null, "hoverSlot занулён")
	ck(iface.canUnequip == false, "canUnequip снят (иначе Unequip наведённого слота)")

	map.free()
	tr.queue_free()

func t_close_interfaces_tolerates_missing_iface() -> void:
	# Без ванильного Interface/ToggleInterface закрытие не должно падать:
	# get_node_or_null вернёт null, а ветки с iface пропускаются.
	var tr := TestTravel.new()
	root.add_child(tr)
	tr._close_interfaces()
	ck(true, "без Interface _close_interfaces не падает")
	tr.queue_free()

func t_map_rollback_restores_snapshot() -> void:
	var tr := TestTravel.new()
	root.add_child(tr)
	var gd := FakeGameData.new()
	tr.game_data = gd

	var snap := tr._map_state()
	ck(str(snap.get("currentMap")) == "Village", "_map_state снимает currentMap")
	ck(str(snap.get("previousMap")) == "Cabin", "_map_state снимает previousMap")

	# Так выглядит отказ: цель записана, карта не загрузилась.
	gd.currentMap = "Terminal"
	gd.previousMap = "Village"
	tr._restore_map(snap)
	ck(gd.currentMap == "Village", "откат возвращает currentMap")
	ck(gd.previousMap == "Cabin", "откат возвращает previousMap")

	tr.queue_free()

func t_map_rollback_without_game_data() -> void:
	var tr := TestTravel.new()
	root.add_child(tr)
	tr.game_data = null
	ck(tr._map_state().is_empty(), "без GameData снимок пуст")
	tr._restore_map({})
	ck(true, "откат на пустом снимке не падает")
	tr.queue_free()

# travel_arrived приходит из compiler-spawn-post, а Spawn() вызывается уже
# после сброса isCaching, поэтому ждать «начала кэша» в этой ветке нечего:
# флаг больше не поднимется, и цикл выстоит весь CACHE_ENTER_WAIT_FRAMES.
func t_await_map_ready_confirmed_skips_enter() -> void:
	var tr := TestTravel.new()
	root.add_child(tr)
	tr.game_data = FakeGameData.new()
	var t0 := Time.get_ticks_msec()
	await tr._await_map_ready(true)
	var ms := Time.get_ticks_msec() - t0
	ck(ms < 1000, "подтверждённый spawn не ждёт фазу кэша (" + str(ms) + " мс)")
	tr.queue_free()

func t_map_arrived_needs_matching_scene() -> void:
	var tr := TestTravel.new()
	root.add_child(tr)
	# Без current_scene _current_map_name() отдаёт "", и пустая цель не должна
	# считаться совпадением: иначе отказ загрузки выглядел бы как успех.
	ck(not tr._map_arrived("Village"), "без текущей сцены карта не подтверждена")
	ck(not tr._map_arrived(""), "пустая цель не подтверждается")
	tr.queue_free()
