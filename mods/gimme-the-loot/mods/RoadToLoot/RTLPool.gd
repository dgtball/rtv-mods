extends RefCounted

const VANILLA := 0
const COMMON := 1
const RARE := 2
const LEGENDARY := 3

const TIER_NAMES := {0: "Vanilla", 1: "Common", 2: "Rare", 3: "Legendary"}

const POOL: Array = [
	# weapon, release=2 (0.4.0)
	{"stat": "damage", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [2, 6], 2: [4, 8], 3: [6, 12]}, "release": 2},
	{"stat": "recoil", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [1, 2], 2: [2, 4], 3: [4, 6]}, "release": 2},
	{"stat": "wear", "category": "weapon", "unit": "pct", "weight": 0.6,
		"ranges": {1: [10, 20], 2: [20, 35], 3: [35, 60]}, "release": 2},
	{"stat": "low_hp_damage", "category": "weapon", "unit": "pct", "weight": 0.7,
		"ranges": {1: [5, 10], 2: [8, 14], 3: [12, 20]}, "release": 2},
	{"stat": "ammo_save", "category": "weapon", "unit": "pct", "weight": 0.6,
		"ranges": {1: [5, 10], 2: [10, 15], 3: [15, 50]}, "release": 2, "needs": "firearm"},
	{"stat": "never_jam", "category": "weapon", "unit": "flag", "weight": 0.1,
		"ranges": {2: [1, 1], 3: [1, 1]}, "release": 3, "needs": "firearm"},
	{"stat": "unbreakable", "category": "weapon", "unit": "flag", "weight": 0.04,
		"ranges": {3: [1, 1]}, "release": 3, "needs": "durable",
		"categories": ["weapon", "clothing"]},

	# clothing, release=1 (0.3.0)
	{"stat": "regen", "category": "clothing", "unit": "rate", "weight": 1.0,
		"ranges": {1: [0.005, 0.01], 2: [0.01, 0.025], 3: [0.02, 0.04]}, "release": 1},
	{"stat": "low_hp_regen", "category": "clothing", "unit": "rate", "weight": 0.5,
		"ranges": {1: [0.015, 0.015], 2: [0.025, 0.025], 3: [0.04, 0.04]}, "release": 1},
	{"stat": "capacity", "category": "clothing", "unit": "kg", "weight": 0.9,
		"ranges": {1: [1, 2], 2: [2, 4], 3: [4, 6]}, "release": 1, "needs": "capacity"},
	{"stat": "stamina_drain", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}, "release": 1},
	{"stat": "insulation", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [4, 8], 2: [8, 12], 3: [12, 16]}, "release": 1, "needs": "insulation"},
	{"stat": "thirst_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}, "release": 1},
	{"stat": "hunger_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}, "release": 1},
	{"stat": "sanity_drain", "category": "clothing", "unit": "pct", "weight": 0.5,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}, "release": 1,
		"categories": ["clothing", "gadget"], "needs": "comfort"},

	# clothing, release=2 (0.4.0)
	{"stat": "noise", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [5, 8], 2: [7, 12], 3: [10, 16]}, "release": 2},
	{"stat": "sprint", "category": "clothing", "unit": "pct", "weight": 0.8,
		"ranges": {1: [1, 2], 2: [2, 4], 3: [4, 6]}, "release": 2},
	{"stat": "extra_loot", "category": "clothing", "unit": "pct", "weight": 0.5,
		"ranges": {1: [1, 1], 2: [2, 3], 3: [3, 4]}, "release": 2,
		"categories": ["clothing", "gadget"], "needs": "comfort"},
	{"stat": "protection", "category": "clothing", "unit": "flat", "weight": 0.5,
		"ranges": {2: [1, 1], 3: [1, 1]}, "release": 2, "needs": "armor"},
	{"stat": "max_hp", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [1, 5], 2: [5, 15], 3: [15, 30]}, "release": 2},

	# clothing, release=4 (1.2.2)
	{"stat": "frost_resistant", "category": "clothing", "unit": "flag", "weight": 0.25,
		"ranges": {3: [1, 1]}, "release": 4},

	# gadget, release=3 (1.2.0)
	{"stat": "battery_save", "category": "gadget", "unit": "pct", "weight": 0.8,
		"ranges": {1: [5, 10], 2: [20, 50], 3: [70, 90]}, "release": 3, "needs": "battery"},
]

# MERGED: аффикс вписывается суммой в ванильную строку тултипа, своей строки не получает.
const MERGED := {
	"damage": "Damage",
	"capacity": "Capacity",
	"insulation": "Insulation",
	"protection": "Protection",
}

# MERGED_BASE: имя поля ItemData
const MERGED_BASE := {
	"capacity": "capacity",
}

# ROW_ORDER: порядок собственных строк тултипа. Слитые статы сюда не входят.
# Порядок фиксирован, чтобы список не переставлялся от предмета к предмету.
const ROW_ORDER := [
	"recoil", "low_hp_damage", "wear", "ammo_save", "never_jam", "unbreakable",
	"regen", "low_hp_regen",
	"stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain",
	"noise", "sprint", "extra_loot", "max_hp", "frost_resistant", "battery_save",
]

# ACTIVE_RELEASE: активный релиз пула. 4 = 1.2.2: статы релизов 1-4.
# Новый стат попадает только на только что созданный лут: ролл хранится в слоте
# с момента создания, ретрофить уже разложенные предметы не нужно.
const ACTIVE_RELEASE: int = 4

const UNITS := ["pct", "hp", "kg", "flat", "rate", "mult", "flag"]
const CATEGORIES := ["weapon", "clothing", "gadget"]

# Запись может лежать в нескольких категориях (extra_loot: одежда + гаджеты,
# unbreakable: оружие + снаряжение), поэтому category — основная, а categories —
# дополнительные. Один стат = одна запись, диапазоны правятся в одном месте.
static func _cats(e: Dictionary) -> Array:
	var out: Array = []
	var primary := str(e.get("category", ""))
	if primary != "":
		out.append(primary)
	var extra = e.get("categories", null)
	if extra is Array:
		for c in extra:
			var cs := str(c)
			if not out.has(cs):
				out.append(cs)
	return out

static func _in_category(e: Dictionary, category: String) -> bool:
	return _cats(e).has(category)

static func entries(category: String) -> Array:
	var out: Array = []
	for e in POOL:
		if _in_category(e, category) and int(e.get("release", 0)) <= ACTIVE_RELEASE:
			out.append(e)
	return out

static func affix_ids(category: String) -> Array:
	var ids: Array = []
	for e in POOL:
		if _in_category(e, category) and int(e.get("release", 0)) <= ACTIVE_RELEASE and not ids.has(e["stat"]):
			ids.append(e["stat"])
	ids.sort()
	return ids

static func entry(category: String, stat: String) -> Dictionary:
	for e in POOL:
		if _in_category(e, category) and e["stat"] == stat:
			return e
	return {}

static func validate() -> Array:
	var problems: Array = []
	var seen: Array = []
	for e in POOL:
		var st = e.get("stat", "")
		var cats := _cats(e)
		if cats.is_empty():
			problems.append("no category: " + str(st))
		for cat in cats:
			if not CATEGORIES.has(cat):
				problems.append("bad category: " + str(cat) + "/" + str(st))
		if st == "":
			problems.append("empty stat: " + str(st))
		if seen.has(st):
			problems.append("duplicate: " + str(st))
		seen.append(st)
		if not UNITS.has(e.get("unit", "")):
			problems.append("bad unit: " + str(st))
		if float(e.get("weight", 0.0)) <= 0.0:
			problems.append("bad weight: " + str(st))
		var ranges = e.get("ranges", {})
		if typeof(ranges) != TYPE_DICTIONARY or ranges.is_empty():
			problems.append("no ranges: " + str(st))
		else:
			for tier in ranges.keys():
				if not [COMMON, RARE, LEGENDARY].has(tier):
					problems.append("bad tier " + str(tier) + ": " + str(st))
				var r = ranges[tier]
				if typeof(r) != TYPE_ARRAY or r.size() != 2:
					problems.append("bad range at tier " + str(tier) + ": " + str(st))
				else:
					var r0 = float(r[0])
					var r1 = float(r[1])
					if r0 > r1:
						problems.append("bad range at tier " + str(tier) + ": " + str(st))
	return problems
