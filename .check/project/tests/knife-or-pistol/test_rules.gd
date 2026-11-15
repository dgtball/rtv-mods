extends SceneTree

const Rules = preload("res://mods/KnifeOrPistol/SlotRules.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_is_pistol()
	t_add_knife_slot()
	t_should_alias()
	print("")
	if fails == 0:
		print("KnifeOrPistol tests passed")
		quit(0)
	else:
		print("KnifeOrPistol tests failed: ", fails)
		quit(1)

func t_is_pistol() -> void:
	ck(Rules.is_pistol({"type": "Weapon", "subtype": "Pistol"}), "weapon + pistol")
	ck(Rules.is_pistol({"type": " Weapon ", "subtype": " Pistol "}), "leading/trailing spaces")
	ck(Rules.is_pistol({"type": "weapon", "subtype": "PISTOL"}), "different case")
	ck(not Rules.is_pistol({"type": "Weapon", "subtype": "Rifle"}), "rifle rejected")
	ck(not Rules.is_pistol({"type": "Weapon", "subtype": "SMG"}), "smg rejected")
	ck(not Rules.is_pistol({"type": "Weapon", "subtype": "Shotgun"}), "shotgun rejected")
	ck(not Rules.is_pistol({"type": "Knife", "subtype": ""}), "knife rejected")
	ck(not Rules.is_pistol({"type": "Weapon"}), "missing subtype rejected")
	ck(not Rules.is_pistol(null), "null rejected")

func t_add_knife_slot() -> void:
	var slots := ["Primary", "Secondary"]
	ck(Rules.add_knife_slot(slots), "appends Knife")
	ck(slots == ["Primary", "Secondary", "Knife"], "keeps order")
	ck(not Rules.add_knife_slot(slots), "second call is a no-op")
	ck(slots.size() == 3, "no duplicate Knife")
	var knives := ["Knife"]
	ck(not Rules.add_knife_slot(knives), "knife array untouched")
	ck(knives == ["Knife"], "knife array unchanged")
	ck(not Rules.add_knife_slot(null), "null slots rejected")
	ck(not Rules.add_knife_slot("Primary,Secondary"), "string slots rejected")
	var empty: Array = []
	ck(Rules.add_knife_slot(empty), "empty array gets Knife")
	ck(Rules.has_knife_slot(empty), "has_knife_slot sees it")
	ck(not Rules.has_knife_slot(null), "has_knife_slot on null is false")

func t_should_alias() -> void:
	var pistol := {"type": "Weapon", "subtype": "Pistol"}
	ck(Rules.should_alias(true, 1, pistol), "drawn knife slot with pistol aliases")
	ck(not Rules.should_alias(false, 1, pistol), "not drawn: no alias")
	ck(not Rules.should_alias(true, 0, pistol), "empty slot: no alias")
	ck(not Rules.should_alias(true, 1, {"type": "Weapon", "subtype": "Rifle"}), "rifle in slot: no alias")
	ck(not Rules.should_alias(true, 1, null), "null item: no alias")
