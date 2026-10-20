extends RefCounted

const VANILLA := 0
const COMMON := 1
const RARE := 2
const LEGENDARY := 3

const TIER_NAMES := {0: "Vanilla", 1: "Common", 2: "Rare", 3: "Legendary"}

const POOL: Array = [
	{"stat": "damage", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [5, 15], 2: [10, 20], 3: [15, 30]}},
	{"stat": "recoil", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "sway", "category": "weapon", "unit": "pct", "weight": 1.0,
		"ranges": {1: [10, 20], 2: [15, 30], 3: [20, 40]}},
	{"stat": "fire_rate", "category": "weapon", "unit": "pct", "weight": 0.8,
		"ranges": {1: [5, 10], 2: [8, 14], 3: [10, 20]}},
	{"stat": "penetration", "category": "weapon", "unit": "flat", "weight": 0.6,
		"ranges": {2: [1, 1], 3: [1, 2]}},
	{"stat": "low_hp_damage", "category": "weapon", "unit": "pct", "weight": 0.7,
		"ranges": {1: [15, 25], 2: [25, 35], 3: [35, 50]}},
	{"stat": "durability", "category": "weapon", "unit": "pct", "weight": 0.8,
		"ranges": {1: [25, 40], 2: [40, 55], 3: [55, 75]}},

	{"stat": "max_hp", "category": "clothing", "unit": "hp", "weight": 1.0,
		"ranges": {1: [5, 10], 2: [10, 20], 3: [15, 50]}},
	{"stat": "regen", "category": "clothing", "unit": "rate", "weight": 1.0,
		"ranges": {1: [0.01, 0.02], 2: [0.02, 0.05], 3: [0.04, 0.08]}},
	{"stat": "low_hp_regen", "category": "clothing", "unit": "mult", "weight": 0.5,
		"ranges": {1: [2.0, 2.0], 2: [2.5, 2.5], 3: [3.0, 3.0]}},
	{"stat": "carry", "category": "clothing", "unit": "kg", "weight": 0.9,
		"ranges": {1: [2, 5], 2: [5, 8], 3: [8, 10]}},
	{"stat": "stamina_drain", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "insulation", "category": "clothing", "unit": "pct", "weight": 0.9,
		"ranges": {1: [10, 20], 2: [20, 30], 3: [30, 40]}},
	{"stat": "noise", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [10, 20], 2: [15, 30], 3: [20, 40]}},
	{"stat": "sprint", "category": "clothing", "unit": "pct", "weight": 0.8,
		"ranges": {1: [3, 6], 2: [5, 9], 3: [8, 12]}},
	{"stat": "protection", "category": "clothing", "unit": "flat", "weight": 0.5,
		"ranges": {2: [1, 1], 3: [1, 1]}},
	{"stat": "thirst_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "hunger_drain", "category": "clothing", "unit": "pct", "weight": 0.7,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
	{"stat": "sanity_drain", "category": "clothing", "unit": "pct", "weight": 0.5,
		"ranges": {1: [8, 15], 2: [12, 22], 3: [18, 30]}},
]

const UNITS := ["pct", "hp", "kg", "flat", "rate", "mult"]
const CATEGORIES := ["weapon", "clothing"]

static func entries(category: String) -> Array:
	var out: Array = []
	for e in POOL:
		if e["category"] == category:
			out.append(e)
	return out

static func affix_ids(category: String) -> Array:
	var ids: Array = []
	for e in POOL:
		if e["category"] == category and not ids.has(e["stat"]):
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
