extends SceneTree

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	var SD = load("res://mods/LooterShooter/Scripts/SlotData.gd")
	ck(SD != null, "override script loads")

	var a = SD.new()
	ck(a.loot_tier == 0, "loot_tier default 0")
	ck(a.loot_affixes.is_empty(), "loot_affixes default empty")

	a.loot_tier = 3
	a.loot_affixes = [{"stat": "damage", "value": 0.2}]
	a.condition = 55
	a.amount = 7

	var b = SD.new()
	b.Update(a)
	ck(b.loot_tier == 3, "Update copies loot_tier")
	ck(b.loot_affixes.size() == 1, "Update copies loot_affixes")
	ck(b.loot_affixes[0]["stat"] == "damage", "Update copies affix payload")
	ck(b.condition == 55 and b.amount == 7, "super.Update still copies vanilla fields")

	b.Reset()
	ck(b.loot_tier == 0, "Reset clears loot_tier")
	ck(b.loot_affixes.is_empty(), "Reset clears loot_affixes")
	ck(b.condition == 100 and b.amount == 0, "super.Reset still resets vanilla fields")

	print("")
	if fails == 0:
		print("LSH SlotData tests passed")
		quit(0)
	else:
		print("LSH SlotData tests failed: ", fails)
		quit(1)
