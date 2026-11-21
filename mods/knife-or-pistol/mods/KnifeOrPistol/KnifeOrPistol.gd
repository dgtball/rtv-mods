extends Node

const Rules := preload("res://mods/KnifeOrPistol/SlotRules.gd")
const DATABASE := "/root/Database"
const GAME_DATA := "res://Resources/GameData.tres"
const PATCH_RETRY_FRAMES := 600

var _lib = null
var _gd = null
var _patched := false
var _retry := 0
var _alias_active := false
var _alias_rm = null
var _alias_primary := false
var _alias_primary_slot = null


func _ready() -> void:
	if not Engine.has_meta("RTVModLib"):
		return
	_lib = Engine.get_meta("RTVModLib")
	if _lib.get("_is_ready"):
		_register()
	else:
		_lib.frameworks_ready.connect(_register)


func _register() -> void:
	if _lib == null:
		return
	_lib.hook("weaponrig-_ready-pre", _on_weapon_ready_pre)
	_lib.hook("rigmanager-updaterig-pre", _on_update_rig_pre)
	_lib.hook("rigmanager-updaterig-post", _on_update_rig_post)
	_lib.hook("loader-loadcharacter-post", _on_load_character_post)
	_lib.hook("item-updatesprite-post", _on_update_sprite_post)


func _game_data() -> Variant:
	if _gd == null:
		_gd = load(GAME_DATA)
	return _gd


func _process(_delta: float) -> void:
	_restore_alias()
	if _patched or _retry >= PATCH_RETRY_FRAMES:
		return
	_retry += 1
	_try_patch()


func _try_patch() -> void:
	var db = get_node_or_null(DATABASE)
	if db == null:
		return
	var master = db.get("master")
	if master == null:
		return
	var items = master.get("items")
	if not (items is Array):
		return
	_patched = true
	var opened := _patch_items(items)
	print("[KnifeOrPistol] pistols opened for the knife slot: %d" % opened)


func _patch_items(items: Array) -> int:
	var opened := 0
	for item in items:
		if not Rules.is_pistol(item):
			continue
		if Rules.add_knife_slot(item.get("slots")):
			opened += 1
	return opened


func _on_load_character_post() -> void:
	_patched = false
	_retry = 0


func _on_weapon_ready_pre() -> void:
	if _lib == null:
		return
	var rig = _lib._caller
	if rig == null:
		return
	if not ("weaponSlot" in rig):
		return
	if rig.get("slotData") != null:
		return
	var gd = _game_data()
	if gd == null or not bool(gd.get("knife")):
		return
	var rm = rig.get_parent()
	if rm == null:
		return
	var slot = rm.get("knifeSlot")
	if slot == null or slot.get_child_count() == 0:
		return
	rig.set("weaponSlot", slot)
	rig.set("slotData", slot.get_child(0).slotData)


func _on_update_rig_pre(_animate) -> void:
	if _lib == null:
		return
	var rm = _lib._caller
	if rm == null:
		return
	var gd = _game_data()
	if gd == null:
		return
	var slot = rm.get("knifeSlot")
	if slot == null:
		return
	var count: int = slot.get_child_count()
	var item = null
	if count > 0:
		item = slot.get_child(0).slotData.itemData
	if not Rules.should_alias(bool(gd.get("knife")), count, item):
		return
	_alias_rm = rm
	_alias_primary = bool(gd.get("primary"))
	_alias_primary_slot = rm.get("primarySlot")
	_alias_active = true
	gd.set("primary", true)
	rm.set("primarySlot", slot)


func _on_update_rig_post(_animate) -> void:
	_restore_alias()


# Vanilla misses the height overflow of a square pistol in the 2x1 knife slot.
# Fit the sprite by height there, after vanilla has picked its own scale.
func _on_update_sprite_post() -> void:
	if _lib == null:
		return
	var item = _lib._caller
	if item == null or not bool(item.get("equipped")):
		return
	var slot = item.get("equipSlot")
	if slot == null or str(slot.get("name")) != Rules.KNIFE_SLOT:
		return
	var sd = item.get("slotData")
	if sd == null:
		return
	var data = sd.get("itemData")
	if not Rules.is_pistol(data):
		return
	var sprite = item.get("sprite")
	if sprite == null:
		return
	var scale = sprite.get("scale")
	var fit: float = Rules.knife_icon_scale(data, slot.get("size"), float(scale.x))
	if fit < 0.0:
		return
	sprite.set("scale", Vector2(fit, fit))


func _restore_alias() -> void:
	if not _alias_active:
		return
	_alias_active = false
	var gd = _game_data()
	if gd != null:
		gd.set("primary", _alias_primary)
	if is_instance_valid(_alias_rm):
		_alias_rm.set("primarySlot", _alias_primary_slot)
	_alias_rm = null
	_alias_primary_slot = null
