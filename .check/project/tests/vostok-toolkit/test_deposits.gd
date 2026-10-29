extends SceneTree

const D = preload("res://mods/VTK/VTKDeposits.gd")

var fails := 0

# Персист леджера в тесте: пишет факт и порядок вызова и возвращает заданный
# результат, чтобы проверить «леджер до списания» без файловой системы игры.
class Recorder:
	extends RefCounted
	var calls: Array = []
	var result := true
	func persist(ledger) -> bool:
		calls.append(ledger)
		return result

# Проверка существования ресурса без файловой системы игры.
class Exists:
	extends RefCounted
	var present: Dictionary = {}
	func check(path: String) -> bool:
		return present.has(path)

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_task_key()
	t_normalize_slots()
	t_coverage()
	t_apply()
	t_clear_task()
	t_prune_missing()
	t_badge_text()
	t_commit()
	print("")
	if fails == 0:
		print("Deposits tests passed")
		quit(0)
	else:
		print("Deposits tests failed: ", fails)
		quit(1)

func _slots() -> Array:
	return D.normalize_slots([
		{"file": "Beer", "name": "Beer", "amount": 3},
		{"file": "Can", "name": "Can", "amount": 1},
	])

func t_task_key() -> void:
	ck(D.task_key("res://X.tres", "A", "Doctor") == "res://X.tres", "task_key: непустой path")
	ck(D.task_key("", "A", "Doctor") == "A::Doctor", "task_key: фоллбэк name::trader")

func t_normalize_slots() -> void:
	var got := D.normalize_slots([
		{"file": "Beer", "name": "Beer", "amount": 3},
		{"name": "OnlyName", "amount": 0},
	])
	ck(got.size() == 2, "normalize_slots: два слота")
	ck(got[0]["index"] == 0 and got[0]["file"] == "Beer" and got[0]["required"] == 3, "нормализация первого")
	ck(got[1]["index"] == 1 and got[1]["file"] == "OnlyName", "file: фоллбэк на name")
	ck(got[1]["required"] == 1, "amount<1 -> 1")
	ck(D.normalize_slots(null).is_empty(), "normalize_slots: null -> пусто")

func t_coverage() -> void:
	var slots := _slots()
	var empty := D.coverage({}, "K", slots)
	ck(empty["all_satisfied"] == false, "coverage: пусто -> не покрыто")
	ck(empty["slots"][0]["deposited"] == 0 and empty["slots"][0]["remaining"] == 3, "coverage: остаток = нужно")
	var part := D.coverage({"K": {0: 1}}, "K", slots)
	ck(part["all_satisfied"] == false and part["slots"][0]["remaining"] == 2, "coverage: частично")
	var full := D.coverage({"K": {0: 5, 1: 1}}, "K", slots)
	ck(full["all_satisfied"] == true, "coverage: покрыто")
	ck(full["slots"][0]["deposited"] == 3, "coverage: вклад обрезан до нужно")

func t_apply() -> void:
	var slots := _slots()
	var r := D.apply({}, "K", slots, [
		{"file": "Beer", "amount": 5, "ref": "n1"},
		{"file": "Can", "amount": 1, "ref": "n2"},
	])
	ck(r["ledger"]["K"][0] == 3 and r["ledger"]["K"][1] == 1, "apply: леджер заполнен")
	var take: Array = r["take"]
	ck(take.size() == 2, "apply: две стопки списаны")
	ck(take[0]["ref"] == "n1" and take[0]["amount"] == 3, "apply: из Beer взято не больше остатка")
	ck(take[1]["ref"] == "n2" and take[1]["amount"] == 1, "apply: Can целиком")

	# Повторный депозит по уже покрытому слоту не берёт ничего.
	var again := D.apply(r["ledger"], "K", slots, [{"file": "Beer", "amount": 2, "ref": "n3"}])
	ck(again["take"].is_empty(), "apply: покрытый слот не берёт")

	# Чужой file игнорируется.
	var wrong := D.apply({}, "K", slots, [{"file": "Rags", "amount": 4, "ref": "n4"}])
	ck(wrong["take"].is_empty() and wrong["ledger"].get("K", {}).is_empty(), "apply: чужой file -> ничего")

	# Исходный леджер не мутируется.
	var base := {"K": {0: 1}}
	var copy := D.apply(base, "K", slots, [{"file": "Beer", "amount": 1, "ref": "n5"}])
	ck(base["K"][0] == 1, "apply: исходный леджер не изменён")
	ck(copy["ledger"]["K"][0] == 2, "apply: копия изменена")

func t_clear_task() -> void:
	var base := {"K": {0: 1}, "Z": {0: 2}}
	var out := D.clear_task(base, "K")
	ck(not out.has("K") and out.has("Z"), "clear_task: удаляет только K")
	ck(base.has("K"), "clear_task: исходный не тронут")

func t_prune_missing() -> void:
	var ledger := {"res://alive.tres": {0: 1}, "res://gone.tres": {0: 2}, "Quest::Doctor": {0: 3}}
	var ex := Exists.new()
	ex.present["res://alive.tres"] = true
	var out := D.prune_missing(ledger, Callable(ex, "check"))
	ck(out.has("res://alive.tres"), "prune_missing: живой путь остался")
	ck(not out.has("res://gone.tres"), "prune_missing: пропавший путь убран")
	ck(out.has("Quest::Doctor"), "prune_missing: фолбэк name::trader не тронут")
	ck(out["res://alive.tres"][0] == 1, "prune_missing: значения скопированы")
	ck(ledger.has("res://gone.tres"), "prune_missing: исходный леджер не изменён")
	ck(D.prune_missing({}, Callable(ex, "check")).is_empty(), "prune_missing: пустой -> пусто")

func t_badge_text() -> void:
	ck(D.badge_text(2, 5) == "2 / 5", "badge_text: 2 / 5")
	ck(D.badge_text(0, 3) == "0 / 3", "badge_text: 0 / 3")
	ck(D.is_covered({"all_satisfied": true}), "is_covered: true")
	ck(not D.is_covered({"all_satisfied": false}), "is_covered: false")

# commit: леджер сохраняется ДО того, как take отдан на списание. Сбой персиста
# обязан вернуть пустой take, иначе предметы спишутся без записи вклада.
func t_commit() -> void:
	var slots := _slots()
	var rec := Recorder.new()
	var r := D.commit({}, "K", slots, [{"file": "Beer", "amount": 5, "ref": "n1"}], Callable(rec, "persist"))
	ck(bool(r["ok"]), "commit: успех")
	ck(r["take"].size() == 1 and r["take"][0]["amount"] == 3, "commit: take отдан после успеха персиста")
	ck(rec.calls.size() == 1, "commit: персист вызван один раз")
	ck(rec.calls[0]["K"][0] == 3, "commit: персист получил новый леджер")

	var rec_fail := Recorder.new()
	rec_fail.result = false
	var rf := D.commit({}, "K", slots, [{"file": "Beer", "amount": 5, "ref": "n1"}], Callable(rec_fail, "persist"))
	ck(not bool(rf["ok"]), "commit: сбой персиста -> not ok")
	ck(rf["take"].is_empty(), "commit: сбой персиста -> take пуст (предметы остаются)")

	var rec_none := Recorder.new()
	var rn := D.commit({}, "K", slots, [{"file": "Rags", "amount": 1, "ref": "n9"}], Callable(rec_none, "persist"))
	ck(bool(rn["ok"]) and rn["take"].is_empty(), "commit: нечего давать -> ok, пусто")
	ck(rec_none.calls.is_empty(), "commit: нечего давать -> персист не вызван")
