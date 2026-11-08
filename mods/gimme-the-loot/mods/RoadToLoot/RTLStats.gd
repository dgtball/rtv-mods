extends RefCounted

const KNOWN_STATS := ["regen", "low_hp_regen", "capacity", "stamina_drain",
	"insulation", "thirst_drain", "hunger_drain", "sanity_drain",
	"damage", "recoil", "fire_rate", "low_hp_damage", "sprint", "noise",
	"protection", "extra_loot", "wear", "max_hp"]

# Ниже этого порога срабатывают low_hp_damage и low_hp_regen.
const LOW_HP_FRACTION := 0.3
const MAX_HEALTH := 100.0

# «Меньше — лучше»: 0.12 значит x0.88. Сверху фактор зажат в 1.0, чтобы
# отрицательное значение из легаси-сейва не усиливало эффект.
static func reduction_factor(totals: Dictionary, stat: String) -> float:
	var t := float(totals.get(stat, 0.0))
	# general cap 50% reduction (drains cannot fully zero)
	return clampf(1.0 - minf(t, 0.5), 0.0, 1.0)


# «Больше — лучше»: 0.12 значит x1.12.
const BONUSES := {
	"capacity": 50.0,
	"sprint": 1.0,
	"max_hp": 1.0,
	"damage": 1.0,
	"low_hp_damage": 0.2,
	"perception": 1.0,
	"insulation": 100.0,
}
# Caps to prevent stacking from killing difficulty.
static func bonus_factor(totals: Dictionary, stat: String) -> float:
	var t := float(totals.get(stat, 0.0))
	if BONUSES.has(stat):
		t = minf(t, float(BONUSES[stat]))
	return maxf(0.0, 1.0 + t)

# Урон оружия: бонус damage плюс low_hp_damage, пока HP ниже порога.
static func damage_factor(totals: Dictionary, low_hp: bool) -> float:
	var bonus := float(totals.get("damage", 0.0))
	if low_hp:
		bonus += minf(float(totals.get("low_hp_damage", 0.0)), 0.2)
	return maxf(0.0, 1.0 + minf(bonus, 1.0))

# Мёртвый (0 HP) не «на низком HP»: лечить и добивать некого.
static func is_low_hp(health: float, max_health: float = MAX_HEALTH) -> bool:
	return health > 0.0 and health <= max_health * LOW_HP_FRACTION

static func capacity_bonus(totals: Dictionary) -> float:
	return maxf(0.0, minf(float(totals.get("capacity", 0.0)), 50.0))

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
