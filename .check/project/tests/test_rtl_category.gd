extends SceneTree

const Cat = preload("res://mods/RoadToLoot/RTLCategory.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	# оружие
	ck(Cat.of_item({"type": "Weapon", "slots": ["Primary"]}) == Cat.WEAPON, "rifle -> weapon")
	ck(Cat.of_item({"type": "Weapon", "slots": ["Primary", "Secondary"]}) == Cat.WEAPON, "pistol -> weapon")
	ck(Cat.of_item({"type": "Knife", "slots": ["Knife"]}) == Cat.WEAPON, "knife -> weapon")
	# путь ресурса больше ничего не решает: ствол KAR-21 лежит в /Weapons/, но это вложение
	ck(Cat.of_item({"type": "Attachment", "slots": [],
		"resource_path": "res://Items/Weapons/KAR-21/KAR-21_Barrel.tres"}) == Cat.OTHER,
		"weapon path does not make a weapon")
	# одежда
	ck(Cat.of_item({"type": "Clothing", "slots": ["Torso"]}) == Cat.CLOTHING, "clothing torso -> clothing")
	ck(Cat.of_item({"type": "Clothing", "slots": ["Head"]}) == Cat.CLOTHING, "clothing head -> clothing")
	ck(Cat.of_item({"type": "Backpack", "slots": ["Backpack"]}) == Cat.CLOTHING, "backpack -> clothing")
	ck(Cat.of_item({"type": "Rig", "slots": ["Rig"]}) == Cat.CLOTHING, "rig -> clothing")
	ck(Cat.of_item({"type": "Helmet", "slots": ["Helmet"]}) == Cat.CLOTHING, "helmet -> clothing")
	ck(Cat.of_item({"type": "Belt Pouch", "slots": ["Belt"]}) == Cat.CLOTHING, "belt pouch -> clothing")
	# прочее
	ck(Cat.of_item({"type": "Armor", "slots": []}) == Cat.OTHER, "armor plate -> other")
	ck(Cat.of_item({"type": "Attachment", "slots": []}) == Cat.OTHER, "attachment -> other")
	ck(Cat.of_item({"type": "Grenade", "slots": ["Grenade_1", "Grenade_2"]}) == Cat.OTHER, "grenade -> other")
	ck(Cat.of_item({"type": "Electronics", "slots": ["Light"]}) == Cat.OTHER, "flashlight -> other")
	ck(Cat.of_item({"type": "Misc", "slots": ["Map"]}) == Cat.OTHER, "map -> other")
	ck(Cat.of_item({"type": "Fishing", "slots": ["Primary", "Secondary"]}) == Cat.OTHER, "fishing rod -> other")
	ck(Cat.of_item({"type": "Instrument", "slots": ["Primary", "Secondary"]}) == Cat.OTHER, "guitar -> other")
	# грязный вход
	ck(Cat.of_item(null) == Cat.OTHER, "null -> other")
	ck(Cat.of_item({}) == Cat.OTHER, "empty dict -> other")
	ck(Cat.of_item({"type": " Misc", "slots": []}) == Cat.OTHER, "leading space type -> other")
	ck(Cat.of_item({"slots": ["Primary"]}) == Cat.WEAPON, "missing type, weapon slot -> weapon")
	# rollable
	ck(Cat.rollable({"type": "Weapon", "slots": ["Primary"]}), "rifle rollable")
	ck(Cat.rollable({"type": "Knife", "slots": ["Knife"]}), "knife rollable")
	ck(Cat.rollable({"type": "Belt Pouch", "slots": ["Belt"]}), "belt pouch rollable")
	ck(not Cat.rollable({"type": "Armor", "slots": []}), "armor plate not rollable")
	ck(not Cat.rollable({"type": "Attachment", "slots": []}), "attachment not rollable")
	ck(not Cat.rollable(null), "null not rollable")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
