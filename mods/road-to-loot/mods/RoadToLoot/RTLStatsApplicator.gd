extends Node

# Applies RTL affix stats to the player and to the equipped weapon. Only pre/post
# hooks are used, never replace hooks, so Evolve and other mods keep their seams.
# The module is created and parented by RTLBoot, and registers itself in setup().

const Stats = preload("res://mods/RoadToLoot/RTLStats.gd")
const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const Category = preload("res://mods/RoadToLoot/RTLCategory.gd")

const IFACE_PATH := "/root/Map/Core/UI/Interface"
const CONTROLLER_PATH := "/root/Map/Core/Controller"

const META_BODY := "rtl_tick_body"
const META_ARM := "rtl_tick_arm"
const META_ENERGY := "rtl_tick_energy"
const META_HYDRATION := "rtl_tick_hydration"
const META_MENTAL := "rtl_tick_mental"

const META_SPRINT := "rtl_sprint_applied"
const META_FIRE_RATE := "rtl_fire_rate_applied"
const META_WEAPON_BASE := "rtl_weapon_base"

const RECOIL_FIELDS := ["horizontalRecoil", "verticalRecoil", "kick"]

var _lib = null
var _totals: Dictionary = {}
var _dirty := true

# Total of every clothing affix currently worn. Called from RTLBoot when the
# loader or the drop path changes the equipment; the interface post hook keeps
# it fresh in between.
func mark_dirty() -> void:
	_dirty = true

func setup(lib) -> void:
	if lib == null:
		return
	_lib = lib
	_lib.hook("character-stamina-pre", Callable(self, "on_stamina_pre"), 1000)
	_lib.hook("character-stamina-post", Callable(self, "on_stamina_post"), 1000)
	_lib.hook("character-energy-pre", Callable(self, "on_energy_pre"), 1000)
	_lib.hook("character-energy-post", Callable(self, "on_energy_post"), 1000)
	_lib.hook("character-hydration-pre", Callable(self, "on_hydration_pre"), 1000)
	_lib.hook("character-hydration-post", Callable(self, "on_hydration_post"), 1000)
	_lib.hook("character-mental-pre", Callable(self, "on_mental_pre"), 1000)
	_lib.hook("character-mental-post", Callable(self, "on_mental_post"), 1000)
	_lib.hook("character-health-post", Callable(self, "on_health_post"), 1000)
	_lib.hook("interface-updatestats-post", Callable(self, "on_updatestats_post"), 1000)
	_lib.hook("interface-platecheck-pre", Callable(self, "on_platecheck_pre"), 1000)
	_lib.hook("interface-platecheck-post", Callable(self, "on_platecheck_post"), 1000)
	_lib.hook("interface-helmetcheck-pre", Callable(self, "on_helmetcheck_pre"), 1000)
	_lib.hook("interface-helmetcheck-post", Callable(self, "on_helmetcheck_post"), 1000)
	_lib.hook("lootcontainer-interact-post", Callable(self, "on_lootcontainer_interact_post"), 1000)
	_lib.hook("weaponrig-fireevent-pre", Callable(self, "on_fireevent_pre"), 1000)
	_lib.hook("weaponrig-fireevent-post", Callable(self, "on_fireevent_post"), 1000)
	_lib.hook("weaponrig-fireinput-post", Callable(self, "on_fireinput_post"), 1000)

# --- totals ---------------------------------------------------------------

# Pure shape for Stats.clothing_totals: item and slot are flattened to the
# plain dictionaries the helper reads, because Object.get() takes one argument
# and the helper uses Dictionary.get().
static func totals_from_equipment(equipment) -> Dictionary:
	var rows: Array = []
	if equipment == null or not (equipment is Object) or not equipment.has_method("get_children"):
		return Stats.clothing_totals(rows)
	for slot in equipment.get_children():
		if slot == null or not (slot is Node) or slot.get_child_count() == 0:
			continue
		var item = slot.get_child(0)
		if item == null or not ("slotData" in item):
			continue
		var slot_data = item.slotData
		if slot_data == null or not ("itemData" in slot_data):
			continue
		var item_data = slot_data.itemData
		if item_data == null or Category.of_item(item_data) != Category.CLOTHING:
			continue
		rows.append({
			"item_data": {"insulation": _num(item_data.get("insulation"), 0.0)},
			"slot_data": {"loot_affixes": Store.affixes(slot_data)},
		})
	return Stats.clothing_totals(rows)

static func _num(value, fallback: float) -> float:
	if value == null:
		return fallback
	return float(value)

func _ensure_totals() -> Dictionary:
	if _dirty:
		_refresh_totals()
	return _totals

func _refresh_totals() -> void:
	_dirty = false
	var iface = _iface()
	if iface == null:
		_totals = {}
		return
	_totals = totals_from_equipment(iface.get("equipment"))

# --- character ticks ------------------------------------------------------

# Vanilla subtracts in one branch and regenerates in the other, so only a
# negative delta is scaled: a drain reduction must not slow recovery down.
func _scaled_tick(instance, meta_key: String, now: float, factor: float) -> float:
	if not instance.has_meta(meta_key):
		return now
	var before := float(instance.get_meta(meta_key))
	instance.remove_meta(meta_key)
	if factor >= 0.999:
		return now
	var diff := now - before
	if diff >= 0.0:
		return now
	return before + diff * factor

func _game_data(instance) -> Variant:
	if instance == null:
		return null
	return instance.get("gameData")

func _capture(data, meta_key: String, field: String) -> void:
	if data == null:
		return
	var value = data.get(field)
	if value != null:
		data.set_meta(meta_key, float(value))

func on_stamina_pre(_delta) -> void:
	var instance = _caller()
	var data = _game_data(instance)
	if data == null:
		return
	_capture(data, META_BODY, "bodyStamina")
	_capture(data, META_ARM, "armStamina")

func on_stamina_post(_delta) -> void:
	var instance = _caller()
	var data = _game_data(instance)
	if data == null:
		return
	var factor := Stats.reduction_factor(_ensure_totals(), "stamina_drain")
	var body := _scaled_tick(data, META_BODY, float(data.get("bodyStamina")), factor)
	var arm := _scaled_tick(data, META_ARM, float(data.get("armStamina")), factor)
	data.set("bodyStamina", body)
	data.set("armStamina", arm)

func on_energy_pre(_delta) -> void:
	_capture(_game_data(_caller()), META_ENERGY, "energy")

func on_energy_post(_delta) -> void:
	_apply_tick(META_ENERGY, "energy", "hunger_drain")

func on_hydration_pre(_delta) -> void:
	_capture(_game_data(_caller()), META_HYDRATION, "hydration")

func on_hydration_post(_delta) -> void:
	_apply_tick(META_HYDRATION, "hydration", "thirst_drain")

func on_mental_pre(_delta) -> void:
	_capture(_game_data(_caller()), META_MENTAL, "mental")

func on_mental_post(_delta) -> void:
	_apply_tick(META_MENTAL, "mental", "sanity_drain")

func _apply_tick(meta_key: String, field: String, stat: String) -> void:
	var data = _game_data(_caller())
	if data == null:
		return
	var factor := Stats.reduction_factor(_ensure_totals(), stat)
	var now := _scaled_tick(data, meta_key, float(data.get(field)), factor)
	data.set(field, now)

# Health runs before Clamp(), and death is already decided before the post hook,
# so a dead character is never healed back.
func on_health_post(delta) -> void:
	var data = _game_data(_caller())
	if data == null:
		return
	var dead = data.get("isDead")
	if dead is bool and dead:
		return
	var totals := _ensure_totals()
	var rate := float(totals.get("regen", 0.0))
	if Stats.is_low_hp(float(data.get("health"))):
		rate += float(totals.get("low_hp_regen", 0.0))
	if rate <= 0.0:
		return
	data.set("health", minf(1000.0, float(data.get("health")) + rate * float(delta)))

# --- capacity, insulation, sprint ----------------------------------------

func on_updatestats_post(update_labels) -> void:
	var iface = _caller()
	if iface == null:
		return
	_dirty = false
	_totals = totals_from_equipment(iface.get("equipment"))
	_apply_capacity(iface, update_labels)
	_apply_insulation(iface)
	_apply_sprint()

func _apply_capacity(iface, update_labels) -> void:
	var bonus := Stats.capacity_bonus(_totals)
	if bonus <= 0.0:
		return
	var capacity := float(iface.currentInventoryCapacity) + bonus
	iface.currentInventoryCapacity = capacity
	var weight := float(iface.currentInventoryWeight)
	var data = _game_data(iface)
	var character = iface.get("character")
	if data != null and character != null and weight <= capacity:
		if data.get("overweight") == true:
			character.Overweight(false)
	if not update_labels or capacity <= 0.0:
		return
	var percentage := weight / capacity
	iface.inventoryWeightPercentage = percentage
	iface.inventoryCapacity.text = str("%.1f" % capacity)
	iface.equipmentCapacity.text = str(int(round(capacity))) + "kg"
	if percentage > 1.0:
		iface.inventoryWeight.modulate = Color.RED
	elif percentage >= 0.5:
		iface.inventoryWeight.modulate = Color.YELLOW
	else:
		iface.inventoryWeight.modulate = Color.GREEN

func _apply_insulation(iface) -> void:
	var bonus := float(_totals.get("insulation", 0.0))
	if bonus <= 0.0:
		return
	var total := float(iface.currentEquipmentInsulation) + bonus
	iface.currentEquipmentInsulation = total
	var multiplier := clampf(1.0 - total / 100.0, 0.0, 1.0)
	iface.insulationMultiplier = multiplier
	var character = iface.get("character")
	if character != null:
		character.insulation = multiplier
	if iface.get("equipmentInsulation") == null:
		return
	iface.equipmentInsulation.text = str(int(round(total)))
	if total <= 25.0:
		iface.equipmentInsulation.modulate = Color.RED
	elif total <= 50.0:
		iface.equipmentInsulation.modulate = Color.YELLOW
	else:
		iface.equipmentInsulation.modulate = Color.GREEN

# The controller has no reset pass of its own, so the applied value is stored
# next to the base it came from: a second pass over the same value is a no-op,
# a value written by someone else becomes the new base, and dropping the affix
# restores the original speed.
func _apply_sprint() -> void:
	var controller = _controller()
	if controller == null or not ("sprintSpeed" in controller):
		return
	var factor := Stats.bonus_factor(_totals, "sprint")
	var current := float(controller.sprintSpeed)
	var applied = controller.get_meta(META_SPRINT) if controller.has_meta(META_SPRINT) else null
	if applied is Dictionary and absf(current - float(applied.get("scaled", -1.0))) < 0.00001:
		if factor <= 1.00001:
			controller.sprintSpeed = float(applied.get("base", current))
			controller.remove_meta(META_SPRINT)
		return
	if factor <= 1.00001:
		if applied is Dictionary:
			controller.remove_meta(META_SPRINT)
		return
	var scaled := current * factor
	controller.sprintSpeed = scaled
	controller.set_meta(META_SPRINT, {"base": current, "scaled": scaled})

# --- weapon ---------------------------------------------------------------

func on_fireevent_pre() -> void:
	var rig = _caller()
	if rig == null:
		return
	var data = rig.get("data")
	var slot_data = rig.get("slotData")
	if data == null or slot_data == null:
		return
	var totals := Stats.weapon_totals({"loot_affixes": Store.affixes(slot_data)})
	var base: Dictionary = {}
	var damage_factor := Stats.damage_factor(totals, Stats.is_low_hp(_health(rig)))
	if absf(damage_factor - 1.0) > 0.00001 and "damage" in data:
		base["damage"] = float(data.get("damage"))
		data.set("damage", float(base["damage"]) * damage_factor)
	var recoil := Stats.reduction_factor(totals, "recoil")
	if recoil < 0.999:
		for field in RECOIL_FIELDS:
			if not (field in data):
				continue
			base[field] = float(data.get(field))
			data.set(field, float(base[field]) * recoil)
	if base.is_empty():
		return
	rig.set_meta(META_WEAPON_BASE, base)

# data is shared by every rig of the same weapon scene, so it is restored right
# after the shot instead of being left scaled.
func on_fireevent_post() -> void:
	var rig = _caller()
	if rig == null or not rig.has_meta(META_WEAPON_BASE):
		return
	var base: Dictionary = rig.get_meta(META_WEAPON_BASE)
	rig.remove_meta(META_WEAPON_BASE)
	var data = rig.get("data")
	if data == null:
		return
	for field in base.keys():
		data.set(field, base[field])

	var slot_data = rig.get("slotData") if (rig is Object) and rig.has_method("get") else null
	if slot_data != null:
		var wtot := Stats.weapon_totals(Store.affixes(slot_data))
		var chance := clampf(float(wtot.get("wear", 0.0)), 0.0, 0.9)
		if chance > 0.0 and randf() < chance and "condition" in slot_data and int(slot_data.condition) > 0:
			slot_data.condition -= 1

# fireRate is a cooldown, so a fire-rate bonus divides it. Vanilla writes a fresh
# base only on the frames it fires, which is exactly what the stored pair detects.
func on_fireinput_post() -> void:
	var rig = _caller()
	if rig == null:
		return
	var current := float(rig.fireRate)
	var applied = rig.get_meta(META_FIRE_RATE) if rig.has_meta(META_FIRE_RATE) else null
	var slot_data = rig.get("slotData")
	var totals := Stats.weapon_totals({"loot_affixes": Store.affixes(slot_data)})
	var factor := Stats.bonus_factor(totals, "fire_rate")
	if applied is Dictionary and absf(current - float(applied.get("scaled", -1.0))) < 0.00001:
		if factor <= 1.00001:
			rig.fireRate = float(applied.get("base", current))
			rig.remove_meta(META_FIRE_RATE)
		return
	if factor <= 1.00001 or current <= 0.0:
		if applied is Dictionary:
			rig.remove_meta(META_FIRE_RATE)
		return
	var scaled := current / factor
	rig.fireRate = scaled
	rig.set_meta(META_FIRE_RATE, {"base": current, "scaled": scaled})


# --- protection (per-instance, temp mutate of shared ItemData) ---------------

const META_PROTECTION := "rtl_protection_base"

func on_platecheck_pre(_penetration) -> void:
	var iface = _caller()
	if iface == null or not (iface is Object) or not iface.has_method("get"):
		return
	var rigSlot = iface.get("equipmentUI")
	if rigSlot == null or not rigSlot.has_method("get_child"):
		return
	if rigSlot.get_child_count() < 8:
		return
	rigSlot = rigSlot.get_child(7)
	if rigSlot == null or not (rigSlot is Node) or rigSlot.get_child_count() == 0:
		return
	var sd = rigSlot.get_child(0).slotData if "slotData" in rigSlot.get_child(0) else null
	if sd == null:
		return
	if not ("nested" in sd):
		return
	var nested = sd.nested
	if not (nested is Array):
		return
	for itemData in nested:
		_stash_apply_protection(itemData)

func on_platecheck_post(_penetration) -> void:
	var iface = _caller()
	if iface == null or not iface.has_method("get"):
		return
	var rigSlot = iface.get("equipmentUI")
	if rigSlot == null or rigSlot.get_child_count() < 8:
		return
	rigSlot = rigSlot.get_child(7)
	if rigSlot == null or rigSlot.get_child_count() == 0:
		return
	var sd = rigSlot.get_child(0).slotData if "slotData" in rigSlot.get_child(0) else null
	if sd == null or not ("nested" in sd):
		return
	var nested = sd.nested
	if not (nested is Array):
		return
	for itemData in nested:
		_restore_protection(itemData)

func on_helmetcheck_pre(_penetration) -> void:
	var iface = _caller()
	if iface == null or not iface.has_method("get"):
		return
	var equipmentUI = iface.get("equipmentUI")
	if equipmentUI == null or equipmentUI.get_child_count() < 9:
		return
	var helmetSlot = equipmentUI.get_child(8)
	if helmetSlot == null or not (helmetSlot is Node) or helmetSlot.get_child_count() == 0:
		return
	var item = helmetSlot.get_child(0)
	if item == null or not ("slotData" in item) or item.slotData == null:
		return
	var itemData = item.slotData.itemData
	_stash_apply_protection(itemData)

func on_helmetcheck_post(_penetration) -> void:
	var iface = _caller()
	if iface == null or not iface.has_method("get"):
		return
	var equipmentUI = iface.get("equipmentUI")
	if equipmentUI == null or equipmentUI.get_child_count() < 9:
		return
	var helmetSlot = equipmentUI.get_child(8)
	if helmetSlot == null or helmetSlot.get_child_count() == 0:
		return
	var item = helmetSlot.get_child(0)
	if item == null or not ("slotData" in item) or item.slotData == null:
		return
	var itemData = item.slotData.itemData
	_restore_protection(itemData)

func _protection_bonus(itemData) -> float:
	if itemData == null:
		return 0.0
	var sd: Variant = null
	# ItemData itself may carry loot_affixes? No — affixes are on slotData.
	# For helmets, map through the item's slotData if available is handled by caller.
	return 0.0

func _stash_apply_protection(itemData) -> void:
	if itemData == null or not (itemData is Object):
		return
	if itemData.has_meta(META_PROTECTION):
		return
	var bonus := _affix_protection_for(itemData)
	if bonus <= 0.0:
		# mark as visited so restore is a no-op
		itemData.set_meta(META_PROTECTION, {"base": -1.0})
		return
	if not ("protection" in itemData):
		return
	var before := float(itemData.protection)
	itemData.protection = int(round(before + bonus))
	itemData.set_meta(META_PROTECTION, {"base": before})

func _restore_protection(itemData) -> void:
	if itemData == null or not (itemData is Object):
		return
	if not itemData.has_meta(META_PROTECTION):
		return
	var m: Dictionary = itemData.get_meta(META_PROTECTION)
	itemData.remove_meta(META_PROTECTION)
	if m.has("base") and float(m.base) >= 0.0:
		if "protection" in itemData:
			itemData.protection = m.base if m.base is int else int(round(float(m.base)))

func _affix_protection_for(itemData) -> float:
	# itemData alone has no affixes; the helmet's protection affix is stored on
	# its SlotData. The Interface HelmetCheck uses slotData.itemData.protection,
	# and rigSlot-based items use nested itemData without affixes, so this
	# descriptor resolves the bonus via the currently equipped gear totals.
	var t: Dictionary = _ensure_totals()
	return float(t.get("protection", 0.0))

# --- perception (extra loot on container open) ------------------------------

func on_lootcontainer_interact_post() -> void:
	var container = _caller()
	if container == null or not (container is Object):
		return
	# Interface lock state mirrors Evolve's guard
	var iface = null
	# attempt lock check via the same key Evolve uses
	if "locked" in container and bool(container.locked):
		return
	var totals := _ensure_totals()
	var chance := clampf(float(totals.get("perception", 0.0)), 0.0, 1.0)
	if chance <= 0.0:
		return
	if randf() >= chance:
		return
	# replicate Evolve's random-item selection from container buckets
	var item_data = _random_container_item(container)
	if item_data == null:
		return
	if container.has_method("CreateLoot"):
		container.CreateLoot(item_data)

func _random_container_item(container) -> Variant:
	if container == null:
		return null
	var rarityRoll: int = randi_range(1, 30) if ("corpse" in container and bool(container.corpse)) else randi_range(1, 100)
	if (rarityRoll == 1 or rarityRoll == 100) and "legendaryBucket" in container:
		var lb = container.legendaryBucket
		if lb is Array and lb.size() > 0 and randi_range(1, 4) == 1:
			return lb.pick_random()
	if rarityRoll <= 5 and "rareBucket" in container:
		var rb = container.rareBucket
		if rb is Array and rb.size() > 0 and randi_range(1, 2) == 1:
			return rb.pick_random()
	if "commonBucket" in container:
		var cb = container.commonBucket
		if cb is Array and cb.size() > 0:
			return cb.pick_random()
	return null


func _caller() -> Variant:
	if _lib == null or not ("_caller" in _lib):
		return null
	return _lib._caller

func _health(instance) -> float:
	var data = _game_data(instance)
	if data == null:
		return Stats.MAX_HEALTH
	var value = data.get("health")
	return Stats.MAX_HEALTH if value == null else float(value)

func _iface() -> Variant:
	var scene = _scene()
	if scene == null:
		return null
	return scene.get_node_or_null(IFACE_PATH)

func _controller() -> Variant:
	var scene = _scene()
	if scene == null:
		return null
	return scene.get_node_or_null(CONTROLLER_PATH)

func _scene() -> Variant:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.current_scene
