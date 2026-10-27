extends RefCounted

const VANILLA := 0
const COMMON := 1
const RARE := 2
const LEGENDARY := 3

const TIER_NAMES := {0: "Vanilla", 1: "Common", 2: "Rare", 3: "Legendary"}

const POOL: Array = [
	# weapon, release=2 (0.4.0)
	{"stat": "damage", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [5, 15], 2: [10, 20], 3: [15, 30]}, "release": 2},
	{"stat": "recoil", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}, "release": 2},
	{"stat": "fire_rate", "category": "weapon", "unit": "pct", "weight": 0.8,
		"ranges": {1: [5, 10], 2: [8, 14], 3: [10, 20]}, "release": 2},
	{"stat": "low_hp_damage", "category": "weapon", "unit": "pct", "weight": 0.7,
		"ranges": {1: [15, 25], 2: [25, 35], 3: [35, 50]}, "release": 2},

	# clothing, release=1 (0.3.0)
	{"stat": "regen", "category": "clothing", "unit": "rate", "weight": 1.0,
		"ranges": {1: [0.01, 0.02], 2: [0.02, 0.05], 3: [0.04, 0.08]}, "release": 1},
	{"stat": "low_hp_regen", "category": "clothing", "unit": "rate", "weight": 0.5,
		"ranges": {1: [0.03, 0.03], 2: [0.05, 0.05], 3: [0.08, 0.08]}, "release": 1},
	{"stat": "carry", "category": "clothing", "unit": "kg", "weight": 0.9,
		"ranges": {1: [2, 5], 2: [5, 8], 3: [8, 10]}, "release": 1, "needs": "capacity"},
	{"stat": "stamina_drain", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}, "release": 1},
	{"stat": "insulation", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [10, 20], 2: [20, 30], 3: [30, 40]}, "release": 1, "needs": "insulation"},
	{"stat": "thirst_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}, "release": 1},
	{"stat": "hunger_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}, "release": 1},
	{"stat": "sanity_drain", "category": "clothing", "unit": "pct", "weight": 0.5,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}, "release": 1},

	# clothing, release=2 (0.4.0)
	{"stat": "noise", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [10, 20], 2: [15, 30], 3: [20, 40]}, "release": 2},
	{"stat": "sprint", "category": "clothing", "unit": "pct", "weight": 0.8,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}, "release": 2},
	{"stat": "protection", "category": "clothing", "unit": "flat", "weight": 0.5,
		"ranges": {2: [1, 1], 3: [1, 1]}, "release": 2, "needs": "armor"},
]

# MERGED: аффикс вписывается суммой в ванильную строку тултипа, своей строки не получает.
const MERGED := {
	"damage": "Damage",
	"carry": "Capacity",
	"insulation": "Insulation",
	"protection": "Protection",
}

# MERGED_BASE: имя поля ItemData, если оно расходится с именем стата.
# Единственное расхождение — carry: база строки Capacity лежит в `capacity`.
const MERGED_BASE := {
	"carry": "capacity",
}

# ROW_ORDER: порядок собственных строк тултипа. Слитые статы сюда не входят.
# Порядок фиксирован, чтобы список не переставлялся от предмета к предмету.
const ROW_ORDER := [
	"recoil", "fire_rate", "low_hp_damage",
	"regen", "low_hp_regen",
	"stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain",
	"noise", "sprint",
]

# ACTIVE_RELEASE: 1 = 0.3.0 только статы релиза 1 (§6 D23)
const ACTIVE_RELEASE: int = 2

const UNITS := ["pct", "hp", "kg", "flat", "rate", "mult"]
const CATEGORIES := ["weapon", "clothing"]

static func entries(category: String) -> Array:
	var out: Array = []
	for e in POOL:
		if e["category"] == category and int(e.get("release", 0)) <= ACTIVE_RELEASE:
			out.append(e)
	return out

static func affix_ids(category: String) -> Array:
	var ids: Array = []
	for e in POOL:
		if e["category"] == category and int(e.get("release", 0)) <= ACTIVE_RELEASE and not ids.has(e["stat"]):
			ids.append(e["stat"])
	ids.sort()
	return ids

static func entry(category: String, stat: String) -> Dictionary:
	for e in POOL:
		if e["category"] == category and e["stat"] == stat:
			return e
	return {}

static func validate() -> Array:
	var problems: Array = []
	var seen: Array = []
	for e in POOL:
		var cat = e.get("category", "")
		var st = e.get("stat", "")
		var tag: String = str(cat) + "/" + str(st)
		if not CATEGORIES.has(cat):
			problems.append("bad category: " + tag)
		if st == "":
			problems.append("empty stat: " + tag)
		if seen.has(tag):
			problems.append("duplicate: " + tag)
		seen.append(tag)
		if not UNITS.has(e.get("unit", "")):
			problems.append("bad unit: " + tag)
		if float(e.get("weight", 0.0)) <= 0.0:
			problems.append("bad weight: " + tag)
		var ranges = e.get("ranges", {})
		if typeof(ranges) != TYPE_DICTIONARY or ranges.is_empty():
			problems.append("no ranges: " + tag)
		else:
			for tier in ranges.keys():
				if not [COMMON, RARE, LEGENDARY].has(tier):
					problems.append("bad tier " + str(tier) + ": " + tag)
				var r = ranges[tier]
				if typeof(r) != TYPE_ARRAY or r.size() != 2:
					problems.append("bad range at tier " + str(tier) + ": " + tag)
				else:
					var r0 = float(r[0])
					var r1 = float(r[1])
					if r0 > r1:
						problems.append("bad range at tier " + str(tier) + ": " + tag)
	return problems
