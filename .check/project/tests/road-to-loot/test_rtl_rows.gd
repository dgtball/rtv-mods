extends SceneTree

const Rows = preload("res://mods/RoadToLoot/RTLRows.gd")

const COLOR := Color(1.0, 0.8, 0.2)

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _stats(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append(str(r["stat"]))
	return out

func _init() -> void:
	var res: Dictionary = Rows.build([], [], COLOR)
	ck(res["rows"].is_empty(), "no affixes: no rows")
	ck(res["skipped"].is_empty(), "no affixes: nothing skipped")

	# порядок задаёт ROW_ORDER, а не порядок аффиксов
	res = Rows.build([
		{"stat": "sprint", "value": 0.08, "unit": "pct"},
		{"stat": "recoil", "value": 0.18, "unit": "pct"},
		{"stat": "regen", "value": 0.03, "unit": "rate"},
	], [], COLOR)
	ck(_stats(res["rows"]) == ["recoil", "regen", "sprint"],
		"order follows ROW_ORDER: " + str(_stats(res["rows"])))

	# слитые статы своих строк не получают
	res = Rows.build([
		{"stat": "capacity", "value": 5.0, "unit": "kg"},
		{"stat": "damage", "value": 0.20, "unit": "pct"},
		{"stat": "noise", "value": 0.20, "unit": "pct"},
	], ["capacity", "damage"], COLOR)
	ck(_stats(res["rows"]) == ["noise"], "merged stats skipped: " + str(_stats(res["rows"])))

	# слитый стат без ванильной строки -> своя строка (fallback §7.5)
	res = Rows.build([{"stat": "capacity", "value": 5.0, "unit": "kg"}], [], COLOR)
	ck(_stats(res["rows"]) == ["capacity"], "unmerged capacity falls back to a row")
	ck(str(res["rows"][0]["label"]) == "Capacity:", "fallback label: " + str(res["rows"][0]["label"]))
	ck(str(res["rows"][0]["value"]) == "+5kg", "fallback value: " + str(res["rows"][0]["value"]))

	# condition не показывается и репортится как skipped
	res = Rows.build([
		{"stat": "condition", "value": 0.20, "unit": "pct"},
		{"stat": "stamina_drain", "value": 0.15, "unit": "pct"},
	], [], COLOR)
	ck(_stats(res["rows"]) == ["stamina_drain"], "condition has no row")
	ck(res["skipped"] == ["condition"], "condition reported as skipped")

	# легаси-статы 0.2.x идут после статов пула, в порядке аффиксов
	res = Rows.build([
		{"stat": "max_hp", "value": 10.0, "unit": "hp"},
		{"stat": "stamina_drain", "value": 0.15, "unit": "pct"},
		{"stat": "sway", "value": 1.2, "unit": "mult"},
	], [], COLOR)
	ck(_stats(res["rows"]) == ["stamina_drain", "max_hp", "sway"],
		"legacy stats appended: " + str(_stats(res["rows"])))

	# дубль стата суммируется, а не перезаписывается
	res = Rows.build([
		{"stat": "capacity", "value": 5.0, "unit": "kg"},
		{"stat": "capacity", "value": 10.0, "unit": "kg"},
	], [], COLOR)
	ck(res["rows"].size() == 1, "duplicate stat: one row")
	ck(str(res["rows"][0]["value"]) == "+15kg", "duplicate stat sums: " + str(res["rows"][0]["value"]))

	# цвет и знак переносятся в строку
	res = Rows.build([{"stat": "recoil", "value": 0.18, "unit": "pct"}], [], COLOR)
	ck(res["rows"][0]["color"] == COLOR, "row keeps tier colour")
	ck(str(res["rows"][0]["value"]) == "-18%", "row value has sign")

	# мусор во входе не роняет сборку
	res = Rows.build([{"value": 1.0}, "nope", null], [], COLOR)
	ck(res["rows"].is_empty(), "garbage affixes ignored")

	# totals: сумма по статам, включая слитые (их считает и RTLDisplay)
	var t: Dictionary = Rows.totals([
		{"stat": "capacity", "value": 5.0, "unit": "kg"},
		{"stat": "capacity", "value": 10.0, "unit": "kg"},
		{"stat": "recoil", "value": 0.18, "unit": "pct"},
	])
	ck(abs(float(t.get("capacity", 0.0)) - 15.0) < 0.001, "totals sums capacity: " + str(t.get("capacity")))
	ck(abs(float(t.get("recoil", 0.0)) - 0.18) < 0.001, "totals keeps recoil")
	ck(t.size() == 2, "totals: two stats")
	ck(Rows.totals([{"value": 1.0}, "nope", null]).is_empty(), "totals ignores garbage")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
