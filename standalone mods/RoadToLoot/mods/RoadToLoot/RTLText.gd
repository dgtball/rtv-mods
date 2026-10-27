extends RefCounted

const STAT_LABELS := {
	"low_hp_regen": "Low HP Regen",
	"low_hp_damage": "Low HP Damage",
	"fire_rate": "Fire Rate",
	"max_hp": "Max HP",
}

# Меньше — лучше: минус читается как бонус, плюс сбивал бы с толку.
const NEGATIVE_STATS := ["stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain", "noise", "recoil"]

static func stat_label(stat: String) -> String:
	var label: String = STAT_LABELS.get(stat, stat.capitalize().replace("_", " "))
	return label + ":"

static func stat_sign(stat: String) -> String:
	return "-" if NEGATIVE_STATS.has(stat) else "+"

static func stat_value(stat: String, value: float, unit: String) -> String:
	var prefix := stat_sign(stat)
	match unit:
		"pct":
			return "%s%d%%" % [prefix, int(round(absf(value) * 100.0))]
		"rate":
			return "%s%.2f HP/s" % [prefix, absf(value)]
		"kg":
			return "%s%dkg" % [prefix, int(round(absf(value)))]
		"mult":
			return "x%.1f" % absf(value)
		_:
			return "%s%d" % [prefix, int(round(absf(value)))]

# Сумма аффикса с ванильной базой. Формат повторяет ванильные строки:
# Damage — голое число, Insulation — "+N", Capacity — "+Nkg", Protection — "Level N".
# int() отсекает, а не округляет: так же считает ванильный Tooltip.
static func merged_value(stat: String, value: float, base: float) -> String:
	match stat:
		"damage":
			return str(int(base * (1.0 + value)))
		"insulation":
			return "+%d" % int(base * (1.0 + value))
		"carry":
			return "+%dkg" % int(base + value)
		"protection":
			return "Level %d" % int(base + value)
	return str(int(base + value))
