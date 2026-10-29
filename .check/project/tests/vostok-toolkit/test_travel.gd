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
