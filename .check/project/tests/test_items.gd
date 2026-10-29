extends SceneTree

const S = preload("res://mods/VTK/VTKItemStore.gd")
const Item = preload("res://stubs/ItemData.gd")

var fails := 0
var _akm

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

# Тип возврата Variant, а не RefCounted: свойства у заглушки свои, и доступ к
# ним через RefCounted не прошёл бы анализатор. А вывести тип из Variant через
# := тоже нельзя - это ошибка, поэтому вызовы ниже пишутся с явным типом.
func _item(item_name: String, path: String, item_type: String, item_slots: Array) -> Variant:
	var it = Item.new()
	it.name = item_name
	it.resource_path = path
	it.type = item_type
	it.slots = item_slots
	return it

func _init() -> void:
	t_rebuild()
	t_info()
	t_slots()
	t_cells()
	t_icon()
	t_clear()
	print("")
	if fails == 0:
		print("ItemStore tests passed")
		quit(0)
	else:
		print("ItemStore tests failed: ", fails)
		quit(1)

func t_rebuild() -> void:
	_akm = _item("AKM", "res://Items/Weapons/AKM/AKM.tres", "Weapon", ["Primary"])
	var broken: Variant = _item("", "res://Items/Broken.tres", "Misc", [])
	S.rebuild([_akm, broken, null])
	ck(S.all().size() == 1, "rebuild держит только предметы с именем")
	ck(S.all()[0] == _akm, "rebuild сохраняет порядок валидных")
	ck(S.index_of(_akm.resource_path) == _akm, "rebuild наполняет индекс по resource_path")
	ck(S.index_of("res://Items/Nope.tres") == null, "путь вне индекса -> null")

func t_info() -> void:
	ck(S.item_info("").is_empty(), "item_info по пустому пути -> {}")
	var info: Dictionary = S.item_info(_akm.resource_path)
	ck(info.get("name") == "AKM", "item_info берёт предмет из индекса, без диска")
	ck(info.get("type") == "Weapon", "type берётся как в данных")
	ck(info.get("cat") == "weapon", "cat приводится к нижнему регистру")
	ck(info.get("slots") == ["Primary"], "slots приходят из данных")
	ck(info.get("compatible") == [], "compatible без данных -> []")
	ck(info.get("resource") == _akm, "info несёт сам ресурс")
	ck(S.info_of(null).is_empty(), "info_of(null) -> {}")
	ck(S.info_of(_akm) == info, "info_of повторяет кеш по resource_path")
	ck(S.item_info(_akm.resource_path) == info, "повторный item_info отдаёт то же из кеша")

func t_slots() -> void:
	ck(S.item_slots(null).is_empty(), "item_slots(null) -> []")
	ck(S.item_slots({}).is_empty(), "item_slots без ключа -> []")
	ck(S.item_slots({"slots": "Primary"}).is_empty(), "item_slots не-массив -> []")
	ck(S.item_slots({"slots": ["Primary"]}) == ["Primary"], "item_slots читает слоты у Dictionary")

func t_cells() -> void:
	ck(S.cell_resource({}) == null, "cell_resource пустой дескриптор -> null")
	ck(S.cell_resource({"path": _akm.resource_path}) == _akm, "cell_resource достаёт ресурс из индекса")
	ck(S.attachment_resource({}) == null, "attachment_resource пустая запись -> null")
	ck(S.attachment_resource({"path": _akm.resource_path}) == _akm, "attachment_resource достаёт ресурс")

func t_icon() -> void:
	# PNG-фолбэк здесь не проверяется: resource_path у созданного в тесте
	# Resource не назначить, а грузить чужой диск в headless смысла нет.
	ck(S.item_icon(null) == null, "item_icon(null) -> null")
	ck(S.item_icon({"name": "X"}) == null, "item_icon для Dictionary -> null")
	ck(S.item_icon(_akm) == null, "item_icon для RefCounted -> null")
	ck(S.item_icon(Resource.new()) == null, "item_icon без .tres-пути -> null")

func t_clear() -> void:
	S.clear()
	ck(S.all().is_empty(), "clear() чистит список")
	ck(S.index_of(_akm.resource_path) == null, "clear() чистит индекс")
