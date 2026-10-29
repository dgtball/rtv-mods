extends SceneTree

const Cat = preload("res://mods/LooterShooter/LSHCategory.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(Cat.of_path("res://Items/Weapons/KA-M.tres") == Cat.WEAPON, "path Weapons -> weapon")
	ck(Cat.of_path("res://Items/Clothing/M62 Jacket.tres") == Cat.CLOTHING, "path Clothing -> clothing")
	ck(Cat.of_path("res://Items/Armor/Plate.tres") == Cat.CLOTHING, "path Armor -> clothing")
	ck(Cat.of_path("res://Items/Consumables/Water_Bottle.tres") == Cat.OTHER, "path Consumables -> other")
	ck(Cat.of_path("") == Cat.OTHER, "empty path -> other")

	var w = {"type": "Weapon", "resource_path": "res://Items/Fishing/Rod.tres"}
	ck(Cat.of_item(w) == Cat.WEAPON, "type Weapon wins over path")
	var a = {"type": "Armor", "resource_path": "res://Items/Armor/Plate.tres"}
	ck(Cat.of_item(a) == Cat.CLOTHING, "type Armor -> clothing")
	var food = {"type": "Consumable", "resource_path": "res://Items/Consumables/Water.tres"}
	ck(Cat.of_item(food) == Cat.OTHER, "consumable -> other")
	var no_type = {"resource_path": "res://Items/Weapons/VSD.tres"}
	ck(Cat.of_item(no_type) == Cat.WEAPON, "no type falls back to path")

	ck(Cat.rollable(w), "weapon rollable")
	ck(not Cat.rollable(food), "consumable not rollable")

	print("")
	if fails == 0:
		print("LSH Category tests passed")
		quit(0)
	else:
		print("LSH Category tests failed: ", fails)
		quit(1)
