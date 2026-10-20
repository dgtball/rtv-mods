extends RefCounted
class_name LSHPool

const VANILLA := 0
const COMMON := 1
const RARE := 2
const LEGENDARY := 3

const TIER_NAMES := {0: "Vanilla", 1: "Common", 2: "Rare", 3: "Legendary"}

const _WEAPON_ENTRIES := [
	{
		"stat": "damage",
		"category": "weapon",
		"unit": "pct",
		"weight": 100.0,
		"ranges": {1: [5, 15], 2: [10, 25], 3: [15, 30]}
	},
	{
		"stat": "recoil",
		"category": "weapon",
		"unit": "pct",
		"weight": 90.0,
		"ranges": {1: [-15, -5], 2: [-25, -10], 3: [-40, -15]}
	},
	{
		"stat": "sway",
		"category": "weapon",
		"unit": "pct",
		"weight": 85.0,
		"ranges": {1: [-15, -5], 2: [-25, -10], 3: [-40, -15]}
	},
	{
		"stat": "fire_rate",
		"category": "weapon",
		"unit": "pct",
		"weight": 80.0,
		"ranges": {1: [5, 12], 2: [10, 20], 3: [15, 30]}
	},
	{
		"stat": "penetration",
		"category": "weapon",
		"unit": "flat",
		"weight": 40.0,
		"ranges": {2: [1, 1], 3: [1, 2]}
	},
	{
		"stat": "low_hp_damage",
		"category": "weapon",
		"unit": "pct",
		"weight": 40.0,
		"ranges": {2: [15, 30], 3: [25, 50]}
	},
	{
		"stat": "durability",
		"category": "weapon",
		"unit": "pct",
		"weight": 70.0,
		"ranges": {1: [5, 15], 2: [10, 25], 3: [15, 40]}
	}
]

const _CLOTHING_ENTRIES := [
	{
		"stat": "max_hp",
		"category": "clothing",
		"unit": "hp",
		"weight": 100.0,
		"ranges": {1: [5, 10], 2: [8, 15], 3: [15, 50]}
	},
	{
		"stat": "regen",
		"category": "clothing",
		"unit": "hp",
		"weight": 90.0,
		"ranges": {1: [0.1, 0.25], 2: [0.15, 0.4], 3: [0.25, 0.6]}
	},
	{
		"stat": "low_hp_regen",
		"category": "clothing",
		"unit": "hp",
		"weight": 40.0,
		"ranges": {2: [0.15, 0.4], 3: [0.25, 0.6]}
	},
	{
		"stat": "carry",
		"category": "clothing",
		"unit": "kg",
		"weight": 95.0,
		"ranges": {1: [1, 3], 2: [2, 5], 3: [3, 8]}
	},
	{
		"stat": "stamina_drain",
		"category": "clothing",
		"unit": "pct",
		"weight": 90.0,
		"ranges": {1: [-10, -5], 2: [-20, -8], 3: [-30, -15]}
	},
	{
		"stat": "insulation",
		"category": "clothing",
		"unit": "pct",
		"weight": 80.0,
		"ranges": {1: [5, 10], 2: [10, 20], 3: [15, 30]}
	},
	{
		"stat": "noise",
		"category": "clothing",
		"unit": "pct",
		"weight": 80.0,
		"ranges": {1: [-10, -5], 2: [-20, -10], 3: [-40, -20]}
	},
	{
		"stat": "sprint",
		"category": "clothing",
		"unit": "pct",
		"weight": 85.0,
		"ranges": {1: [2, 5], 2: [5, 10], 3: [8, 15]}
	},
	{
		"stat": "protection",
		"category": "clothing",
		"unit": "pct",
		"weight": 95.0,
		"ranges": {1: [2, 5], 2: [5, 10], 3: [8, 15]}
	},
	{
		"stat": "thirst_drain",
		"category": "clothing",
		"unit": "pct",
		"weight": 70.0,
		"ranges": {1: [-10, -5], 2: [-20, -10], 3: [-30, -15]}
	},
	{
		"stat": "hunger_drain",
		"category": "clothing",
		"unit": "pct",
		"weight": 70.0,
		"ranges": {1: [-10, -5], 2: [-20, -10], 3: [-30, -15]}
	},
	{
		"stat": "sanity_drain",
		"category": "clothing",
		"unit": "pct",
		"weight": 60.0,
		"ranges": {1: [-10, -5], 2: [-20, -10], 3: [-40, -20]}
	}
]

static func _all_entries() -> Array:
	return _WEAPON_ENTRIES + _CLOTHING_ENTRIES

static func entries(category: String) -> Array:
	var out: Array = []
	for e in _all_entries():
		if e["category"] == category:
			out.append(e)
	return out

static func affix_ids(category: String) -> Array:
	var seen := {}
	var out: Array = []
	for e in entries(category):
		var s: String = e["stat"]
		if not seen.has(s):
			seen[s] = true
			out.append(s)
	out.sort()
	return out

static func entry(category: String, stat: String) -> Dictionary:
	for e in entries(category):
		if e["stat"] == stat:
			return e
	return {}

static func validate() -> Array:
	var errs: Array = []
	for e in _all_entries():
		var cat: String = e.get("category", "")
		if cat != "weapon" and cat != "clothing":
			errs.append("bad category: %s" % cat)
		var stat: String = e.get("stat", "")
		if stat.is_empty():
			errs.append("empty stat")
		var unit: String = e.get("unit", "")
		if unit.is_empty():
			errs.append("empty unit for %s" % stat)
		var rngs: Dictionary = e.get("ranges", {})
		if rngs.is_empty():
			errs.append("no ranges for %s" % stat)
		for tier in rngs.keys():
			if typeof(tier) != TYPE_INT:
				errs.append("tier key not int for %s" % stat)
			var r: Array = rngs[tier]
			if r.size() != 2:
				errs.append("range not [min,max] for %s" % stat)
			else:
				if typeof(r[0]) != TYPE_FLOAT and typeof(r[0]) != TYPE_INT:
					errs.append("range min not number for %s" % stat)
				if typeof(r[1]) != TYPE_FLOAT and typeof(r[1]) != TYPE_INT:
					errs.append("range max not number for %s" % stat)
				if r[0] > r[1]:
					errs.append("range min>max for %s" % stat)
	return errs
