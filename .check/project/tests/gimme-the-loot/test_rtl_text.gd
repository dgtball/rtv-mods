extends SceneTree

const Text = preload("res://mods/RoadToLoot/RTLText.gd")
const Pool = preload("res://mods/RoadToLoot/RTLPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	# --- stat_label: алиасы и фолбэк ---
	ck(Text.stat_label("capacity") == "Capacity:", "label capacity aliased to Capacity")
	ck(Text.stat_label("stamina_drain") == "Stamina Drain:", "label stamina_drain")
	ck(Text.stat_label("low_hp_regen") == "Low HP Regen:", "label alias low_hp_regen")
	ck(Text.stat_label("low_hp_damage") == "Low HP Damage:", "label alias low_hp_damage")
	ck(Text.stat_label("fire_rate") == "Fire Rate:", "label alias fire_rate")
	ck(Text.stat_label("max_hp") == "Max HP:", "label alias max_hp")
	ck(Text.stat_label("sway") == "Sway:", "label unknown falls back")

	# --- stat_value: знаки (D6) ---
	ck(Text.stat_value("recoil", 0.18, "pct") == "-18%", "recoil: " + Text.stat_value("recoil", 0.18, "pct"))
	ck(Text.stat_value("noise", 0.20, "pct") == "-20%", "noise: " + Text.stat_value("noise", 0.20, "pct"))
	for stat in ["stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain"]:
		ck(Text.stat_value(stat, 0.12, "pct").begins_with("-"), stat + " negative")
	for stat in ["damage", "fire_rate", "low_hp_damage", "sprint"]:
		ck(Text.stat_value(stat, 0.10, "pct") == "+10%", stat + " positive")

	# --- stat_value: единицы ---
	ck(Text.stat_value("regen", 0.03, "rate") == "+0.03 HP/s", "rate unit")
	ck(Text.stat_value("capacity", 5.0, "kg") == "+5kg", "kg unit")
	ck(Text.stat_value("protection", 1.0, "flat") == "+1", "flat unit")
	ck(Text.stat_value("max_hp", 10.0, "hp") == "+10", "hp unit")
	ck(Text.stat_value("sway", 1.2, "mult") == "x1.2", "mult unit")

	# --- каждая запись пула даёт читаемую пару подпись/значение ---
	for cat in ["weapon", "clothing"]:
		for e in Pool.entries(cat):
			var stat: String = str(e["stat"])
			var unit: String = str(e["unit"])
			ck(Text.stat_label(stat).ends_with(":"), "pool label ends with colon: " + stat)
			ck(Text.stat_value(stat, 0.10, unit) != "", "pool value non-empty: " + stat)

	# --- merged_value: сумма с ванильной базой (§6.1 спеки) ---
	ck(Text.merged_value("damage", 0.20, 100.0) == "120", "damage 100 +20%")
	ck(Text.merged_value("insulation", 0.30, 20.0) == "+26", "insulation 20 +30%")
	ck(Text.merged_value("capacity", 15.0, 20.0) == "+35kg", "capacity 20 +15")
	ck(Text.merged_value("protection", 1.0, 1.0) == "Level 2", "protection 1 +1")

	# §6.1 говорит int(base + base * x), то есть отсечение как в ванили
	# (Tooltip пишет int(itemData.insulation)), а не округление.
	ck(Text.merged_value("insulation", 0.13, 15.0) == "+16",
		"insulation truncates: " + Text.merged_value("insulation", 0.13, 15.0))
	ck(Text.merged_value("damage", 0.13, 15.0) == "16",
		"damage truncates: " + Text.merged_value("damage", 0.13, 15.0))
	ck(Text.merged_value("capacity", 0.5, 20.0) == "+20kg",
		"capacity truncates: " + Text.merged_value("capacity", 0.5, 20.0))
	# Целое произведение не должно просесть на отсечении: 15 * 1.2 == 18.0 ровно.
	ck(Text.merged_value("insulation", 0.20, 15.0) == "+18",
		"insulation exact product: " + Text.merged_value("insulation", 0.20, 15.0))

	# Страж от дрейфа: у каждой записи MERGED свой формат, а не generic-фолбэк.
	var fallback: String = str(int(round(10.0 + 0.5)))
	for stat in Pool.MERGED:
		ck(Text.merged_value(str(stat), 0.5, 10.0) != fallback,
			"MERGED stat has its own format: " + str(stat))

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
