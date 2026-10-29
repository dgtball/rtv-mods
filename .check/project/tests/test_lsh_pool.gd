extends SceneTree

const Pool = preload("res://mods/LooterShooter/LSHPool.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Pool.validate().is_empty(), "pool passes validation: " + str(Pool.validate()))

	var w: Array = Pool.affix_ids("weapon")
	ck(w.size() == 7, "7 weapon affixes")
	for need in ["damage", "recoil", "sway", "fire_rate", "penetration", "low_hp_damage", "durability"]:
		ck(w.has(need), "weapon pool has " + need)

	var c: Array = Pool.affix_ids("clothing")
	ck(c.size() == 12, "12 clothing affixes")
	for need in ["max_hp", "regen", "low_hp_regen", "carry", "stamina_drain", "insulation",
			"noise", "sprint", "protection", "thirst_drain", "hunger_drain", "sanity_drain"]:
		ck(c.has(need), "clothing pool has " + need)

	var d: Dictionary = Pool.entry("weapon", "damage")
	ck(d["category"] == "weapon", "damage entry category")
	ck(d["ranges"][1] == [5, 15], "damage common range 5..15 as fractions")
	ck(d["ranges"][3] == [15, 30], "damage legendary range 15..30")

	var pen: Dictionary = Pool.entry("weapon", "penetration")
	ck(not pen["ranges"].has(1), "penetration not rolled at Common")
	ck(pen["ranges"][2] == [1, 1], "penetration rare flat +1")
	ck(pen["ranges"][3] == [1, 2], "penetration legendary +1..2")

	var rare_ids: Array = []
	for id in Pool.affix_ids("weapon"):
		var e: Dictionary = Pool.entry("weapon", id)
		if e["ranges"].has(2):
			rare_ids.append(id)
	ck(rare_ids.size() >= 2, "at least two weapon affixes are rollable at Rare")

	var hp: Dictionary = Pool.entry("clothing", "max_hp")
	ck(hp["ranges"][3] == [15, 50], "max_hp legendary 15..50")

	ck(Pool.entry("weapon", "nope").is_empty(), "unknown stat returns empty")
	ck(Pool.entry("weapon", "regen").is_empty(), "clothing stat not in weapon pool")

	print("")
	if fails == 0:
		print("LSH Pool tests passed")
		quit(0)
	else:
		print("LSH Pool tests failed: ", fails)
		quit(1)
