extends RefCounted

# Строки тултипа для аффиксов: суммирование, порядок, исключения, формат.
# Ни узлов, ни load(), ни путей внутрь игры — чистая логика, покрыта test_rtl_rows.gd.

const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")
const Text = preload("res://mods/RoadToLoot/RTLText.gd")

# Статы, которые не показываются в тултипе вовсе (§D2 спеки).
const HIDDEN := ["condition"]

# affixes: [{stat, value, unit}] из RTLStore.affixes()
# merged: статы, уже вписанные в ванильные строки — своей строки им не нужно.
# Возвращает {rows: [{stat, label, value, color}], skipped: [stat]}.
static func build(affixes: Array, merged: Array, color: Color) -> Dictionary:
	var values: Dictionary = {}
	var units: Dictionary = {}
	for a in affixes:
		if not (a is Dictionary):
			continue
		var stat: String = str(a.get("stat", ""))
		if stat == "":
			continue
		values[stat] = float(values.get(stat, 0.0)) + float(a.get("value", 0.0))
		if not units.has(stat):
			units[stat] = str(a.get("unit", "pct"))
	var rows: Array = []
	var skipped: Array = []
	var done: Dictionary = {}
	for stat in Pool.ROW_ORDER:
		if not values.has(stat) or merged.has(stat):
			continue
		done[stat] = true
		rows.append(_row(stat, values, units, color))
	for stat in values.keys():
		if done.has(stat) or merged.has(stat):
			continue
		if HIDDEN.has(stat):
			skipped.append(stat)
			continue
		rows.append(_row(stat, values, units, color))
	return {"rows": rows, "skipped": skipped}

static func _row(stat: String, values: Dictionary, units: Dictionary, color: Color) -> Dictionary:
	return {
		"stat": stat,
		"label": Text.stat_label(stat),
		"value": Text.stat_value(stat, float(values[stat]), str(units.get(stat, "pct"))),
		"color": color,
	}
