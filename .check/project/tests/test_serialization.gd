extends Node

func _ready():
	var SD = preload("res://mods/LooterShooter/Scripts/SlotData.gd")
	var a = SD.new()
	a.loot_tier = 3
	a.loot_affixes = [{"stat": "damage", "value": 5.0, "unit": "flat"}]
	a.condition = 55

	print("BEFORE SAVE:")
	print("  loot_tier =", a.loot_tier)
	print("  loot_affixes =", JSON.stringify(a.loot_affixes))
	print("  loot_tier has @export attr =", a.get_property_list())

	# Сохраняем в temporary resource file
	var path = "res://tests/_slotdata_save.tres"
	var err = ResourceSaver.save(a, path)
	print("  ResourceSaver.save ->", err)

	# Загружаем заново
	var b = load(path)
	print("\nAFTER LOAD from .tres:")
	print("  loot_tier =", b.loot_tier)
	print("  loot_affixes =", JSON.stringify(b.loot_affixes))

	if "loot_tier" in b:
		print("  'loot_tier' IN b:", true)
	else:
		print("  'loot_tier' IN b:", false)
	if "loot_affixes" in b:
		print("  'loot_affixes' IN b:", true)
	else:
		print("  'loot_affixes' IN b:", false)

	# meta-метки
	a.set_meta("rtl_loot_tier", 3)
	a.set_meta("rtl_loot_affixes", a.loot_affixes)
	var path2 = "res://tests/_slotdata_save2.tres"
	ResourceSaver.save(a, path2)
	var c = load(path2)
	print("\nAFTER LOAD with meta:")
	print("  has_meta rtl_loot_tier:", c.has_meta("rtl_loot_tier"))
	print("  get_meta rtl_loot_tier:", c.get_meta("rtl_loot_tier"))

	# JSON serialization check
	print("\nJSON.stringify(a):", JSON.stringify(a))
	if "rtl_loot" in JSON.stringify(a):
		print("  meta попал в JSON — ХОРОШО")
	else:
		print("  meta НЕ попал в JSON — ПЛОХО")

	quit(0)
