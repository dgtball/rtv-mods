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
	{"stat": "fire_rate", "category": "weapon", "unit": "pct", "weight": 0.8,
		"ranges": {1: [2, 4], 2: [3, 6], 3: [4, 8]}, "release": 2},
	{"stat": "wear", "category": "weapon", "unit": "pct", "weight": 0.6,
		"ranges": {1: [2, 4], 2: [4, 8], 3: [6, 12]}, "release": 2},
	{"stat": "low_hp_damage", "category": "weapon", "unit": "pct", "weight": 0.7,
		"ranges": {1: [5, 10], 2: [8, 14], 3: [12, 20]}, "release": 2},

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
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}, "release": 1},

	# clothing, release=2 (0.4.0)
	{"stat": "noise", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [5, 8], 2: [7, 12], 3: [10, 16]}, "release": 2},
	{"stat": "sprint", "category": "clothing", "unit": "pct", "weight": 0.8,
		"ranges": {1: [1, 2], 2: [2, 4], 3: [4, 6]}, "release": 2},
	{"stat": "perception", "category": "clothing", "unit": "pct", "weight": 0.5,
		"ranges": {1: [1, 1], 2: [2, 3], 3: [3, 4]}, "release": 2},
	{"stat": "protection", "category": "clothing", "unit": "flat", "weight": 0.5,
		"ranges": {2: [1, 1], 3: [1, 1]}, "release": 2, "needs": "armor"},
	{"stat": "max_hp", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [1, 1], 2: [2, 3], 3: [3, 4]}, "release": 2},
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
	"recoil", "fire_rate", "low_hp_damage", "wear",
	"regen", "low_hp_regen",
	"stamina_drain", "thirst_drain", "hunger_drain", "sanity_drain",
	"noise", "sprint", "perception", "max_hp",
]

# ACTIVE_RELEASE: активный релиз пула. 2 = 0.3.0: статы релизов 1 и 2 (§6 D23)
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
