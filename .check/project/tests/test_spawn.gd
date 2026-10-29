extends SceneTree

const VTKData = preload("res://mods/VTK/VTKData.gd")

var fails := 0

class FakeSlot:
	extends Panel
	var hint := NodePath("")

class FakeItem:
	extends Node
	var slotData = 1

class FakeGrid:
	extends Node
	var picked: Array = []
	func Pick(n) -> void:
		picked.append(n)

class FakeInterface:
	extends Node
	func Create(sd, grid, _one) -> void:
		var item := FakeItem.new()
		item.slotData = sd
		grid.add_child(item)
	# Игровой Equip забирает узел из сетки и кладёт в слот.
	func Equip(node, sl) -> void:
		var p = node.get_parent()
		if p != null:
			p.remove_child(node)
		sl.add_child(node)

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_is_furniture()
	t_insert_desc()
	t_instances()
	t_find_free_slot()
	t_equip_sd()
	print("")
	if fails == 0:
		print("tests passed")
		quit(0)
	else:
		print("Spawn tests failed: ", fails)
		quit(1)

# Распознавание мебели по type ресурса. Словарь-описание тоже подходит:
# у него есть .get, как у Resource.
func t_is_furniture() -> void:
	ck(VTKData._is_furniture({"type": "Furniture"}), "Furniture распознана")
	ck(VTKData._is_furniture({"type": " Furniture "}), "пробелы и регистр снимаются")
	ck(not VTKData._is_furniture({"type": "Weapon"}), "оружие не мебель")
	ck(not VTKData._is_furniture({"type": "Consumables"}), "еда не мебель")
	ck(not VTKData._is_furniture({}), "пустое описание не мебель")
	ck(not VTKData._is_furniture(null), "null не мебель")

# _insert_desc не дотрагивается до interface, пока вставлять нечего: пустой
# путь даёт null в _build_slot_data и обрыв цикла на первой итерации.
func t_insert_desc() -> void:
	ck(VTKData._insert_desc(null, null, {"path": ""}) == 0, "пустой путь: 0 вставок")
	ck(VTKData._insert_desc(null, null, {"path": "", "count": 5}) == 0,
		"битый путь обрывается первой итерацией")

func t_instances() -> void:
	ck(VTKData._instances({}) == 1, "без count один инстанс")
	ck(VTKData._instances({"count": 99}) == 32, "count клампится к 32")
	ck(VTKData._instances({"count": -5}) == 0, "минусовой count ноль")
	# Обычное снаряжение держит число копий в amount, а не в count:
	# без этого 5 банок спавнились одной стопкой, и игра показывала одну.
	ck(VTKData._instances({"amount": 5.0}) == 5, "amount без ресурса = отдельные копии")
	ck(VTKData._instances({"amount": 2.0, "count": 3}) == 3, "count важнее amount")
	ck(VTKData._instances({"amount": 0.4}) == 1, "дробный amount меньше 1 = один инстанс")

# Оверлей Equipment/Hints держит Label'ы с именами слотов (Primary, Helmet...).
# Наивный поиск свободного слота по имени хватал такую подпись, когда настоящий
# слот занят: игра «экипировала» предмет в Label — визуальный призрак, fitted
# вместо skip, повторный применённый сет дублировался вместо ухода в инвентарь.
func t_find_free_slot() -> void:
	var root := Control.new()
	root.name = "Equipment"
	var primary := FakeSlot.new()
	primary.name = "Primary"
	root.add_child(primary)
	var hints := Control.new()
	hints.name = "Hints"
	var hl := Label.new()
	hl.name = "Primary"
	hints.add_child(hl)
	root.add_child(hints)

	var wanted := {"primary": true}
	ck(VTKData._find_free_slot(root, wanted, 0) == primary, "свободный слот берётся из Equipment")
	primary.add_child(FakeItem.new())
	ck(VTKData._find_free_slot(root, wanted, 0) == null, "занятый слот не подменяется Label из Hints")
	root.free()

# Регрессия 4.14.1: `_equip_sd` сперва искал свободный слот, и только потом
# вставлял предмет. На занятом слоте предмет вставлялся в inventoryGrid и
# оставался там — повторный Apply каждого предмета плодил дубль и переполнял
# сетку (иконки-призраки поверх HUD). Тест запирает порядок: занят слот —
# узел не создаётся вообще.
func t_equip_sd() -> void:
	var equip_root := Control.new()
	equip_root.name = "Equipment"
	var torso := FakeSlot.new()
	torso.name = "Torso"
	equip_root.add_child(torso)

	var ig := FakeGrid.new()
	var iface := FakeInterface.new()
	var sd := SlotData.new()
	sd.itemData = {"slots": ["Torso"], "name": "Hoodie"}

	ck(VTKData._equip_sd(iface, ig, equip_root, sd, "Torso"), "свободный слот -> экипировано")
	ck(ig.get_child_count() == 0, "узел ушёл из сетки в слот")
	ck(torso.get_child_count() == 1, "предмет лёг в слот")

	var sd2 := SlotData.new()
	sd2.itemData = {"slots": ["Torso"], "name": "Hoodie"}
	ck(not VTKData._equip_sd(iface, ig, equip_root, sd2, "Torso"), "занятый слот -> пропуск")
	ck(ig.get_child_count() == 0, "на занятом слоте дубль не осел в сетке")
	ck(torso.get_child_count() == 1, "слот не тронут")
	equip_root.free()
