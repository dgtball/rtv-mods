extends RefCounted

const KNOWN_STATS := ["regen", "low_hp_regen", "capacity", "stamina_drain",
	"insulation", "thirst_drain", "hunger_drain", "sanity_drain",
	"damage", "recoil", "fire_rate", "low_hp_damage"]

static func clothing_totals(slots: Array) -> Dictionary:
	var result := {}
	for slot in slots:
		var item_data: Dictionary = slot.get("item_data", {})
		var slot_data: Dictionary = slot.get("slot_data", {})
		var affixes: Array = slot_data.get("loot_affixes", []) if slot_data else []
		for affix in affixes:
			var stat: String = str(affix.get("stat", ""))
			if not (stat in KNOWN_STATS):
				continue
			var affix_val: float = float(affix.get("value", 0.0))
			if stat == "insulation":
				var base_val: float = float(item_data.get("insulation", 0.0))
				result[stat] = result.get(stat, 0.0) + base_val * affix_val
			else:
				result[stat] = result.get(stat, 0.0) + affix_val
	return result

static func weapon_totals(slot_data) -> Dictionary:
	var result := {}
	if slot_data == null:
		return result
	for affix in slot_data.get("loot_affixes", []):
		var stat: String = str(affix.get("stat", ""))
		if not (stat in KNOWN_STATS):
			continue
		var affix_val: float = float(affix.get("value", 0.0))
		result[stat] = result.get(stat, 0.0) + affix_val
	return result
