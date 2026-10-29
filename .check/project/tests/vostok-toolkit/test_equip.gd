extends SceneTree

const E = preload("res://mods/VTK/VTKEquip.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _matches() -> Dictionary:
	return {"file": "Matches", "name": "Matches", "slots": ["Matches"], "stackable": true, "maxAmount": 300}

func _rifle() -> Dictionary:
	return {"file": "AKM", "name": "AKM", "slots": ["Primary"]}

func _boots() -> Dictionary:
	return {"file": "Boots", "name": "Boots", "slots": ["Feet"]}

func _init() -> void:
	t_slots()
	t_decide()
	t_split()
	t_move()
	print("")
	if fails == 0:
		print("Equip tests passed")
		quit(0)
	else:
		print("Equip tests failed: ", fails)
		quit(1)

func t_slots() -> void:
	ck(E.is_equipment(_rifle()), "оружие со слотами -> экипировка")
	ck(not E.is_equipment({"file": "Beer", "slots": []}), "без слотов -> не экипировка")
	ck(not E.is_equipment(null), "null -> не экипировка")
	ck(E.slot_names(_matches()) == ["Matches"], "slot_names читает слоты")
	var w := E.wanted_slots(_rifle())
	ck(w.has("primary"), "wanted_slots приводит к нижнему регистру")

func t_decide() -> void:
	ck(E.decide(_rifle(), null) == "equip", "свободный слот -> equip")
	ck(E.decide(_matches(), _matches()) == "merge", "тот же стакающийся -> merge")
	ck(E.decide(_boots(), _boots()) == "skip", "тот же нестакающийся -> skip")
	ck(E.decide(_rifle(), _boots()) == "skip", "другой предмет -> skip")
	ck(E.decide(null, null) == "skip", "null -> skip")

func t_split() -> void:
	ck(E.split_share(40) == 20, "split(40) -> 20")
	ck(E.split_share(21) == 10, "split(21) -> 10 (округляем вниз до целого)")
	ck(E.split_share(1) == 0, "split(1) -> 0")
	ck(E.take_share(10) == 10, "take_share берёт defaultAmount")

func t_move() -> void:
	ck(E.equip_space(300, 0) == 300, "свободный слот -> все доступно")
	ck(E.equip_space(300, 295) == 5, "места = ёмкость - занято")
	ck(E.equip_space(300, 300) == 0, "полный слот -> 0")
	ck(E.equip_space(0, 0) == -1, "нет ёмкости (не экипировочный) -> -1")
	ck(E.equip_move(20, 0, 300) == 20, "влезает целиком")
	ck(E.equip_move(20, 295, 300) == 5, "климпится по свободному месту")
	ck(E.equip_move(20, 300, 300) == 0, "нет места -> 0")
	ck(E.equip_move(1, 0, 0) == 1, "не экипировочный но взяли бы")
	ck(E.equip_move(-3, 0, 300) == 0, "отрицательное -> 0")