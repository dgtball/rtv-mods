extends SceneTree

const VTKData = preload("res://mods/VTK/VTKData.gd")

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
	_clean()
	t_roundtrip()
	t_bak_written()
	t_corrupt_recovers_from_bak()
	t_corrupt_without_bak()
	t_foreign_format_not_quarantined()
	t_bare_array_is_read_as_sets()
	t_norm_halves_independent()
	t_save_returns_ok()
	t_save_reports_open_error()
	t_replace_set_drops_old_name_in_one_write()
	t_prop()
	print("")
	if fails == 0:
		print("tests passed")
		quit(0)
	else:
		print("Data tests failed: ", fails)
		quit(1)

class FakeRes extends Resource:
	var amount := 5
	var nothing = null

func t_prop() -> void:
	# Object.get() принимает один аргумент: get(name, default) на Resource
	# падает в debug, поэтому фолбэк применяет сам prop.
	var r := FakeRes.new()
	ck(int(VTKData.prop(r, "amount", 1)) == 5, "prop: читает свойство")
	ck(int(VTKData.prop(r, "missing", 7)) == 7, "prop: отсутствующее свойство -> фолбэк")
	ck(int(VTKData.prop(r, "nothing", 9)) == 9, "prop: null-свойство -> фолбэк")
	ck(int(VTKData.prop(null, "amount", 3)) == 3, "prop: null-объект -> фолбэк")
	ck(int(VTKData.prop({"amount": 4}, "amount", 1)) == 4, "prop: работает и для Dictionary")

func _ld(nm: String) -> Dictionary:
	return {"name": nm, "quick_key": 0, "equip": {}, "gear": []}

func _dir() -> String:
	return VTKData.SAVE_FILE.get_base_dir()

func _g(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _clean() -> void:
	for p in [VTKData.SAVE_FILE, VTKData.SAVE_FILE + ".bak", VTKData.SAVE_FILE + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(_g(p))
	var tmp_dir := _g(VTKData.SAVE_FILE + ".tmp")
	if DirAccess.dir_exists_absolute(tmp_dir):
		DirAccess.remove_absolute(tmp_dir)
	var d := DirAccess.open(_dir())
	if d != null:
		for f in d.get_files():
			if f.begins_with("VTKsets.json.corrupt"):
				DirAccess.remove_absolute(_g(_dir() + "/" + f))

func _write_main(text: String) -> void:
	if DirAccess.open(_dir()) == null:
		DirAccess.make_dir_recursive_absolute(_g(_dir()))
	var f := FileAccess.open(VTKData.SAVE_FILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _corrupt_count() -> int:
	var n := 0
	var d := DirAccess.open(_dir())
	if d != null:
		for f in d.get_files():
			if f.begins_with("VTKsets.json.corrupt"):
				n += 1
	return n

func t_roundtrip() -> void:
	_clean()
	VTKData.save_all([_ld("A")])
	var all := VTKData.get_all()
	ck(all.size() == 1 and str(all[0]["name"]) == "A", "save/get round-trip")

func t_bak_written() -> void:
	_clean()
	VTKData.save_all([_ld("A")])
	VTKData.save_all([_ld("B")])
	var bak := VTKData.SAVE_FILE + ".bak"
	ck(FileAccess.file_exists(bak), "РІС‚РѕСЂР°СЏ Р·Р°РїРёСЃСЊ СЃРѕР·РґР°С‘С‚ .bak")
	var all := VTKData.get_all()
	ck(all.size() == 1 and str(all[0]["name"]) == "B", "РѕСЃРЅРѕРІРЅРѕР№ = РїРѕСЃР»РµРґРЅСЏСЏ РІРµСЂСЃРёСЏ")
	var f := FileAccess.open(bak, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	ck(parsed != null and str(parsed["loadouts"][0]["name"]) == "A", "РІ .bak РїСЂРµРґС‹РґСѓС‰Р°СЏ РІРµСЂСЃРёСЏ")

func t_corrupt_recovers_from_bak() -> void:
	_clean()
	VTKData.save_all([_ld("A")])
	VTKData.save_all([_ld("B")])
	_write_main("}{ not json")
	var all := VTKData.get_all()
	ck(all.size() == 1 and str(all[0]["name"]) == "A", "Р±РёС‚С‹Р№ РѕСЃРЅРѕРІРЅРѕР№ -> РіСЂСѓР·РёРј .bak")
	ck(_corrupt_count() >= 1, "Р±РёС‚С‹Р№ РѕСЃРЅРѕРІРЅРѕР№ РѕС‚Р»РѕР¶РµРЅ РІ .corrupt")

func t_corrupt_without_bak() -> void:
	_clean()
	_write_main("garbage")
	var all := VTKData.get_all()
	ck(all.is_empty(), "Р±РёС‚С‹Р№ Р±РµР· .bak -> РїСѓСЃС‚Рѕ")
	ck(_corrupt_count() == 1, "Р±РёС‚С‹Р№ Р±РµР· .bak РѕС‚Р»РѕР¶РµРЅ РІ .corrupt")
	VTKData.get_all()
	ck(_corrupt_count() == 1, "РїРѕРІС‚РѕСЂРЅС‹Р№ get_all РЅРµ РїР»РѕРґРёС‚ .corrupt")

func t_save_returns_ok() -> void:
	_clean()
	ck(VTKData.save_all([_ld("A")]) == OK, "save_all: успешная запись -> OK")

# Отказ записи: каталог на месте .tmp не открывается на запись. Раньше
# save_all молча возвращал void, и вызывающий не мог отличить отказ от успеха.
func t_save_reports_open_error() -> void:
	_clean()
	VTKData.save_all([_ld("A")])
	var tmp_dir := _g(VTKData.SAVE_FILE + ".tmp")
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var rc := VTKData.save_all([_ld("B")])
	ck(rc != OK, "save_all: неоткрываемый .tmp -> код ошибки")
	ck(str(VTKData.get_all()[0]["name"]) == "A", "save_all: основной файл не тронут")
	_clean()

# Переименование одной записью: remove + replace_set оставляли файл без старого
# сета и ещё без нового, если вторая запись падала.
func t_replace_set_drops_old_name_in_one_write() -> void:
	_clean()
	VTKData.save_all([_ld("Old"), _ld("Keep")])
	var rc := VTKData.replace_set("New", {}, [], "Old")
	ck(rc == OK, "replace_set с drop_name -> OK")
	var names := VTKData.names()
	ck(names.size() == 2, "replace_set: осталось ровно два сета")
	ck(names.has("New") and names.has("Keep") and not names.has("Old"),
		"replace_set: старое имя убрано, новое добавлено")

# Валидный JSON чужой формы - не порча байтов: карантин не нужен, данные
# читаются из .bak. Раньше такой файл уезжал в .corrupt-*, и мод возвращал
# предыдущее поколение сетов.
func t_foreign_format_not_quarantined() -> void:
	_clean()
	VTKData.save_all([_ld("A")])
	VTKData.save_all([_ld("B")])
	_write_main('{"sets": []}')
	var all := VTKData.get_all()
	ck(all.size() == 1 and str(all[0]["name"]) == "A", "чужой формат -> данные из .bak")
	ck(_corrupt_count() == 0, "валидный JSON чужой формы не уезжает в .corrupt")

# Голый массив верхнего уровня - старый/ручной формат: принимаем как список.
func t_bare_array_is_read_as_sets() -> void:
	_clean()
	_write_main('[{"name": "Raw", "quick_key": 0, "equip": {}, "gear": []}]')
	var all := VTKData.get_all()
	ck(all.size() == 1 and str(all[0]["name"]) == "Raw", "голый массив = список сетов")
	ck(_corrupt_count() == 0, "голый массив не карантинится")

# Потерянная половина - это половина сета, а не пустой сет: данные на диске
# целы, терялась только логика чтения.
func t_norm_halves_independent() -> void:
	var eq_only = VTKData._norm({
		"name": "E",
		"equip": {"Primary": {"path": "res://a.tres"}},
	})
	ck((eq_only["equip"] as Dictionary).has("Primary"), "_norm: equip читается без gear")
	ck((eq_only["gear"] as Array).is_empty(), "_norm: отсутствующий gear -> []")

	var gear_only = VTKData._norm({"name": "G", "gear": [{"path": "res://b.tres"}]})
	ck((gear_only["equip"] as Dictionary).is_empty(), "_norm: отсутствующий equip -> {}")
	ck((gear_only["gear"] as Array).size() == 1, "_norm: gear читается без equip")

	# legacy items - только когда нет ни equip, ни gear; иначе он съел бы
	# половину новой записи.
	var legacy = VTKData._norm({
		"name": "L",
		"items": [{"name": "Old"}],
	})
	ck((legacy["gear"] as Array).size() == 1, "_norm: legacy items -> gear")
