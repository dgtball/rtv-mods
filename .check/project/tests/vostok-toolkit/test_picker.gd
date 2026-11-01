extends SceneTree

const P = preload("res://mods/VTK/VTKPicker.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_all_slots()
	t_equip_layout()
	t_matches_slot()
	t_matches_search()
	t_equip_group_of()
	t_equip_subs_of()
	t_inventory_group_of()
	t_type_groups()
	t_unknown_folder_no_chip()
	t_buckets()
	t_buckets_multi()
	t_subcategory_of()
	t_order_subcategories()
	t_furn_subcategories()
	t_merged_subcategories()
	t_att_panel_needed()
	t_group_attachments()
	t_item_art()
	t_art_key_by_path()
	t_art_cache_cleared()
	t_clear_caches_independent()
	print("")
	if fails == 0:
		print("Picker tests passed")
		quit(0)
	else:
		print("Picker tests failed: ", fails)
		quit(1)

func t_all_slots() -> void:
	var got := P.all_slots([["Primary", "Secondary"], ["Head"], ["Head"], null, "Primary"])
	ck(got == ["Primary", "Secondary", "Head"], "слоты в предпочтительном порядке, без дублей")
	ck(P.all_slots([]).is_empty(), "пустой список даёт пустой результат")
	ck(P.all_slots([null, [""], [null]]).is_empty(), "мусорные значения игнорируются")
	var extra := P.all_slots([["Head"], ["Zzz"], ["Альт"]])
	ck(extra.size() == 3 and str(extra[0]) == "Head", "известные слоты идут первыми")
	ck(str(extra[1]) != "Head", "новый слот не потерялся")
	ck(str(extra[1]) == "Zzz" and str(extra[2]) == "Альт", "неизвестные слоты по алфавиту в конце")
	# предпочтительного слота, которого в данных нет, в списке не появляется:
	# после обновления игры пустых строк не прибавится
	ck(not P.all_slots([["Head"]]).has("Radio"), "слот без предметов в списке не показывается")

func t_equip_layout() -> void:
	var all := P.SLOT_ORDER.duplicate()
	var got := P.equip_layout(all)
	ck(int(got.get("cols", 0)) == 6 and int(got.get("rows", 0)) == 8, "сетка 6×8")
	var cells: Array = got.get("cells", [])
	ck(cells.size() == P.SLOT_ORDER.size(), "раскладка не теряет и не дублирует слоты")
	var seen := {}
	var spans_ok := true
	var by := {}
	for c in cells:
		seen[str(c[0])] = true
		by[str(c[0])] = c
		if int(c[1]) < 0 or int(c[2]) < 0 or int(c[1]) + int(c[3]) > 6 or int(c[2]) + int(c[4]) > 8:
			spans_ok = false
	ck(spans_ok, "клетки не выходят за сетку 6×8")
	for s in P.SLOT_ORDER:
		ck(seen.has(str(s)), "слот " + str(s) + " есть в раскладке")
	var pr: Array = by["Primary"]
	var se: Array = by["Secondary"]
	ck(int(pr[1]) == 0 and int(pr[3]) == 2 and int(pr[4]) == 6, "Primary 2×6 в левом столбце")
	ck(int(se[1]) == 4 and int(se[3]) == 2 and int(se[4]) == 4, "Secondary 2×4 в правом столбце")
	var he: Array = by["Helmet"]
	var ri: Array = by["Rig"]
	var pa: Array = by["Backpack"]
	ck(int(he[2]) == 0 and int(ri[2]) == 2 and int(pa[2]) == 4, "броня Helmet/Rig/Backpack сверху вниз")
	var kn: Array = by["Knife"]
	ck(int(kn[3]) == 2 and int(kn[4]) == 1, "нож горизонтально 2×1")
	var g1: Array = by["Grenade_1"]
	var g2: Array = by["Grenade_2"]
	ck(int(g1[2]) == 5 and int(g2[2]) == 5, "гранаты в одном ряду под ножом")
	var one := P.equip_layout(["Head"])
	var one_cells: Array = one.get("cells", [])
	ck(one_cells.size() == 1 and str(one_cells[0][0]) == "Head", "недостающие слоты выпадают")
	ck(P.equip_layout([]).get("cells", []).is_empty(), "пустой каталог даёт пустую раскладку")
	# Инвариант раскладки: клетку, которую сетка рисует, шаг 1 обязан уметь
	# заполнить. Слот в EQUIP_GRID без группы в EQUIP_SLOT_GROUPS даёт
	# кликабельную клетку и "Nothing fits" на любой клик - так выпал Player
	# (кассетный плеер).
	var grid := {}
	for row in P.EQUIP_GRID:
		grid[str(row[0])] = true
		ck(P.EQUIP_SLOT_GROUPS.has(str(row[0])), "у клетки сетки есть группа шага 1: " + str(row[0]))
	for key in P.EQUIP_SLOT_GROUPS.keys():
		ck(grid.has(str(key)), "группа шага 1 не висит без клетки сетки: " + str(key))

func t_matches_slot() -> void:
	ck(P.matches_slot(["Primary", "Secondary"], "Secondary") == true, "слот из списка подходит")
	ck(P.matches_slot(["Primary"], "Head") == false, "чужой слот не подходит")
	ck(P.matches_slot(["Head"], "Head") == true, "одиночный слот работает")
	ck(P.matches_slot(null, "Head") == false, "null slots не подходит ни к чему")
	ck(P.matches_slot("Primary", "Primary") == false, "строка вместо массива не считается слотами")
	ck(P.matches_slot(null, "") == true, "пустой слот-цель подходит всему")
	ck(P.matches_slot(["Head"], "") == true, "без цели фильтр слота выключен")

func t_matches_search() -> void:
	ck(P.matches_search("Аптечка", "") == true, "пустой запрос подходит всему")
	ck(P.matches_search("Аптечка", "   ") == true, "запрос из пробелов считается пустым")
	ck(P.matches_search("Аптечка", "апт") == true, "поиск без учёта регистра")
	ck(P.matches_search("Аптечка", "АПТ") == true, "поиск в верхнем регистре находит")
	ck(P.matches_search("Аптечка", "  апт  ") == true, "запрос обрезается по краям")
	ck(P.matches_search("Аптечка", "нож") == false, "чужое слово не подходит")
	ck(P.matches_search("Аптечка", "ечк") == true, "совпадение в середине слова")
	ck(P.matches_search("", "апт") == false, "пустое имя не совпадает ни с чем")

func t_att_panel_needed() -> void:
	ck(P.att_panel_needed({"compatible": [{"name": "ПСО"}]}) == true, "есть compatible - панель нужна")
	ck(P.att_panel_needed({"compatible": []}) == false, "пустой compatible - панель не нужна")
	ck(P.att_panel_needed({"maxAmount": 8}) == false, "maxAmount без обвесов - панель не нужна")
	ck(P.att_panel_needed({"maxAmount": 0}) == false, "нулевой maxAmount - панель не нужна")
	ck(P.att_panel_needed({}) == false, "пустой info - панели нет")
	ck(P.att_panel_needed(null) == false, "null - панели нет")
	ck(P.att_panel_needed({"compatible": null}) == false, "compatible не массив - панели нет")
	ck(P.att_panel_needed({"compatible": [{"name": "ПСО"}], "maxAmount": 8}) == true,
		"обвесы при непустом maxAmount - панель нужна")

func t_group_attachments() -> void:
	var atts := [
		{"path": "res://pso.tres", "name": "ПСО-1", "subtype": "Sight"},
		{"path": "res://koll.tres", "name": "ПК-01", "subtype": "Sight"},
		{"path": "res://muz.tres", "name": "Дуло", "subtype": "Muzzle"},
		{"path": "res://grip.tres", "name": "Цевьё", "subtype": "Grip"},
	]
	var got := P.group_attachments(atts)
	ck(got.size() == 3, "три группы: Оптика, Дуло, Цевьё")
	ck(str(got[0]["grp"]) == "Sight", "прицелы в одной группе")
	ck((got[0]["items"] as Array).size() == 2, "два прицела в группе")
	ck(str(got[1]["grp"]) == "Muzzle", "вторая группа - дуло")
	var no_sub := P.group_attachments([{"path": "res://x.tres", "name": "Х"}])
	ck(str(no_sub[0]["grp"]) == "Other", "без subtype группа Other")
	ck(P.group_attachments([]).is_empty(), "пустой список даёт пустые группы")
	ck(P.group_attachments([null, {"name": "без пути"}, {"path": "", "name": "пусто"}]).is_empty(),
		"элементы без пути отбрасываются")
	ck((P.group_attachments([{"path": "res://a.tres", "subtype": ""}])[0]["items"] as Array).size() == 1,
		"пустой subtype не теряет обвес")

func t_item_art() -> void:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(10, 12, 40, 20), Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	var art := P.item_art(tex)
	ck(art is AtlasTexture, "item_art режет прозрачные поля")
	var region: Rect2 = (art as AtlasTexture).region
	ck(region.position == Vector2(7, 9), "item_art кроп: позиция +3")
	ck(region.size == Vector2(46, 26), "item_art кроп: размер +3")
	ck(P.item_art(tex) == art, "item_art кэшируется по экземпляру")
	ck(P.item_art(null) == null, "item_art: null-безопасность")
	var rot := P.item_art(tex, true)
	ck(rot is ImageTexture, "item_art с поворотом отдаёт ImageTexture")
	ck(rot.get_width() == 26 and rot.get_height() == 46,
		"item_art поворот 90° меняет стороны кропа")
	ck(P.item_art(tex, true) == rot, "повёрнутый item_art кэшируется отдельно")
	ck(P.item_art(tex) != rot, "поворот и без поворота - разные записи кэша")

func t_art_key_by_path() -> void:
	# Ключ кеша - resource_path: путь стабилен между перезагрузками каталога,
	# instance_id - адрес объекта, после перезагрузки мог достаться чужой
	# текстуре. Движок не даёт двум ресурсам владеть одним путём разом, поэтому
	# сценарий перезагрузки: первая отдаёт путь, новая его подхватывает и
	# обязана взять уже собранный кроп (у неё другой instance_id).
	P.clear_cache()
	var img_a := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img_a.fill(Color(1, 0, 0, 1))
	var a := ImageTexture.create_from_image(img_a)
	a.resource_path = "res://test_icon_a.png"
	var art_a := P.item_art(a)
	ck(art_a is AtlasTexture, "первая текстура с путём кропается и кешируется")
	var img_b := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img_b.fill(Color(0, 1, 0, 1))
	var b := ImageTexture.create_from_image(img_b)
	a.resource_path = ""
	b.resource_path = "res://test_icon_a.png"
	var art_b := P.item_art(b)
	ck(art_b == art_a, "новая текстура с прежним путём берётся из кеша по пути")

func t_art_cache_cleared() -> void:
	# clear_cache чистит кроп и подкатегории и безопасен на повторном вызове.
	P.clear_cache()
	P.clear_cache()
	ck(P.subcategory_of("res://test_x.tres", "Weapon") == "", "после чистки таблицы пусты и не бросают")
	var img_a := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img_a.fill(Color(1, 0, 0, 1))
	var a := ImageTexture.create_from_image(img_a)
	a.resource_path = "res://test_icon_clear.png"
	var art_a := P.item_art(a)
	var rot := P.item_art(a, true)
	ck(rot != art_a, "повёрнутый кроп - отдельная запись")
	P.clear_cache()
	var art_a2 := P.item_art(a)
	ck(art_a2 != art_a, "после clear_cache кроп пересобирается заново")
	# Текстуры без пути кеш работает по instance_id.
	var img_n := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img_n.fill(Color(0, 0, 1, 1))
	var n := ImageTexture.create_from_image(img_n)
	var art_n := P.item_art(n)
	ck(P.item_art(n) == art_n, "без пути кеш по instance_id держит")

func t_clear_caches_independent() -> void:
	P.clear_cache()
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 0, 1))
	var n := ImageTexture.create_from_image(img)
	n.resource_path = "res://test_clear.png"
	var art1 := P.item_art(n)
	var sub1 := P.subcategory_of("res://test_clear.tres", "Weapon")
	P.clear_art_cache()
	ck(P.item_art(n) != art1, "clear_art_cache сбрасывает кроп")
	var sub2 := P.subcategory_of("res://test_clear.tres", "Weapon")
	ck(sub2 == sub1, "clear_art_cache не трогает subcat_cache")
	P.clear_subcat_cache()
	var art2 := P.item_art(n)
	ck(art2 == P.item_art(n), "clear_subcat_cache не трогает art_cache")
	P.clear_cache()
	ck(P.subcategory_of("res://test_clear.tres", "Weapon") == sub1, "clear_cache пересчитывает подкатегорию заново")
	P.clear_cache()

func t_equip_group_of() -> void:
	ck(P.equip_group_of("Weapon", ["Primary"]) == "weapon", "оружие в Primary -> Weapons")
	ck(P.equip_group_of("Weapon", ["Primary", "Secondary"]) == "weapon", "два слота оружия -> Weapons")
	ck(P.equip_group_of("Clothing", ["Head"]) == "clothing", "шапка -> Clothing")
	ck(P.equip_group_of("Electronics", ["Light"]) == "gear", "фонарик -> Gear")
	ck(P.equip_group_of("Misc", ["Matches"]) == "gear", "спички -> Gear")
	ck(P.equip_group_of("Electronics", ["Player"]) == "gear", "кассетный плеер в слоте Player -> Gear")
	ck(P.equip_group_of("Fishing", ["Primary", "Secondary"]) == "hobby", "удилище -> Hobby, не Weapons")
	ck(P.equip_group_of("Instrument", ["Primary", "Secondary"]) == "hobby", "гитара -> Hobby")
	ck(P.equip_group_of("Ammo", []) == "", "патроны без слота на шаге 1 не показываются")
	ck(P.equip_group_of("Armor", ["Armor"]) == "", "бронеплита вне слотов шага 1")
	ck(P.equip_group_of(null, null) == "", "без type и слотов - вне шага 1")
	ck(P.equip_group_of("Weapon", "Primary") == "", "строка вместо массива слотов не считается")
	ck(P.equip_group_of("Weapon", [null, "Zzz"]) == "", "мусор и незнакомый слот группы не дают")
	ck(P.group_keys(P.EQUIP_GROUPS) == ["weapon", "clothing", "gear", "hobby"], "порядок групп шага 1")
	ck(P.group_label(P.EQUIP_GROUPS, "gear") == "Gear", "подпись группы шага 1")

func t_equip_subs_of() -> void:
	ck(P.equip_subs_of("Weapon", ["Primary", "Secondary"]) == ["Primary", "Secondary"], "пистолет в двух слотах")
	ck(P.equip_subs_of("Grenade", ["Grenade_1"]) == ["Grenade"], "граната: подпись без номера слота")
	ck(P.equip_subs_of("Grenade", ["Grenade_1", "Grenade_2"]) == ["Grenade"], "два гнезда гранат схлопываются")
	ck(P.equip_subs_of("Fishing", ["Primary", "Secondary"]).is_empty(), "у Hobby подкатегорий нет")
	ck(P.equip_subs_of("Electronics", ["Player"]) == ["Player"], "Player - своя подкатегория шага 1")
	ck(P.equip_subs_of("Ammo", []).is_empty(), "вне шага 1 - без подкатегорий")
	ck(P.equip_subs_of("Weapon", ["Primary", "Armor"]) == ["Primary"], "слот вне шага 1 в подкатегории не попадает")

func t_inventory_group_of() -> void:
	ck(P.inventory_group_of("Furniture", []) == "furniture", "мебель")
	ck(P.inventory_group_of("Weapon", ["Primary"]) == "weapon", "оружие")
	ck(P.inventory_group_of("Knife", ["Knife"]) == "weapon", "нож к оружию")
	ck(P.inventory_group_of("Grenade", ["Grenade_1"]) == "weapon", "граната к оружию")
	ck(P.inventory_group_of(null, ["Grenade_2"]) == "weapon", "слот-граната решает без type")
	ck(P.inventory_group_of("Ammo", []) == "ammo", "патроны")
	ck(P.inventory_group_of("Attachment", []) == "ammo", "обвесы рядом с патронами")
	ck(P.inventory_group_of("Rig", ["Rig"]) == "clothing", "разгрузка в одежду")
	ck(P.inventory_group_of("Belt Pouch", ["Belt"]) == "clothing", "подсумок в одежду")
	ck(P.inventory_group_of("Armor", ["Armor"]) == "clothing", "бронеплита в одежду")
	ck(P.inventory_group_of("Medical", []) == "medical", "медицина")
	ck(P.inventory_group_of("Consumables", []) == "food", "еда (Consumables)")
	ck(P.inventory_group_of("Consumable", []) == "food", "еда (Consumable)")
	ck(P.inventory_group_of("Fish", []) == "food", "рыба в еду")
	ck(P.inventory_group_of("Electronics", ["Light"]) == "gear", "фонарик уходит из электроники в Gear")
	ck(P.inventory_group_of("Misc", ["Map"]) == "gear", "карта в Gear по слоту")
	ck(P.inventory_group_of("Fishing", []) == "gear", "удочка в Gear")
	ck(P.inventory_group_of("Instrument", []) == "gear", "музыка в Gear")
	ck(P.inventory_group_of("Misc", []) == "tools", "хлам в хозтовары")
	ck(P.inventory_group_of("Key", []) == "tools", "ключи в хозтовары")
	ck(P.inventory_group_of("Literature", []) == "tools", "книги в хозтовары")
	ck(P.inventory_group_of("Lore", []) == "tools", "лор в хозтовары")
	ck(P.inventory_group_of("Electronics", []) == "tools", "электроника без слота в хозтовары")
	ck(P.inventory_group_of(" Misc ", []) == "tools", "пробелы и регистр не мешают")
	ck(P.inventory_group_of("Wat", []) == "", "незнакомый type - без группы")
	ck(P.inventory_group_of(null, null) == "", "null type и слоты - без группы")
	ck(P.group_keys(P.INVENTORY_GROUPS).size() == 8, "восемь групп шага 2")
	ck(P.group_label(P.INVENTORY_GROUPS, "tools") == "Tools & sundries", "подпись группы шага 2")

func t_type_groups() -> void:
	ck(P.inventory_group_of("Consumables", []) == P.inventory_group_of("Consumable", []),
		"Consumables и Consumable - одна группа")
	ck(P.inventory_group_of("Rig", []) == "clothing", "разгрузка в одежде, а не отдельной полке")
	ck(P.inventory_group_of("Backpack", []) == "clothing", "рюкзак в одежде")
	ck(P.inventory_group_of("Helmet", []) == "clothing", "шлем в одежде")
	ck(P.inventory_group_of("Fish", []) == "food", "рыба в еде")

func t_unknown_folder_no_chip() -> void:
	ck(P.subcategory_of("res://Items/Misc/Tarp/Tarp.tres", "Misc") == "Utilities & Tools",
		"Tarp явно в хозтоварах")
	ck(P.subcategory_of("res://Items/Misc/Tarp_New/Tarp_New.tres", "Misc") == "",
		"новая папка чипа не даёт")
	ck(P.subcategory_of("res://Items/Junk/Thing_01.tres", "Misc") == "",
		"новая трёхсегментная папка чипа не даёт")

func t_buckets() -> void:
	var items: Array = [
		{"name": "AK", "inv_group": "weapon"},
		{"name": "Аптечка", "inv_group": "medical"},
		{"name": "Без группы", "inv_group": ""},
	]
	var got := P.buckets(items, "inv_group", P.group_keys(P.INVENTORY_GROUPS), true)
	ck(str(got[0].get("key", "x")) == "" and int(got[0].get("count", -1)) == 3,
		"строка Все впереди и считает и записи без группы")
	ck(str(got[1].get("key", "")) == "weapon", "группы идут в порядке таблицы")
	ck(str(got[2].get("key", "")) == "medical", "медицина после оружия")
	ck(got.size() == 3, "пустые группы не появляются")
	ck(P.buckets(items, "inv_group", [], false).size() == 2, "без with_all нет строки Все")
	var odd := P.buckets([{"g": "zzz"}, {"g": "weapon"}, {"g": "aaa"}], "g", ["weapon"], false)
	ck(str(odd[0].get("key", "")) == "weapon", "порядок из order идёт первым")
	ck(str(odd[1].get("key", "")) == "aaa" and str(odd[2].get("key", "")) == "zzz",
		"хвост по алфавиту")
	ck(P.buckets([], "inv_group", [], true).size() == 1, "пустой вход даёт только Все с нулём")
	ck(int(P.buckets([], "inv_group", [], true)[0].get("count", -1)) == 0, "счётчик Все нулевой")
	ck(P.buckets([null, "мусор"], "inv_group", [], true)[0].get("count", -1) == 0,
		"мусорные элементы пропускаются")

func t_buckets_multi() -> void:
	var items: Array = [
		{"name": "Karov", "eq_group": "weapon", "eq_subs": ["Primary", "Secondary"]},
		{"name": "Шапка", "eq_group": "clothing", "eq_subs": ["Head"]},
	]
	var shelves := P.buckets(items, "eq_group", P.group_keys(P.EQUIP_GROUPS), false)
	ck(shelves.size() == 2, "две полки")
	ck((shelves[0].get("items", []) as Array).size() == 1, "пистолет лежит на полке один раз")
	var subs := P.buckets(items, "eq_subs", ["Primary", "Secondary", "Head"], false)
	ck(subs.size() == 3, "подкатегории: Primary, Secondary, Head")
	ck((subs[0].get("items", []) as Array).size() == 1, "пистолет в Primary")
	ck((subs[1].get("items", []) as Array).size() == 1, "он же в Secondary")
	ck(str(subs[2].get("key", "")) == "Head", "шапка в своей подкатегории")

func t_order_subcategories() -> void:
	ck(P.order_subcategories(["Fish", "Grenades", "Pistols", "Assault Rifles"]) == ["Assault Rifles", "Pistols", "Grenades", "Fish"],
		"порядок таблицы важнее порядка во входных данных")
	ck(P.order_subcategories([]) == [], "пустой вход даёт пустой список")
	ck(P.order_subcategories(["", "Fish"]) == ["Fish"], "пустая подкатегория отбрасывается")
	ck(P.order_subcategories(["Fish", "Fish"]) == ["Fish"], "дубли схлопываются")
	ck(P.order_subcategories(["Zzz Gear", "Fish", "Aaa Gear"]) == ["Fish", "Aaa Gear", "Zzz Gear"],
		"неизвестные подкатегории идут после таблицы, по алфавиту")
	ck(P.order_subcategories(["Head", "Primary", "Light"]) == ["Primary", "Head", "Light"],
		"подписи слотов шага 1 стоят впереди в порядке SLOT_ORDER")
	ck(P.order_subcategories(["Matches", "Player", "NVG"]) == ["NVG", "Player", "Matches"],
		"Player стоит между NVG и Matches, как в SLOT_ORDER")

func t_furn_subcategories() -> void:
	ck(P.subcategory_of("res://Assets/Radio/Radio_F.tres", "Furniture") == "Appliances & Electronics",
		"мебель: радио в технику")
	ck(P.subcategory_of("res://Assets/Bed_Civilian/Bed_Civilian_F.tres", "Furniture") == "Seating & Beds",
		"мебель: кровать в сиденья")
	ck(P.subcategory_of("res://Assets/Carpet/Carpet_Rag_F.tres", "Furniture") == "Decor",
		"мебель: ковёр в декор")
	ck(P.subcategory_of("res://Assets/Weapon_Display/Weapon_Display_F.tres", "Furniture") == "Decor",
		"мебель: стойка для оружия в декор")
	ck(P.subcategory_of("res://Assets/Bookshelf/Bookshelf_F.tres", "Furniture") == "Decor",
		"мебель: книга/шкаф в декор")
	ck(P.subcategory_of("res://Assets/Cupboard/Cupboard_F.tres", "Furniture") == "Decor",
		"мебель: шкаф/буфет в декор")
	ck(P.subcategory_of("res://Assets/Table_Cabin/Table_Cabin_F.tres", "Furniture") == "Tables & Shelving",
		"мебель: стол в столы")
	# Неизвестная папка остаётся без чипа, а не падает и не липнет к чужой группе.
	ck(P.subcategory_of("res://Assets/Unknown_Thing/Unknown_Thing_F.tres", "Furniture") == "",
		"неизвестная мебель без чипа")
	# Каждое значение таблицы обязано быть в порядке строк фильтров, иначе чип
	# отрисуется, но строки в UI под него не будет и группа пропадёт молча.
	for v in P.FURN_SUB_FOLDERS.values():
		ck(P.SUBCATEGORY_ORDER.has(v), "группа мебели в порядке: " + str(v))

func t_merged_subcategories() -> void:
	ck(P.subcategory_of("res://Items/Medical/Hand_Warmer/Hand_Warmer.tres", "Medical") == "Utility",
		"грелка сворачивается в мелочи")
	ck(P.subcategory_of("res://Items/Lore/Suitcase_Driver/Suitcase_Driver.tres", "Lore") == "Lore",
		"водительский чемоданчик остаётся в лоре")
	for sub in ["Air_Freshener", "Glue", "Leather", "Museum_Plate", "Radiator_Engine", "Screws"]:
		var got := P.subcategory_of("res://Items/Misc/" + sub + "/" + sub + ".tres", "Misc")
		ck(got == "Utilities & Tools", "мелочь без группы -> хозтовары: " + sub)

func t_subcategory_of() -> void:
	# Папка ствола из третьего сегмента.
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM.tres", "Weapon") == "Assault Rifles",
		"AKM -> Assault Rifles")
	ck(P.subcategory_of("res://Items/Weapons/SVD/SVD.tres", "Weapon") == "Sniper Rifles",
		"SVD -> Sniper Rifles")
	ck(P.subcategory_of("res://Items/Weapons/Remington_870/Remington_870.tres", "Weapon") == "Shotguns",
		"Remington_870 -> Shotguns")
	ck(P.subcategory_of("res://Items/Weapons/Colt_1911/Colt_1911.tres", "Weapon") == "Pistols",
		"Colt_1911 -> Pistols")
	ck(P.subcategory_of("res://Items/Weapons/MP5/MP5.tres", "Weapon") == "SMGs",
		"MP5 -> SMGs")
	# Магазин опознаётся суффиксом, а не папкой: у Makarov папка одна и та же.
	ck(P.subcategory_of("res://Items/Weapons/Makarov/Makarov_Magazine.tres", "Attachment") == "Handgun & SMG Mags",
		"Makarov_Magazine -> Handgun & SMG Mags")
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM_Magazine.tres", "Attachment") == "Rifle & Sniper Mags",
		"AKM_Magazine -> Rifle & Sniper Mags")
	ck(P.subcategory_of("res://Items/Weapons/KP-31/KP-31_Drum.tres", "Attachment") == "Handgun & SMG Mags",
		"KP-31_Drum -> Handgun & SMG Mags")
	# Ствольная коробка KAR-21 не должна попасть в Assault Rifles.
	ck(P.subcategory_of("res://Items/Weapons/KAR-21/KAR-21_Barrel.tres", "Attachment") == "Weapon Parts",
		"KAR-21_Barrel -> Weapon Parts")
	# Трёхсегментные пути: папки нет, читаем имя файла.
	ck(P.subcategory_of("res://Items/Armor/Armor_Plate_II.tres", "Armor") == "Armor Plates",
		"Armor_Plate_II -> Armor Plates")
	ck(P.subcategory_of("res://Items/Keys/Key_Attic.tres", "Tool") == "",
		"Key_Attic -> без подкатегории")
	ck(P.subcategory_of("res://Items/Keys/Key_Cellar.tres", "Tool") == "",
		"Key_Cellar -> без подкатегории")
	ck(P.subcategory_of("res://Items/Books/Book_Children.tres", "Tool") == "",
		"Book_Children -> без подкатегории")
	ck(P.subcategory_of("res://Items/Knives/Jaeger_140/Jaeger_140.tres", "Tool") == "",
		"Jaeger_140 -> без подкатегории")
	ck(P.subcategory_of("res://Items/Electronics/Alarm_Clock/Alarm_Clock.tres", "Tool") == "",
		"Alarm_Clock -> без подкатегории")
	ck(P.subcategory_of("res://Items/Electronics/PV7/PV7.tres", "Electronics") == "Electronics",
		"PV7 без слота остаётся электроникой")
	# Прочие папки верхних уровней.
	ck(P.subcategory_of("res://Items/Rigs/LVPC/LVPC_Green.tres", "Armor") == "Rigs & Vests",
		"LVPC -> Rigs & Vests")
	ck(P.subcategory_of("res://Items/Rigs/Vest_Fishing/Vest_Fishing.tres", "Armor") == "Rigs & Vests",
		"Vest_Fishing -> Rigs & Vests")
	ck(P.subcategory_of("res://Items/Attachments/ACOG/ACOG.tres", "Attachment") == "Scopes",
		"ACOG -> Scopes")
	ck(P.subcategory_of("res://Items/Attachments/PBS/PBS.tres", "Attachment") == "Suppressors",
		"PBS -> Suppressors")
	ck(P.subcategory_of("res://Items/Attachments/OZ5/OZ5.tres", "Attachment") == "Lasers",
		"OZ5 -> Lasers")
	ck(P.subcategory_of("res://Items/Attachments/ANPEQ/ANPEQ.tres", "Attachment") == "Lasers",
		"ANPEQ -> Lasers")
	ck(P.subcategory_of("res://Items/Medical/IFAK/IFAK.tres", "Medical") == "First Aid",
		"IFAK -> First Aid")
	ck(P.subcategory_of("res://Items/Consumables/Beer/Beer.tres", "Consumable") == "Vices",
		"Beer -> Vices")
	ck(P.subcategory_of("res://Items/Clothing/Jeans_Black/Jeans_Black.tres", "Clothing") == "Pants",
		"Jeans_Black -> Pants")
	ck(P.subcategory_of("res://Items/Medical/Antiseptic/Antiseptic.tres", "Medical") == "Utility",
		"Antiseptic -> Utility")
	ck(P.subcategory_of("res://Items/Medical/Melatonin/Melatonin.tres", "Medical") == "Utility",
		"Melatonin -> Utility")
	ck(P.subcategory_of("res://Items/Helmets/Helmet_Police/Helmet_Police.tres", "Clothing") == "Helmets",
		"Helmet_Police -> Helmets")
	ck(P.subcategory_of("res://Items/Consumables/Can_Empty/Can_Empty.tres", "Consumable") == "Garbage",
		"Can_Empty -> Garbage")
	ck(P.subcategory_of("res://Items/Misc/Blanket/Blanket.tres", "Misc") == "Utilities & Tools",
		"Survival сведён с Utilities & Tools")
	# Граната из слота, а не из папки.
	ck(P.subcategory_of("res://Items/Grenades/F1/F1.tres", "Consumable") == "",
		"F1 без подкатегории")
	# Музыка и рыба известны таблице, а не попадают в fallback.
	ck(P.subcategory_of("res://Items/Instruments/Guitar/Guitar.tres", "Tool") == "Music",
		"Guitar -> Music")
	ck(P.subcategory_of("res://Items/Misc/Tackle_Box/Tackle_Box.tres", "Tool") == "Fishing",
		"Tackle_Box -> Fishing")
	ck(P.subcategory_of("res://Items/Fishing/Fishing_Rod/Fishing_Rod.tres", "Tool") == "Fishing",
		"Fishing_Rod -> Fishing")
	ck(P.subcategory_of("res://Items/Fishing/Bream/Bream.tres", "Food") == "Fish",
		"Bream -> Fish")
	# Неизвестная папка больше не превращается в чип: класс предмета берётся
	# из таблиц, а не из имени папки.
	ck(P.subcategory_of("res://Items/Weapons/Foo_Bar/Foo_Bar.tres", "Weapon") == "",
		"Foo_Bar -> без подкатегории")
	# То же для трёхсегментного пути, где роль папки играет имя файла.
	ck(P.subcategory_of("res://Items/Junk/Thing_01.tres", "Tool") == "",
		"Thing_01 -> без подкатегории")
	# Класс из слота: у гранаты, фонарика и спичек папка модели ничего не говорит.
	ck(P.subcategory_of("res://Items/Grenades/F1/F1.tres", "Grenade", []) == "",
		"без слотов граната класса не получает")
	ck(P.subcategory_of("res://Items/Grenades/F1/F1.tres", "Grenade", ["Grenade_1", "Grenade_2"]) == "Grenades",
		"слот-граната даёт класс Grenades (кэш различает наборы слотов)")
	ck(P.subcategory_of("res://Items/Knives/Jaeger_140/Jaeger_140.tres", "Knife") == "Knives",
		"Knife -> Knives")
	ck(P.subcategory_of("res://Items/Keys/Key_Attic.tres", "Key") == "Keys", "Key -> Keys")
	ck(P.subcategory_of("res://Items/Books/Book_Children.tres", "Literature") == "Books",
		"Literature -> Books")
	ck(P.subcategory_of("res://Items/Electronics/Polaris/Polaris.tres", "Electronics", ["Light"]) == "Light",
		"класс Gear берётся из слота, а не из папки")
	ck(P.subcategory_of("res://Items/Electronics/PV7/PV7.tres", "Electronics", ["NVG"]) == "NVG",
		"PV7 -> NVG по слоту")
	ck(P.subcategory_of("res://Items/Misc/Matches/Matches.tres", "Misc", ["Matches"]) == "Matches",
		"спички -> Matches по слоту")
	ck(P.subcategory_of("res://Items/Electronics/Batteries/Batteries.tres", "Electronics") == "Electronics",
		"электроника без слота остаётся электроникой")
	# Пустой путь и пустой тип.
	ck(P.subcategory_of("", "Weapon") == "", "пустой путь -> пусто")
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM.tres", null) == "", "пустой тип -> пусто")
