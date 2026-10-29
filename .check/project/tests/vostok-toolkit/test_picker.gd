extends SceneTree

const P = preload("res://mods/VTK/VTKPicker.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func t_facets_of_requires_name() -> void:
	# Регрессия: facets_of фильтрует по ключу name записи. Запись без name
	# (как её отдавал _entry до 4.13.4) под непустым запросом выпадает целиком.
	var with_name: Array = [{"name": "AKM", "cat": "weapon"}]
	var without: Array = [{"cat": "weapon"}]
	ck(int(P.facets_of(with_name, "akm")[0].get("count", -1)) == 1,
		"запись с name находится по запросу")
	ck(int(P.facets_of(without, "akm")[0].get("count", -1)) == 0,
		"запись без name под запросом выпадает (нужен ключ name)")
	ck(int(P.facets_of(without, "")[0].get("count", -1)) == 1,
		"без запроса запись без name остаётся")

func _init() -> void:
	t_all_slots()
	t_equip_layout()
	t_matches_slot()
	t_matches_search()
	t_shelves_of()
	t_category_of()
	t_category_allowed()
	t_subcategory_of()
	t_order_subcategories()
	t_furn_subcategories()
	t_merged_subcategories()
	t_facets_of()
	t_facets_of_requires_name()
	t_facets_of_ungrouped()
	t_att_panel_needed()
	t_group_attachments()
	t_item_art()
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

func t_shelves_of() -> void:
	var items := [
		{"name": "Нож", "cat": "tool"},
		{"name": "АК", "cat": "weapon"},
		{"name": "Аптечка", "cat": "medical"},
		{"name": "Пламегаситель", "cat": "consumable"},
		{"name": "Рация", "cat": "equipment"},
	]
	var got := P.shelves_of(items)
	ck(got.size() == 5, "пять непустых полос")
	ck(str(got[0]["cat"]) == "weapon", "оружие идёт первым")
	ck(str(got[1]["cat"]) == "medical", "медицина раньше расходников и снаряжения")
	ck(str(got[2]["cat"]) == "consumable", "расходники после медицины")
	ck(str(got[3]["cat"]) == "equipment", "снаряжение дальше")
	ck(str(got[4]["cat"]) == "tool", "инструменты последними")
	ck((got[0]["items"] as Array).size() == 1, "в полосе оружия один предмет")
	# категория из данных, которой нет в CATEGORIES, не теряется
	var odd := P.shelves_of([{"name": "Х", "cat": "zzz"}, {"name": "А", "cat": "weapon"},
		{"name": "Б", "cat": "aaa"}])
	ck(odd.size() == 3, "неизвестные категории тоже получили полосы")
	ck(str(odd[0]["cat"]) == "weapon", "известная категория осталась первой")
	ck(str(odd[1]["cat"]) == "aaa" and str(odd[2]["cat"]) == "zzz",
		"неизвестные категории в конце по алфавиту")
	ck(P.shelves_of([]).is_empty(), "пустой список предметов даёт пустые полосы")
	ck(P.shelves_of([{"name": "X", "cat": "weapon"}, "мусор", null]).size() == 1,
		"мусорные элементы пропускаются")
	ck(P.shelves_of([{"name": "Y", "cat": ""}]).is_empty(), "предмет без категории не образует полосу")

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

func t_category_of() -> void:
	ck(P.category_of(["Grenade_1"], "Consumable") == "@grenade", "слот-граната бьёт type")
	ck(P.category_of(["Grenade_2"], null) == "@grenade", "второй слот-граната тоже")
	ck(P.category_of(["Primary", "Grenade_1"], "Weapon") == "@grenade", "среди прочих слотов")
	ck(P.category_of(["Primary"], "Weapon") == "weapon", "без слота-гранаты это type в нижнем регистре")
	ck(P.category_of(null, "Medical") == "medical", "null slots не мешают type")
	ck(P.category_of(["Head"], null) == "", "без type предмет вне групп")
	ck(P.category_of(null, null) == "", "ни слотов ни типа - вне групп")
	ck(P.category_of("Grenade_1", "Weapon") == "weapon", "строка слотами не считается слотами")
	ck(P.category_of(null, "Consumables") == "consumable", "Consumables сводится к consumable")
	ck(P.category_of(null, "Consumable") == "consumable", "единый тип даёт ту же группу")
	ck(P.category_of(null, " Misc") == "misc", "ведущий пробел в type не делает отдельный фасет")
	ck(P.category_of(null, "Instrument") == "misc", "гитара и гармошка ушли в misc")
	ck(P.category_of(null, "Lore") == "misc", "лор ушёл в misc")
	ck(P.category_of(null, "Fishing") == "misc", "удилище ушло в misc")
	ck(P.category_of(["Backpack"], "Backpack") == "clothing", "рюкзак ушёл в одежду")
	ck(P.category_keys().has("@grenade"), "в порядке категорий есть гранаты")
	ck(not P.category_keys().has("instrument"), "полки Instruments больше нет")
	ck(not P.category_keys().has("lore"), "полки Lore больше нет")
	ck(not P.category_keys().has("backpack"), "полки Backpacks больше нет")

func t_category_allowed() -> void:
	ck(P.category_allowed("weapon", "Primary"), "оружие проходит в Primary")
	ck(not P.category_allowed("fishing", "Primary"), "удилище не проходит в Primary")
	ck(not P.category_allowed("instrument", "Secondary"), "гитара не проходит в Secondary")
	ck(P.category_allowed("fishing", ""), "без слота цель не режет предметы")
	ck(P.category_allowed("fishing", "Melee"), "у melee слотов фильтр свободный")
	ck(P.category_allowed("tool", "Head"), "у головы фильтр свободный")
	ck(P.category_allowed("", "Primary"), "предмет вне таксономии не выбрасывается")
	ck(P.category_allowed("weapon", "Grenade_1"), "Primary-правило не цепляет другие слоты")
	ck(not P.category_allowed("attachment", "Primary"), "обвесы не предлагаются слоту оружия")
	ck(P.WEAPON_SLOTS == ["Primary", "Secondary"], "правило касается только двух слотов")


func t_order_subcategories() -> void:
	ck(P.order_subcategories(["Fish", "Grenades", "Pistols", "Assault Rifles"]) == ["Assault Rifles", "Pistols", "Fish", "Grenades"],
		"порядок таблицы важнее порядка во входных данных")
	ck(P.order_subcategories([]) == [], "пустой вход даёт пустой список")
	ck(P.order_subcategories(["", "Fish"]) == ["Fish"], "пустая подкатегория отбрасывается")
	ck(P.order_subcategories(["Fish", "Fish"]) == ["Fish"], "дубли схлопываются")
	ck(P.order_subcategories(["Zzz Gear", "Fish", "Aaa Gear"]) == ["Fish", "Aaa Gear", "Zzz Gear"],
		"неизвестные подкатегории идут после таблицы, по алфавиту")

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

func t_facets_of() -> void:
	var list: Array = [
		{"name": "АК-74", "cat": "weapon"},
		{"name": "Граната М50", "cat": "@grenade"},
		{"name": "Аптечка", "cat": "medical"},
		{"name": "АК-74У", "cat": "weapon"},
	]
	var f := P.facets_of(list, "")
	ck(f.size() == 4, "Все + weapon + гранаты + медицина")
	ck(str(f[0].get("key", "x")) == "" and int(f[0].get("count", -1)) == 4,
		"строка Все впереди и считает всё")
	ck(str(f[1].get("key", "")) == "weapon" and int(f[1].get("count", 0)) == 2,
		"вторым идёт weapon с двумя")
	ck(str(f[2].get("key", "")) == "@grenade" and int(f[2].get("count", 0)) == 1,
		"гранаты по слотам, а не по type")
	ck(str(f[3].get("key", "")) == "medical", "медицина последней по CATEGORIES")
	var q := P.facets_of(list, "ак")
	ck(int(q[0].get("count", -1)) == 2, "запрос сужает строку Все")
	ck(q.size() == 2, "пустые группы под запросом выпадают")
	ck(str(q[1].get("key", "")) == "weapon" and int(q[1].get("count", 0)) == 2,
		"счётчик фасета тоже пересчитан")
	var sum := 0
	for r in q:
		if str(r.get("key", "")) != "":
			sum += int(r.get("count", 0))
	ck(sum == int(q[0].get("count", -1)), "сумма фасетов равна Все: группы не пересекаются")
	var empty := P.facets_of([], "")
	ck(empty.size() == 1 and int(empty[0].get("count", -1)) == 0,
		"пустой каталог даёт только строку Все с нулём")
	ck(P.facets_of([null, "мусор"], "").size() == 1, "мусорные элементы пропускаются")
	# Два типа еды из данных игры не должны давать две строки с одинаковой
	# подписью: ключ фасета - результат category_of, а не сырой type.
	var food: Array = [
		{"name": "Water Bottle", "cat": P.category_of(null, "Consumable")},
		{"name": "Canned Meat", "cat": P.category_of(null, "Consumables")},
	]
	var ff := P.facets_of(food, "")
	ck(ff.size() == 2, "Consumable и Consumables дают один фасет")
	ck(str(ff[1].get("key", "")) == "consumable" and int(ff[1].get("count", 0)) == 2,
		"сводный фасет consumable считает оба типа")

# Предмет без группы не должен попадать в "Все": иначе сумма фасетов не равна
# счётчику Все, и клик по фасету показывает меньше, чем обещает число.
func t_facets_of_ungrouped() -> void:
	var list: Array = [
		{"name": "АК-74", "cat": "weapon"},
		{"name": "Без типа", "cat": ""},
		{"name": "Без ключа"},
	]
	var f := P.facets_of(list, "")
	ck(f.size() == 2, "без группы остаётся только Все и weapon")
	ck(int(f[0].get("count", -1)) == 1, "предметы вне групп не считаются")
	ck(int(f[1].get("count", 0)) == 1, "в фасете осталось одно")
	var all := P.facets_of(list, "")[0]["items"] as Array
	ck(all.size() == 1 and str((all[0] as Dictionary).get("name", "")) == "АК-74",
		"в items Все лежит только сгруппированный предмет")
	var sum := 0
	for r in P.facets_of(list, ""):
		if str(r.get("key", "")) != "":
			sum += int(r.get("count", 0))
	ck(sum == int(f[0].get("count", -1)), "сумма фасетов равна Все и с несгруппированными")
	ck(P.facets_of([{"name": "Без типа", "cat": ""}], "").size() == 1,
		"каталог без сгруппированных даёт только строку Все")

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
	ck(P.subcategory_of("res://Items/Electronics/PV7/PV7.tres", "Electronics") == "",
		"PV7 -> без подкатегории")
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
	# Неизвестная папка не теряется: её имя становится подкатегорией.
	ck(P.subcategory_of("res://Items/Weapons/Foo_Bar/Foo_Bar.tres", "Weapon") == "Foo_Bar",
		"Foo_Bar -> имя папки")
	# То же для трёхсегментного пути, где роль папки играет имя файла.
	ck(P.subcategory_of("res://Items/Junk/Thing_01.tres", "Tool") == "Thing_01",
		"Thing_01 -> имя файла")
	# Пустой путь и пустой тип.
	ck(P.subcategory_of("", "Weapon") == "", "пустой путь -> пусто")
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM.tres", null) == "", "пустой тип -> пусто")
