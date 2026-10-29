extends SceneTree

const Draft = preload("res://mods/VTK/VTKDraft.gd")
const Data = preload("res://mods/VTK/VTKData.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_slot_of()
	t_slot_label()
	t_gear_increments()
	t_equip_replaces()
	t_remove_scoped()
	t_attachments()
	t_toggle_attachment()
	t_has_attachment()
	t_toggle_guards()
	t_to_saved_and_back()
	t_guards()
	t_add_clamp()
	t_replace_set()
	t_free_slot_of()
	t_add_gear()
	t_bump_amount()
	t_add_gear_step()
	t_add_to_slot()
	t_multi_grenades()
	t_whole_amount()
	t_magazines()
	t_mag_shown_count()
	t_quick_key_unique()
	t_save_file_migration()
	print("")
	if fails == 0:
		print("Draft tests passed")
		quit(0)
	else:
		print("Draft tests failed: ", fails)
		quit(1)

func t_slot_of() -> void:
	ck(Draft.slot_of(["Primary", "Secondary"]) == "Primary", "slot_of берёт первый")
	ck(Draft.slot_of([]) == "", "slot_of пустого массива пустой")
	ck(Draft.slot_of(null) == "", "slot_of null пустой")

func t_free_slot_of() -> void:
	var d = Draft.new()
	ck(d.free_slot_of(["Grenade_1", "Grenade_2"]) == "Grenade_1", "free_slot_of берёт первый свободный")
	d.equip["Grenade_1"] = {"name": "G", "path": "res://g.tres", "amount": 1.0, "type": "Consumable"}
	ck(d.free_slot_of(["Grenade_1", "Grenade_2"]) == "Grenade_2", "free_slot_of идёт ко второму, когда первый занят")
	d.equip["Grenade_2"] = {"name": "G", "path": "res://g.tres", "amount": 1.0, "type": "Consumable"}
	ck(d.free_slot_of(["Grenade_1", "Grenade_2"]) == "", "free_slot_of пуст, когда все заняты")
	ck(d.free_slot_of([]) == "", "free_slot_of пустого массива пустой")
	ck(d.free_slot_of(null) == "", "free_slot_of null пустой")

func t_add_to_slot() -> void:
	var d = Draft.new()
	var w := "res://w_slot.tres"
	var got: String = d.add_to_slot(w, "АКС", ["Primary", "Secondary"], 1.0, "Weapon", "Secondary")
	ck(got == "Secondary", "add_to_slot кладёт в запрошенный слот, а не в первый свободный")
	ck(d.equip.size() == 1, "в экипировке одна запись")
	ck(str(d.equip["Secondary"].get("path")) == w, "в Secondary лежит нужный предмет")
	ck(d.equip.has("Primary") == false, "Primary не тронут")
	ck(float(d.equip["Secondary"].get("amount")) == 1.0, "amount предмета записан")
	ck(str(d.equip["Secondary"].get("name")) == "АКС", "имя предмета записано")
	ck(str(d.equip["Secondary"].get("type")) == "Weapon", "тип предмета записан")
	ck(not d.equip["Secondary"].has("count"), "обычный предмет в слоте не получает count")
	# занятый слот вытесняется, а не дублируется
	var got2: String = d.add_to_slot("res://w_slot2.tres", "ПП", ["Primary", "Secondary"], 1.0, "Weapon", "Secondary")
	ck(got2 == "Secondary", "вытеснение возвращает слот")
	ck(str(d.equip["Secondary"].get("path")) == "res://w_slot2.tres", "новый предмет занял слот")
	ck(d.equip.size() == 1, "вытесненный предмет не остался второй записью")
	ck(d.gear.is_empty(), "вытесненное оружие не уехало в снаряжение")
	# второй слот заполняется отдельно
	ck(d.add_to_slot("res://w_slot3.tres", "ПМ", ["Primary"], 1.0, "Weapon", "Primary") == "Primary",
		"Primary занят вторым предметом")
	ck(d.equip.size() == 2, "в экипировке два слота")
	# слот, которого нет в slots предмета, отклоняется
	ck(d.add_to_slot(w, "АКС", ["Secondary"], 1.0, "Weapon", "Primary") == "",
		"слот вне slots предмета отклоняется")
	# мусорные входы
	ck(d.add_to_slot(w, "АКС", null, 1.0, "Weapon", "Primary") == "", "null slots отклоняется")
	ck(d.add_to_slot(w, "АКС", [], 1.0, "Weapon", "Primary") == "", "пустой slots отклоняется")
	ck(d.add_to_slot(w, "АКС", "Primary", 1.0, "Weapon", "Primary") == "",
		"строка вместо массива отклоняется")
	ck(d.add_to_slot(w, "АКС", ["Primary"], 1.0, "Weapon", "") == "", "пустой слот отклоняется")
	# обойма в слот не кладётся: в слоре живёт amount, а у обоймы нужен count
	ck(d.add_to_slot("res://mag_slot.tres", "Магазин", ["Primary"], 8.0, "Attachment",
		"Primary", true) == "", "обойма в слот не кладётся")
	ck(d.equip.size() == 2 and d.gear.is_empty(), "отказ не изменил черновик")
	# отказ не затирает уже занятый слот: без проверки слота на входе
	# безусловный equip[slot] = ... здесь молча уничтожил бы предмет
	var before := str(d.equip["Primary"].get("path"))
	ck(d.add_to_slot("res://other.tres", "Х", ["Body"], 1.0, "Armor", "Primary") == "",
		"чужой слот-цель отклоняется")
	ck(str(d.equip["Primary"].get("path")) == before, "отказ не тронул занятый слот")
	# amount клампится, как в add()
	d.add_to_slot("res://w_slot4.tres", "АКС-3", ["Head"], -5.0, "Weapon", "Head")
	ck(d.equip.has("Head"), "третий слот занят")
	ck(float(d.equip["Head"].get("amount")) == 0.0, "amount клампится к нулю, как в add()")
	# обвесы вытесненного предмета уходят вместе с ним
	var h = Draft.new()
	h.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	h.set_attachments("res://v.tres", ["res://pso.tres"])
	ck(h.add_to_slot("res://v2.tres", "АК-2", ["Primary"], 1.0, "Weapon", "Primary") == "Primary",
		"оружие вытеснено из Primary")
	ck(not h.descriptor_of("res://v.tres").has("attachments"),
		"вытесненный предмет не оставил обвесов в сете")
	# gear-предмет можно адресно переложить в слот
	var g = Draft.new()
	g.add("res://med.tres", "Аптечка", [], 1.0, "Medical")
	ck(g.add_to_slot("res://med.tres", "Аптечка", ["Body"], 1.0, "Medical", "Body") == "Body",
		"gear-предмет можно адресно переложить в слот")
	ck(g.gear.size() == 1, "при этом запись в gear остаётся - убирает её пользователь")

func t_multi_grenades() -> void:
	var d = Draft.new()
	var gslots = ["Grenade_1", "Grenade_2"]
	var s1 = d.add("res://g.tres", "Граната", gslots, 1.0, "Consumable")
	var s2 = d.add("res://g.tres", "Граната", gslots, 1.0, "Consumable")
	ck(s1 == "Grenade_1", "первая граната в Grenade_1")
	ck(s2 == "Grenade_2", "вторая граната в Grenade_2, а не перезапись")
	ck(d.equip.size() == 2, "две гранаты это две записи экипировки")
	ck(str(d.equip["Grenade_2"].get("path")) == "res://g.tres", "во втором слоте лежит та же граната")
	# третья граната все слоты заняла - уходит в gear, а не затирает слот
	var s3 = d.add("res://g.tres", "Граната", gslots, 1.0, "Consumable")
	ck(s3 == "", "третья граната не попадает в занятый слот")
	ck(d.equip.size() == 2, "экипировка не изменилась после третьей гранаты")
	ck(d.gear_index_of("res://g.tres") >= 0, "третья граната ушла в gear")
	# после освобождения слота сет снова принимает гранату в экипировку
	d.remove_slot("Grenade_1")
	var s4 = d.add("res://g.tres", "Граната", gslots, 1.0, "Consumable")
	ck(s4 == "Grenade_1", "освободившийся слот снова используется")

func t_whole_amount() -> void:
	ck(typeof(Data._whole(116.0)) == TYPE_INT, "целое 116.0 становится int")
	ck(str(Data._whole(116.0)) == "116", "116.0 печатается как 116, без .0")
	ck(str(Data._whole(8.0)) == "8", "8.0 печатается как 8")
	ck(str(Data._whole(1.0)) == "1", "1.0 печатается как 1")
	ck(typeof(Data._whole(0.5)) == TYPE_FLOAT, "0.5 остаётся float")
	ck(str(Data._whole(0.5)) == "0.5", "0.5 не обрезается в 0")
	ck(Data._whole(0.5) != Data._whole(0.0), "0.5 отличается от 0, предмет не исчезнет")
	ck(str(Data._whole(0.0)) == "0", "0.0 печатается как 0")
	ck(str(Data._whole(30)) == "30", "целый int 30 проходит без изменений")
	ck(Data._whole(116.0) == 116 and Data._whole(0.5) == 0.5, "значения равны исходным")

func t_slot_label() -> void:
	ck(Draft.slot_label(["Primary", "Secondary"]) == "Primary, Secondary", "slot_label через запятую")
	ck(Draft.slot_label([]) == "", "slot_label пустого массива пустой")

func t_gear_increments() -> void:
	var d = Draft.new()
	var s := d.add("res://a.tres", "Аптечка", [], 1.0, "Medical")
	ck(s == "", "без слотов слот пустой")
	ck(d.gear.size() == 1, "без слотов предмет уходит в gear")
	ck(d.equip.is_empty(), "без слотов equip пуст")
	d.add("res://a.tres", "Аптечка", [], 1.0, "Medical")
	ck(d.gear.size() == 1, "повторный клик не плодит записи")
	ck(d.amount_of("res://a.tres") == 2.0, "повторный клик даёт +1")

func t_equip_replaces() -> void:
	var d = Draft.new()
	d.add("res://v1.tres", "АК-74М", ["Primary"], 1.0, "Weapon")
	d.add("res://v2.tres", "АК-74ММ", ["Primary", "Secondary"], 1.0, "Weapon")
	ck(d.equip.size() == 2, "оружие с двумя слотами занимает свободный Secondary")
	ck(d.equip.has("Primary"), "слот Primary занят")
	ck(d.equip.has("Secondary"), "слот Secondary занят")
	ck(d.equip["Primary"]["path"] == "res://v1.tres", "в Primary осталось первое оружие")
	ck(d.equip["Secondary"]["path"] == "res://v2.tres", "в Secondary второе")
	ck(d.gear.is_empty(), "оружие не попадает в gear")

	d.remove_slot("Primary")
	d.add("res://v3.tres", "ПМ", ["Primary", "Secondary"], 1.0, "Weapon")
	ck(d.equip.size() == 2, "третье оружие заняло освободившийся Primary")
	ck(d.equip["Primary"]["path"] == "res://v3.tres", "в Primary теперь третье оружие")

func t_remove_scoped() -> void:
	var d = Draft.new()
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.add("res://a.tres", "Аптечка", [], 1.0, "Medical")
	d.remove_slot("Primary")
	ck(d.equip.is_empty(), "remove_slot чистит только слот")
	ck(d.gear.size() == 1, "remove_slot не трогает gear")
	d.remove_gear("res://a.tres")
	ck(d.gear.is_empty(), "remove_gear чистит только gear")

func t_attachments() -> void:
	var d = Draft.new()
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.set_attachments("res://v.tres", ["res://att.tres"])
	ck(d.descriptor_of("res://v.tres").get("attachments", []).size() == 1, "вложение записано в дескриптор")

func _grp_stub() -> Callable:
	# Заглушка вместо load(): группа обвеса приходит снаружи, потому что
	# черновик не грузит ресурсы.
	return func(p: String) -> String:
		if p.contains("pso") or p.contains("koll"):
			return "Sight"
		if p.contains("muz"):
			return "Muzzle"
		if p.contains("grip"):
			return "Grip"
		if p.contains("pouch"):
			return "Pouch"
		return "Other"

func t_toggle_attachment() -> void:
	var d = Draft.new()
	var w := "res://w_att.tres"
	d.add(w, "АКС", ["Primary"], 1.0, "Weapon")
	var grp_of := _grp_stub()
	d.toggle_attachment(w, "res://att_pso.tres", "Sight", grp_of)
	ck(d.descriptor_of(w).get("attachments", []).size() == 1, "первый обвес записан")
	ck(d.descriptor_of(w)["attachments"][0] == "res://att_pso.tres", "в списке путь обвеса")
	d.toggle_attachment(w, "res://att_koll.tres", "Sight", grp_of)
	var a: Array = d.descriptor_of(w).get("attachments", [])
	ck(a.size() == 1, "второй прицел заменил первый, а не добавился")
	ck(str(a[0]) == "res://att_koll.tres", "остался последний выбранный")
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	a = d.descriptor_of(w).get("attachments", [])
	ck(a.size() == 2, "другая группа не вытеснила прицел")
	ck(a.has("res://att_koll.tres"), "коллиматор на месте после выбора дула")
	d.toggle_attachment(w, "res://att_grip.tres", "Grip", grp_of)
	ck((d.descriptor_of(w)["attachments"] as Array).size() == 3, "третья группа добавилась")
	d.toggle_attachment(w, "res://att_koll.tres", "Sight", grp_of)
	a = d.descriptor_of(w).get("attachments", [])
	ck(a.size() == 2 and a.has("res://att_muz.tres") and a.has("res://att_grip.tres"),
		"повторный клик снял прицел, остальные группы не тронуты")
	ck(d.descriptor_of(w).has("attachments"), "пока другие группы есть, ключ остаётся")
	# формат записи не меняется: плоский массив путей, без вложенных словарей
	var flat := true
	for p in a:
		if typeof(p) != TYPE_STRING:
			flat = false
	ck(flat, "attachments остаётся плоским массивом строк")
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	ck(d.descriptor_of(w).get("attachments", []).size() == 1, "второе снятие уменьшило список")
	d.toggle_attachment(w, "res://att_grip.tres", "Grip", grp_of)
	ck(not d.descriptor_of(w).has("attachments"), "пустой список обвесов удаляет ключ целиком")
	# обвесы одинакового типа, но из разных групп, не схлопываются
	d.toggle_attachment(w, "res://att_grip.tres", "Grip", grp_of)
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	ck((d.descriptor_of(w)["attachments"] as Array).size() == 2,
		"одноимённые subtype из разных групп не вытесняют друг друга")


# Проверка выбора по принадлежности, а не по первому элементу списка: у ствола
# одновременно стоят прицел, коллиматор и дуло, и плитки всех трёх должны быть
# золотыми.
func t_has_attachment() -> void:
	var d = Draft.new()
	var w := "res://w_has.tres"
	d.add(w, "АКМ", ["Primary"], 1.0, "Weapon")
	var grp_of := func(p: String) -> String:
		if p.contains("pso"):
			return "Sight"
		if p.contains("koll"):
			return "Collimator"
		if p.contains("muz"):
			return "Muzzle"
		return "Other"
	ck(d.has_attachment(w, "res://att_pso.tres") == false, "без обвесов ничего не выбрано")
	d.toggle_attachment(w, "res://att_pso.tres", "Sight", grp_of)
	d.toggle_attachment(w, "res://att_koll.tres", "Collimator", grp_of)
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	ck(d.has_attachment(w, "res://att_pso.tres"), "прицел помечен")
	ck(d.has_attachment(w, "res://att_koll.tres"), "коллиматор помечен")
	ck(d.has_attachment(w, "res://att_muz.tres"), "дуло помечено")
	ck(d.has_attachment(w, "res://att_grip.tres") == false, "невыбранный обвес не помечен")
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	ck(d.has_attachment(w, "res://att_muz.tres") == false, "снятое дуло больше не помечено")
	ck(d.has_attachment(w, "res://att_pso.tres") and d.has_attachment(w, "res://att_koll.tres"),
		"снятие одного обвеса не снимает остальные")
	ck(d.has_attachment("res://none.tres", "res://att_pso.tres") == false, "чужой предмет даёт false")
	ck(d.has_attachment(w, "") == false, "пустой путь обвеса даёт false")
	d.descriptor_of(w)["attachments"] = "мусор"
	ck(d.has_attachment(w, "res://att_pso.tres") == false, "испорченный список не ломает выбор")

func t_toggle_guards() -> void:
	var d = Draft.new()
	var w := "res://w_g.tres"
	d.add(w, "АКС", ["Primary"], 1.0, "Weapon")
	var grp_of := _grp_stub()
	d.toggle_attachment("res://none.tres", "res://att_pso.tres", "Sight", grp_of)
	ck(d.gear.is_empty() and d.equip.size() == 1, "чужой путь не создаёт запись")
	d.toggle_attachment(w, "", "Sight", grp_of)
	ck(not d.descriptor_of(w).has("attachments"), "пустой путь обвеса игнорируется")
	# сохранённый список, который оказался не массивом, не ломает выбор
	d.descriptor_of(w)["attachments"] = "мусор"
	d.toggle_attachment(w, "res://att_pso.tres", "Sight", grp_of)
	ck((d.descriptor_of(w)["attachments"] as Array) == ["res://att_pso.tres"],
		"испорченный список заменяется, а не наследуется")
	# группа, заявленная вызывающим, сверяется с настоящей: опечатка в разметке
	# панели иначе молча вычистила бы чужую группу обвесов
	d.toggle_attachment(w, "res://att_muz.tres", "Muzzle", grp_of)
	ck((d.descriptor_of(w)["attachments"] as Array).size() == 2, "прицел и дуло лежат рядом")
	d.toggle_attachment(w, "res://att_grip.tres", "Muzzle", grp_of)
	ck(d.descriptor_of(w)["attachments"].has("res://att_grip.tres"),
		"обвес записан в свою группу, а не в заявленную ошибочную")
	ck(d.descriptor_of(w)["attachments"].has("res://att_muz.tres")
		and d.descriptor_of(w)["attachments"].has("res://att_pso.tres"),
		"ошибочная группа не вычистила ни одну из настоящих")
	# обвес работает и для предмета в снаряжении
	var m = Draft.new()
	m.add("res://bag.tres", "Рюкзак", [], 1.0, "Backpack")
	m.toggle_attachment("res://bag.tres", "res://att_pouch.tres", "Other", grp_of)
	ck(m.gear[0].get("attachments", []).size() == 1, "обвес gear-предмета записан")
	# set_attachments поверх toggle остаётся доступным
	var s = Draft.new()
	s.add(w, "АКС", ["Primary"], 1.0, "Weapon")
	s.set_attachments(w, ["res://att_pso.tres", "res://att_muz.tres"])
	ck((s.descriptor_of(w)["attachments"] as Array).size() == 2, "set_attachments не сломали")
	s.toggle_attachment(w, "res://att_grip.tres", "Grip", grp_of)
	ck((s.descriptor_of(w)["attachments"] as Array).size() == 3,
		"toggle поверх set_attachments добавляет в новую группу")
	s.toggle_attachment(w, "res://att_koll.tres", "Sight", grp_of)
	ck((s.descriptor_of(w)["attachments"] as Array).size() == 3,
		"и схлопывает старую группу до одного")

func t_to_saved_and_back() -> void:
	var d = Draft.new("Стрелок")
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.add("res://a.tres", "Аптечка", [], 2.0, "Medical")
	var saved: Dictionary = d.to_saved()
	ck(saved["equip"].size() == 1, "to_saved: один слот")
	ck(saved["gear"].size() == 1, "to_saved: одна запись gear")
	var d2 = Draft.new()
	d2.load_from({"name": "Стрелок", "equip": saved["equip"], "gear": saved["gear"]})
	ck(d2.set_name == "Стрелок", "load_from читает имя")
	ck(d2.item_count() == 2, "load_from восстанавливает состав")

func t_guards() -> void:
	var d = Draft.new()
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	d.add("res://a.tres", "Аптечка", [], 2.0, "Medical")
	ck(d.equip_slot_of("res://v.tres") == "Primary", "equip_slot_of находит занятый слот")
	ck(d.equip_slot_of("res://нет.tres") == "", "equip_slot_of чужого пути пустой")
	ck(d.equip_slot_of("res://a.tres") == "", "equip_slot_of игнорирует gear")
	ck(d.gear_index_of("res://a.tres") == 0, "gear_index_of находит запись")
	ck(d.gear_index_of("res://нет.tres") == -1, "gear_index_of чужого пути минус один")
	ck(d.has_path("res://v.tres"), "has_path видит equip-предмет")
	ck(d.has_path("res://a.tres"), "has_path видит gear-предмет")
	ck(not d.has_path("res://нет.tres"), "has_path не видит неизвестный путь")
	ck(not d.is_empty(), "is_empty до clear ложь")
	ck(d.equip_count() == 1, "equip_count считает занятый слот")
	d.set_gear_amount("res://a.tres", 5.0)
	ck(d.amount_of("res://a.tres") == 5.0, "set_gear_amount пишет положительное значение")
	ck(d.gear_index_of("res://a.tres") >= 0, "set_gear_amount не удаляет запись")
	d.set_gear_amount("res://a.tres", 0.0)
	ck(not d.has_path("res://a.tres"), "set_gear_amount 0.0 удаляет запись")
	ck(d.item_count() == 1, "item_count уменьшился после удаления")
	ck(d.to_saved()["gear"].size() == 0, "to_saved не содержит удалённой записи")
	d.add("res://a.tres", "Аптечка", [], 2.0, "Medical")
	ck(d.item_count() == 2, "предмет вернулся в gear")
	d.set_gear_amount("res://a.tres", -3.0)
	ck(not d.has_path("res://a.tres"), "set_gear_amount с минусом тоже удаление")
	ck(d.item_count() == 1, "item_count уменьшился после удаления по минусу")
	ck(Draft.slot_of(null) == "", "slot_of null пустой")
	ck(Draft.slot_label(null) == "", "slot_label null пустой")
	d.clear()
	ck(d.is_empty(), "is_empty после clear истина")
	ck(d.equip_count() == 0, "equip_count после clear ноль")
	ck(d.item_count() == 0, "item_count после clear ноль")
	var d3 = Draft.new()
	d3.load_from(null)
	ck(d3.item_count() == 0, "load_from не-Dictionary не ломает черновик")
	d3.load_from({"name": "Пусто"})
	ck(d3.equip_count() == 0, "load_from без equip и gear даёт пусто")
	ck(d3.item_count() == 0, "load_from без equip и gear пуст по составу")
	d3.load_from({"name": "Стрелок", "equip": {"Primary": {"path": "res://v.tres", "amount": 1.0}}, "gear": [{"path": "res://a.tres", "amount": 2.0}]})
	ck(d3.set_name == "Стрелок", "load_from с ключами читает имя")
	ck(d3.equip_count() == 1, "load_from с ключами читает equip")
	ck(d3.item_count() == 2, "load_from с ключами читает gear")
	var d4 = Draft.new()
	d4.equip[5] = {"name": "АК", "path": "res://v.tres", "amount": 3.0, "type": "Weapon"}
	ck(d4.equip_slot_of("res://v.tres") == "5", "equip_slot_of отдаёт ключ строкой")
	ck(d4.amount_of("res://v.tres") == 3.0, "amount_of переживает нестроковый ключ")
	ck(d4.descriptor_of("res://v.tres").get("path") == "res://v.tres", "descriptor_of переживает нестроковый ключ")
	ck(d4.has_path("res://v.tres"), "has_path переживает нестроковый ключ")

func t_add_clamp() -> void:
	var g = Draft.new()
	g.add("res://a.tres", "Аптечка", [], -2.0, "Medical")
	ck(g.gear.size() == 1, "add без слотов с минусом всё равно создаёт запись gear")
	ck(g.has_path("res://a.tres"), "add без слотов с минусом не выбрасывает предмет")
	ck(g.amount_of("res://a.tres") == 0.0, "add без слотов клампит минус к нулю")
	ck(float(g.to_saved()["gear"][0]["amount"]) == 0.0, "to_saved несёт amount 0.0 у gear-записи")
	var e = Draft.new()
	e.add("res://v.tres", "АК", ["Primary"], -2.0, "Weapon")
	ck(e.equip.has("Primary"), "add в слот с минусом всё равно создаёт дескриптор")
	ck(e.has_path("res://v.tres"), "add в слот с минусом не выбрасывает предмет")
	ck(e.amount_of("res://v.tres") == 0.0, "add в слот клампит минус к нулю")
	ck(float(e.to_saved()["equip"]["Primary"]["amount"]) == 0.0, "to_saved несёт amount 0.0 у слота")
	var p = Draft.new()
	p.add("res://b.tres", "Бинт", [], 2.0, "Medical")
	ck(p.amount_of("res://b.tres") == 2.0, "add без слотов не режет положительное количество")
	p.add("res://v.tres", "АК", ["Primary"], 4.0, "Weapon")
	ck(p.amount_of("res://v.tres") == 4.0, "add в слот не режет положительное количество")
	var i = Draft.new()
	i.add("res://a.tres", "Аптечка", [], 2.0, "Medical")
	i.add("res://a.tres", "Аптечка", [], -5.0, "Medical")
	ck(i.gear.size() == 1, "повторный add того же gear-пути не плодит записи")
	ck(i.amount_of("res://a.tres") == 3.0, "повторный add даёт ровно +1 независимо от переданного amount")

func t_replace_set() -> void:
	var n := "ZZ_test_replace_set"
	Data.replace_set(n, {"Primary": {"name": "Винтовка", "path": "res://v.tres", "amount": 1.0, "type": "Weapon"}}, [])
	var back := Data.get_set(n)
	ck(back.size() > 0, "replace_set создал набор")
	ck(typeof(back.get("equip")) == TYPE_DICTIONARY and back["equip"].has("Primary"), "replace_set записал equip")
	Data.set_quick_key(n, 65)
	Data.replace_set(n, {}, [{"name": "Аптечка", "path": "res://a.tres", "amount": 3.0, "type": "Medical"}])
	back = Data.get_set(n)
	ck(back["equip"].is_empty(), "второй replace_set очистил equip")
	ck(back["gear"].size() == 1, "второй replace_set записал gear")
	ck(int(back["gear"][0]["amount"]) == 3, "второй replace_set выставил amount gear")
	ck(int(back.get("quick_key", 0)) == 65, "replace_set не затирает quick_key")
	Data.remove(n)
	ck(Data.get_set(n).is_empty(), "remove убрал тестовый набор")

func t_quick_key_unique() -> void:
	var a := "ZZ_test_qk_a"
	var b := "ZZ_test_qk_b"
	Data.replace_set(a, {}, [])
	Data.replace_set(b, {}, [])
	Data.set_quick_key_unique(a, 66)
	ck(int(Data.get_set(a).get("quick_key", 0)) == 66, "set_quick_key_unique назначил клавишу")
	ck(Data.get_name_by_quick_key(66) == a, "уникальная клавиша находится по коду")
	Data.set_quick_key_unique(b, 66)
	ck(int(Data.get_set(b).get("quick_key", 0)) == 66, "клавиша перешла второму сету")
	ck(int(Data.get_set(a).get("quick_key", 0)) == 0, "у первого сета клавиша снята")
	ck(Data.get_name_by_quick_key(66) == b, "по коду теперь отдаётся новый владелец")
	Data.set_quick_key_unique(b, 0)
	ck(int(Data.get_set(b).get("quick_key", 0)) == 0, "0 снимает клавишу")
	Data.remove(a)
	Data.remove(b)

func t_magazines() -> void:
	var mag := "res://mag.tres"
	var d = Draft.new()
	d.add(mag, "Обойма", [], 8.0, "Attachment", true)
	ck(d.gear.size() == 1, "обойма падает в gear, а не в слот")
	var desc: Dictionary = d.gear[0]
	ck(int(desc.get("count", 0)) == 1, "обойма сохранена как count 1, а не amount 8")
	ck(float(desc.get("amount", -1.0)) == 0.0, "amount обоймы не хранит патроны")
	ck(d.amount_of(mag) == 1.0, "amount_of показывает число обойм")
	d.add(mag, "Обойма", [], 8.0, "Attachment", true)
	ck(d.gear.size() == 1, "повторный add обоймы не плодит записи")
	ck(d.amount_of(mag) == 2.0, "повторный add обоймы даёт +1 обойму")
	d.set_gear_amount(mag, 3.0)
	ck(d.amount_of(mag) == 3.0, "set_gear_amount пишет в count обойки")
	ck(int(d.gear[0].get("count", 0)) == 3, "count обоймы остался целым")
	ck(float(d.gear[0].get("amount", -1.0)) == 0.0, "set_gear_amount не пишет в amount обоймы")
	d.set_gear_amount(mag, 0.0)
	ck(d.gear.is_empty(), "обойма до нуля удаляется")
	var back: Dictionary = d.to_saved()
	ck(typeof(back["gear"]) == TYPE_ARRAY and back["gear"].is_empty(), "to_saved пережил удаление обоймы")
	var old = Draft.new()
	old.gear = [{"name": "Старая обойма", "path": mag, "amount": 8.0, "type": "Attachment"}]
	ck(old.amount_of(mag) == 8.0, "старый descriptor без count читается как прежде — amount в патронах")
	ck(not old.gear[0].has("count"), "старый descriptor не получает count задним числом")
	var n := "ZZ_test_mag_set"
	Data.replace_set(n, {}, [{"name": "Обойма", "path": mag, "amount": 0.0, "count": 2, "type": "Attachment"}])
	var got: Dictionary = Data.get_set(n)
	ck(int(got["gear"][0].get("count", 0)) == 2, "count пережил сохранение в loadouts.json")
	ck(float(got["gear"][0].get("amount", -1.0)) == 0.0, "amount 0 пережил сохранение")
	Data.remove(n)

func _wipe_sets() -> void:
	DirAccess.make_dir_recursive_absolute("user://MCM/vostok-toolkit")
	for p in ["user://MCM/vostok-toolkit/loadouts.json", "user://MCM/vostok-toolkit/loadouts.json.bak",
			"user://MCM/vostok-toolkit/VTKsets.json", "user://MCM/vostok-toolkit/VTKsets.json.bak"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _put(path: String, text: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _slurp(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	var t := f.get_as_text()
	f.close()
	return t

func t_save_file_migration() -> void:
	ck(str(Data.SAVE_FILE).ends_with("VTKsets.json"), "SAVE_FILE указывает на VTKsets.json")
	ck(str(Data.LEGACY_SAVE_FILE).ends_with("loadouts.json"),
		"LEGACY_SAVE_FILE указывает на старое имя")
	_wipe_sets()
	ck(not FileAccess.file_exists(Data.SAVE_FILE), "VTKsets.json удалён перед тестом")

	var payload := '{"loadouts":[{"name":"ZZ_mig","quick_key":0,"equip":{},"gear":[]}]}'
	_put(Data.LEGACY_SAVE_FILE, payload)
	_put(Data.LEGACY_SAVE_FILE + ".bak", payload)
	Data.migrate_save_file()
	ck(FileAccess.file_exists(Data.SAVE_FILE), "loadouts.json перенесён в VTKsets.json")
	ck(FileAccess.file_exists(Data.SAVE_FILE + ".bak"), "loadouts.json.bak перенесён")
	ck(not FileAccess.file_exists(Data.LEGACY_SAVE_FILE), "старый loadouts.json удалён")
	ck(not FileAccess.file_exists(Data.LEGACY_SAVE_FILE + ".bak"), "старый .bak удалён")
	ck(_slurp(Data.SAVE_FILE) == payload, "содержимое перенесено байт в байт")
	ck(_slurp(Data.SAVE_FILE + ".bak") == payload, "содержимое .bak перенесено байт в байт")
	ck(Data.names().has("ZZ_mig"), "перенесённый сет читается через names()")
	Data.remove("ZZ_mig")
	ck(not Data.names().has("ZZ_mig"), "удаление после миграции работает")

	# повторный вызов не трогает уже перенесённый файл и не съедает живое
	var keep := '{"loadouts":[{"name":"ZZ_keep","quick_key":0,"equip":{},"gear":[]}]}'
	_put(Data.SAVE_FILE, keep)
	_put(Data.LEGACY_SAVE_FILE, '{"loadouts":[]}')
	Data.migrate_save_file()
	ck(_slurp(Data.SAVE_FILE) == keep, "повторный вызов не перетирает живой файл")
	ck(FileAccess.file_exists(Data.LEGACY_SAVE_FILE), "при живом новом файле старое имя не трогаем")
	ck(Data.names().has("ZZ_keep"), "живой набор на месте после повторного вызова")

	# только .bak без основного файла - тоже переносится
	_wipe_sets()
	_put(Data.LEGACY_SAVE_FILE + ".bak", payload)
	Data.migrate_save_file()
	ck(FileAccess.file_exists(Data.SAVE_FILE + ".bak"), "одинокий .bak тоже перенесён")
	ck(not FileAccess.file_exists(Data.SAVE_FILE), "основной файл не создан из .bak")

	# ничего нет - вызов не падает и ничего не создаёт
	_wipe_sets()
	Data.migrate_save_file()
	ck(not FileAccess.file_exists(Data.SAVE_FILE), "без старого файла миграция ничего не создаёт")
	_wipe_sets()

func t_mag_shown_count() -> void:
	# Именно то, из-за чего количество обойм не отображалось: UI читал сырой
	# amount, а у обоймы он служебный 0.
	ck(Draft.shown_count({"count": 1, "amount": 0.0}) == 1, "shown_count обоймы берёт count, а не amount 0")
	ck(Draft.shown_count({"count": 3, "amount": 0.0}) == 3, "shown_count обоймы показывает выбранное количество")
	ck(Draft.shown_count({"amount": 116.0}) == 116, "shown_count обычного предмета читает amount")
	ck(Draft.shown_count({"amount": 0.5}) == 1, "shown_count округляет дробный amount")
	ck(Draft.shown_count({}) == 0, "shown_count пустого descriptor равно 0")
	ck(Draft.shown_count(null) == 0, "shown_count null равен 0")
	var mag := "res://mag2.tres"
	var d = Draft.new()
	d.add(mag, "Обойма", [], 8.0, "Attachment", true)
	ck(Draft.shown_count(d.descriptor_of(mag)) == 1, "свежая обойма показывается как 1")
	d.set_gear_amount(mag, 4.0)
	ck(Draft.shown_count(d.descriptor_of(mag)) == 4, "после четырёх плюсов обойма показывается как 4")
	ck(Draft.is_full(d.descriptor_of(mag)) == true, "новая обойма по умолчанию полная")
	d.set_full_mag(mag, false)
	ck(Draft.is_full(d.descriptor_of(mag)) == false, "тумблер снимает заполнение")
	ck(Draft.shown_count(d.descriptor_of(mag)) == 4, "тумблер не сбивает количество обойм")
	d.set_gear_amount(mag, 2.0)
	ck(Draft.shown_count(d.descriptor_of(mag)) == 2, "минус уменьшает число обойм")
	ck(Draft.is_full(d.descriptor_of(mag)) == false, "минус не включает заполнение обратно")
	ck(Draft.is_full({"count": 1}) == true, "descriptor без full_mag считается полным — ВКЛ по умолчанию")
	ck(Draft.is_full({"count": 1, "full_mag": false}) == false, "явный false уважается")
	ck(Draft.is_full({}) == true, "пустой descriptor полный по умолчанию")
	d.set_full_mag("res://none.tres", false)
	ck(d.gear.size() == 1, "set_full_mag по чужому пути не создаёт запись")

# Шаг 2: клик по предмету на вкладке «Снаряжение» кладёт его в рюкзак, минуя
# free_slot_of. Регрессия: граната/оружие/броня уезжали в снаряжение, потому
# что add() первым делом занимал свободный слот.
func t_add_gear() -> void:
	var d = Draft.new()
	var g := "res://gear_grenade.tres"
	d.add_gear(g, "Граната", 1.0, "Consumable")
	ck(d.equip.is_empty(), "add_gear не занимает слот экипировки")
	ck(d.gear.size() == 1, "add_gear кладёт предмет в снаряжение")
	ck(d.gear_index_of(g) == 0, "add_gear пишет по указанному пути")
	# slots у предмета игнорируются: слот-цель шага 2 пуст
	var w := "res://gear_weapon.tres"
	d.add_gear(w, "АК", 1.0, "Weapon")
	ck(d.equip.is_empty(), "оружие со слотами тоже идёт в снаряжение")
	ck(d.gear.size() == 2, "оружие добавилось второй записью")
	# повторный клик копит, а не плодит записи
	d.add_gear(w, "АК", 1.0, "Weapon")
	ck(d.gear.size() == 2, "повторный add_gear не плодит записи")
	ck(d.amount_of(w) == 2.0, "повторный add_gear даёт +1")
	# обойма: count, а не amount
	var mag := "res://gear_mag.tres"
	d.add_gear(mag, "Обойма", 8.0, "Attachment", true)
	var desc: Dictionary = d.descriptor_of(mag)
	ck(int(desc.get("count", 0)) == 1, "add_gear обоймы пишет count 1")
	ck(float(desc.get("amount", -1.0)) == 0.0, "add_gear обоймы не хранит патроны в amount")
	ck(Draft.is_full(desc) == true, "новая обойма из add_gear полная")
	# минус клампится, как в add()
	var a = Draft.new()
	a.add_gear("res://gear_med.tres", "Аптечка", -3.0, "Medical")
	ck(a.gear.size() == 1, "add_gear с минусом создаёт запись")
	ck(a.amount_of("res://gear_med.tres") == 0.0, "add_gear с минусом клампит к нулю")
	# регрессия: старый add по-прежнему занимает слот первым (шаг 1 не сломан)
	var r = Draft.new()
	r.add("res://slot_w.tres", "АК", ["Primary"], 1.0, "Weapon")
	ck(r.equip.has("Primary"), "add всё ещё занимает слот")
	ck(r.gear.is_empty(), "add не увёл предмет в снаряжение при свободном слоте")

# Шаг «+/−» в клетке снаряжения. Пол по умолчанию 1: «−» не удаляет запись,
# удаление только через ✕. Патроны передают пол 0: на последней коробке «−»
# убирает запись. Потолок задаёт вызывающий: патроны - maxAmount, обоймы - 99.
func t_bump_amount() -> void:
	var ammo := "res://ammo_bump.tres"
	var d = Draft.new()
	d.add_gear(ammo, "5.45x39", 30.0, "Ammo")
	ck(d.amount_of(ammo) == 30.0, "bump_amount: первая коробка ложится как amount 30")
	d.bump_amount(ammo, 1.0, 30.0, 300.0)
	ck(d.amount_of(ammo) == 60.0, "bump_amount прибавляет шаг, а не 1")
	d.bump_amount(ammo, 1.0, 30.0, 300.0)
	ck(d.amount_of(ammo) == 90.0, "bump_amount шагает коробками дальше")
	d.bump_amount(ammo, 1.0, 300.0, 300.0)
	ck(d.amount_of(ammo) == 300.0, "bump_amount не превышает потолок")
	d.bump_amount(ammo, 1.0, 300.0, 300.0)
	ck(d.amount_of(ammo) == 300.0, "bump_amount на потолке остаётся на потолке")
	d.bump_amount(ammo, -1.0, 300.0, 300.0)
	ck(d.amount_of(ammo) == 1.0, "bump_amount вниз клампится к 1, не удаляет")
	d.bump_amount(ammo, -1.0, 30.0, 300.0)
	ck(d.amount_of(ammo) == 1.0, "bump_amount ниже единицы не идёт")
	ck(d.gear_index_of(ammo) >= 0, "bump_amount не выбрасывает запись на полу")
	# пол 0 (патроны со стороны UI): «−» на последней коробке убирает запись
	var z = Draft.new()
	z.add_gear(ammo, "5.45x39", 30.0, "Ammo")
	z.bump_amount(ammo, 1.0, 30.0, 300.0, 0.0)
	ck(z.amount_of(ammo) == 60.0, "bump_amount с полом 0 вверх работает как обычно")
	z.bump_amount(ammo, -1.0, 30.0, 300.0, 0.0)
	ck(z.amount_of(ammo) == 30.0, "bump_amount с полом 0 убавляет коробку")
	z.bump_amount(ammo, -1.0, 30.0, 300.0, 0.0)
	ck(not z.has_path(ammo), "bump_amount с полом 0 убирает патроны на последней коробке")
	ck(z.gear.is_empty(), "gear пуст после удаления патронов на последней коробке")
	# потолок всё ещё главнее пола: с полом 0 вверх не выше cap
	var q = Draft.new()
	q.add_gear(ammo, "5.45x39", 30.0, "Ammo")
	q.bump_amount(ammo, 1.0, 30.0, 30.0, 0.0)
	ck(q.amount_of(ammo) == 30.0, "bump_amount с полом 0 не пробивает потолок")
	# обоймы: потолок 99, шаг 1
	var mag := "res://mag_bump.tres"
	var m = Draft.new()
	m.add_gear(mag, "Обойма", 8.0, "Attachment", true)
	m.bump_amount(mag, 1.0, 1.0, 99.0)
	ck(m.amount_of(mag) == 2.0, "bump_amount обоймы прибавляет одну обойму")
	m.bump_amount(mag, -1.0, 1.0, 99.0)
	ck(m.amount_of(mag) == 1.0, "bump_amount обоймы убавляет до 1")
	# cap = 0 значит "без потолка"
	var med := "res://med_bump.tres"
	var c = Draft.new()
	c.add_gear(med, "Аптечка", 1.0, "Medical")
	c.bump_amount(med, 1.0, 1.0, 0.0)
	ck(c.amount_of(med) == 2.0, "bump_amount без потолка растёт свободно")

# Патроны в снаряжение попадают коробкой и коробкой же шагают при повторном
# клике. Прочие предметы остаются на правиле «ровно +1» (шаг по умолчанию 0).
func t_add_gear_step() -> void:
	var ammo := "res://ammo_step.tres"
	var d = Draft.new()
	d.add_gear(ammo, "5.45x39", 30.0, "Ammo", false, 30.0, 300.0)
	ck(d.amount_of(ammo) == 30.0, "клик по патронам кладёт коробку")
	d.add_gear(ammo, "5.45x39", 30.0, "Ammo", false, 30.0, 300.0)
	ck(d.amount_of(ammo) == 60.0, "повторный клик прибавляет коробку, а не 1")
	for i in range(20):
		d.add_gear(ammo, "5.45x39", 30.0, "Ammo", false, 30.0, 300.0)
	ck(d.amount_of(ammo) == 300.0, "клик по патронам упирается в потолок 300")
	# без step повтор по-прежнему +1 (правило не сломано)
	var med := "res://med_step.tres"
	var p = Draft.new()
	p.add_gear(med, "Аптечка", 1.0, "Medical")
	p.add_gear(med, "Аптечка", 50.0, "Medical")
	ck(p.amount_of(med) == 2.0, "add_gear без step на повтор даёт +1")
	# add() с step всё ещё занимает свободный слот
	var w := "res://w_step.tres"
	var s: String = p.add(w, "АК", ["Primary"], 1.0, "Weapon", false, 1.0, 0.0)
	ck(s == "Primary", "add с step заполняет слот как прежде")
	# обойма: шаг не влияет, считаются штуки
	var mag := "res://mag_step.tres"
	var m = Draft.new()
	m.add_gear(mag, "Обойма", 8.0, "Attachment", true, 30.0, 300.0)
	m.add_gear(mag, "Обойма", 8.0, "Attachment", true, 30.0, 300.0)
	ck(m.amount_of(mag) == 2.0, "step не влияет на счёт обойм")
