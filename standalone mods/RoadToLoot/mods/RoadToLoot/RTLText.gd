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
