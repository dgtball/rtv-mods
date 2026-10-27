extends RefCounted

# format_line: статы без маппинга в ванильные строки
# drain — всегда отрицательный sign
static func format_line(stat: String, value: float, unit: String) -> String:
	var label := stat.capitalize().replace("_", " ")
	var is_drain: bool = stat.to_lower().contains("drain")
	if is_drain:
		return "-%d%% %s" % [int(round(abs(value) * 100.0)), label]
	match unit:
		"rate":
			return "+%.2f %s" % [value, label]
		"kg":
			return "+%d %s" % [int(round(value)), label]
		"flat":
			return "+%d %s" % [int(round(value)), label]
		_:
			return "+%d%% %s" % [int(round(value * 100.0)), label]

# legacy_format: статы не из пула 0.3.0
static func legacy_format(stat: String, value: float, unit: String) -> String:
	var label := stat.capitalize().replace("_", " ")
	match unit:
		"hp":
			return "+%d Max HP" % int(round(value))
		"flat":
			return "+%d %s" % [int(round(value)), label]
		"mult":
			return "%s x%.1f" % [label, value]
		_:
			return "+%d%% %s" % [int(round(abs(value) * 100.0)), label]

# format_affix: a = {stat, value, unit}; tier для информации (пока без цвета)
static func format_affix(a: Dictionary, tier: int) -> String:
	var unit: String = a.get("unit", "pct")
	var value: float = float(a.get("value", 0.0))
	var stat: String = a.get("stat", "")
	# спец-случаи
	if stat == "carry":
		return "+%d Carry" % int(round(value))
	return format_line(stat, value, unit)

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
static func merged_value(stat: String, value: float, base: float) -> String:
	match stat:
		"damage":
			return str(int(round(base * (1.0 + value))))
		"insulation":
			return "+%d" % int(round(base * (1.0 + value)))
		"carry":
			return "+%dkg" % int(round(base + value))
		"protection":
			return "Level %d" % int(round(base + value))
	return str(int(round(base + value)))
