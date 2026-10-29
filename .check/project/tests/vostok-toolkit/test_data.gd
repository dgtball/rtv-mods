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
