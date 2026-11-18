extends RefCounted

const KNOWN_STATS := ["regen", "low_hp_regen", "capacity", "stamina_drain",
	"insulation", "thirst_drain", "hunger_drain", "sanity_drain",
	"damage", "recoil", "fire_rate", "low_hp_damage", "sprint", "noise",
	"protection", "extra_loot", "wear", "max_hp", "ammo_save",
	"never_jam", "unbreakable", "battery_save"]

# Читается с самого гаджета, а не из общих тоталов: три легендарных гаджета
# сложились бы в нулевой расход батарейки.
const PER_SLOT_STATS := ["battery_save"]

# Ниже этого порога срабатывают low_hp_damage и low_hp_regen.
const LOW_HP_FRACTION := 0.3
const MAX_HEALTH := 100.0

# «Меньше — лучше»: 0.12 значит x0.88. Балансного капа нет: остаётся только
# нижняя граница множителя, чтобы легаси-значение не ушло в минус.
static func reduction_factor(totals: Dictionary, stat: String) -> float:
	var t := float(totals.get(stat, 0.0))
	return clampf(1.0 - t, 0.0, 1.0)

# «Больше — лучше»: 0.12 значит x1.12. Таблицы капов больше нет.
static func bonus_factor(totals: Dictionary, stat: String) -> float:
	return maxf(0.0, 1.0 + float(totals.get(stat, 0.0)))

# Урон оружия: бонус damage плюс low_hp_damage, пока HP ниже порога.
static func damage_factor(totals: Dictionary, low_hp: bool) -> float:
	var bonus := float(totals.get("damage", 0.0))
	if low_hp:
		bonus += float(totals.get("low_hp_damage", 0.0))
	return maxf(0.0, 1.0 + bonus)

# Мёртвый (0 HP) не «на низком HP»: лечить и добивать некого.
static func is_low_hp(health: float, max_health: float = MAX_HEALTH) -> bool:
	return health > 0.0 and health <= max_health * LOW_HP_FRACTION

static func capacity_bonus(totals: Dictionary) -> float:
	return maxf(0.0, float(totals.get("capacity", 0.0)))

static func clothing_totals(slots: Array) -> Dictionary:
	var result := {}
	for slot in slots:
		var item_data: Dictionary = slot.get("item_data", {})
		var slot_data: Dictionary = slot.get("slot_data", {})
		var affixes: Array = slot_data.get("loot_affixes", []) if slot_data else []
		for affix in affixes:
			var stat: String = str(affix.get("stat", ""))
			if PER_SLOT_STATS.has(stat):
				continue
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

# Шанс, что выстрел не потратит патрон. Верхняя граница — область определения
# вероятности, а не балансный кап.
static func ammo_save_chance(totals: Dictionary) -> float:
	return clampf(float(totals.get("ammo_save", 0.0)), 0.0, 1.0)

# Ваниль списывает патрон по-разному: авто и Single уменьшают amount, Manual
# (болт) только опустошает патронник и тратит патрон позже, в Reload().
# Поэтому «выстрел состоялся» — это либо падение amount, либо chamber true -> false.
static func shot_spent_round(amount_before: int, amount_after: int, chamber_before: bool, chamber_after: bool) -> bool:
	return amount_after < amount_before or (chamber_before and not chamber_after)

# Флаг присутствия: unit "flag" всегда 1.0, поэтому значение проверяется на > 0.
static func has_flag(affixes: Array, stat: String) -> bool:
	for a in affixes:
		if not (a is Dictionary):
			continue
		if str(a.get("stat", "")) != stat:
			continue
		if float(a.get("value", 0.0)) > 0.0:
			return true
	return false

# unbreakable: base < 0 — захват текущей прочности; condition > base — ремонт,
# база поднимается; condition < base — износ, прочность возвращается к базе.
static func unbreakable_step(base: float, condition: float) -> Dictionary:
	if base < 0.0:
		return {"base": condition, "condition": condition, "changed": true}
	if condition > base:
		return {"base": condition, "condition": condition, "changed": true}
	if condition < base:
		return {"base": base, "condition": base, "changed": true}
	return {"base": base, "condition": condition, "changed": false}

# Множитель расхода батарейки одного гаджета. Максимум одного ролла — 90%,
# поэтому нулевого расхода не бывает даже без капа.
static func battery_factor(affixes: Array) -> float:
	var t := 0.0
	for a in affixes:
		if a is Dictionary and str(a.get("stat", "")) == "battery_save":
			t += float(a.get("value", 0.0))
	return clampf(1.0 - t, 0.0, 1.0)
