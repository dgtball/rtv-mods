extends SceneTree

const Appl = preload("res://mods/RoadToLoot/RTLStatsApplicator.gd")
const Stats = preload("res://mods/RoadToLoot/RTLStats.gd")

class FakeItem extends Node:
	var slotData = null

class FakeSlotData extends Resource:
	var itemData = null

class FakeRig extends Node:
	var data = null
	var slotData = null
	var bullets := 0
	var hud := 0
	func UpdateBullets() -> void:
		bullets += 1
	func UpdateHUD() -> void:
		hud += 1

class FakeSlot extends Resource:
	var loot_affixes: Array = []
	var amount := 0
	var chamber := false
	var condition := 100
	var state := ""

class FakeLib extends RefCounted:
	var _caller = null
	var skipped := false
	func skip_super() -> void:
		skipped = true

class FakeGadget extends Node:
	var lightSlot = null

class FakeIface extends Node:
	var equipmentUI = null

# аффикс есть, счётчика патронов нет: pre обязан не сохранить снимок, post — не упасть
class FakeSlotNoCounter extends Resource:
	var loot_affixes: Array = [{"stat": "ammo_save", "value": 0.9, "unit": "pct"}]

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _make_slot(slot_data) -> Node:
	var slot := Node.new()
	var item := FakeItem.new()
	item.slotData = slot_data
	slot.add_child(item)
	return slot

func _fire(appl, rig, amount_before: int, amount_after: int, chamber_before: bool, chamber_after: bool) -> void:
	rig.slotData.amount = amount_before
	rig.slotData.chamber = chamber_before
	appl.on_fireevent_pre()
	rig.slotData.amount = amount_after
	rig.slotData.chamber = chamber_after
	appl.on_fireevent_post()

func _init() -> void:
	# пустое или неподходящее снаряжение
	ck(Appl.totals_from_equipment(null).is_empty(), "null equipment -> empty")
	ck(Appl.totals_from_equipment({}).is_empty(), "non-node equipment -> empty")

	# обычный SlotData-словарь: одежда считается, оружие и пустой слот — нет
	var equipment := Node.new()
	equipment.add_child(_make_slot({
		"itemData": {"type": "Clothing", "slots": ["Torso"], "insulation": 50.0},
		"loot_affixes": [
			{"stat": "insulation", "value": 0.2, "unit": "pct"},
			{"stat": "capacity", "value": 5.0, "unit": "kg"},
			{"stat": "stamina_drain", "value": 0.1, "unit": "pct"},
			{"stat": "foo_stat", "value": 3.0, "unit": "flat"},
		],
	}))
	equipment.add_child(_make_slot({
		"itemData": {"type": "Weapon", "slots": ["Primary"]},
		"loot_affixes": [{"stat": "damage", "value": 0.2, "unit": "pct"}],
	}))
	equipment.add_child(Node.new())

	var totals: Dictionary = Appl.totals_from_equipment(equipment)
	ck(abs(totals.get("insulation", 0.0) - 10.0) < 0.001, "insulation = base 50 * 0.2")
	ck(abs(totals.get("capacity", 0.0) - 5.0) < 0.001, "capacity = 5")
	ck(abs(totals.get("stamina_drain", 0.0) - 0.1) < 0.001, "stamina_drain = 0.1")
	ck(not totals.has("damage"), "weapon affix does not leak into clothing")
	ck(not totals.has("foo_stat"), "stat outside the pool is ignored")

	# ресурс SlotData: аффиксы лежат только в метаданных (как после adopt)
	var slot_data := FakeSlotData.new()
	slot_data.itemData = {"type": "Clothing", "slots": ["Legs"], "insulation": 20.0}
	slot_data.set_meta("rtl_loot_affixes", [{"stat": "insulation", "value": 0.5, "unit": "pct"}])
	var meta_equipment := Node.new()
	meta_equipment.add_child(_make_slot(slot_data))
	var meta_totals: Dictionary = Appl.totals_from_equipment(meta_equipment)
	ck(abs(meta_totals.get("insulation", 0.0) - 10.0) < 0.001, "resource slot: meta affix 20 * 0.5")

	# два предмета складываются
	var pair := Node.new()
	pair.add_child(_make_slot({
		"itemData": {"type": "Clothing", "slots": ["Head"], "insulation": 0.0},
		"loot_affixes": [{"stat": "stamina_drain", "value": 0.05, "unit": "pct"}],
	}))
	pair.add_child(_make_slot({
		"itemData": {"type": "Clothing", "slots": ["Feet"], "insulation": 0.0},
		"loot_affixes": [{"stat": "stamina_drain", "value": 0.07, "unit": "pct"}],
	}))
	var pair_totals: Dictionary = Appl.totals_from_equipment(pair)
	ck(abs(pair_totals.get("stamina_drain", 0.0) - 0.12) < 0.001, "two items sum up")
	ck(abs(Stats.reduction_factor(pair_totals, "stamina_drain") - 0.88) < 0.001,
		"totals feed the drain factor")

	equipment.free()
	meta_equipment.free()
	pair.free()

	# --- ammo_save: возврат патрона в on_fireevent_post ---
	var appl := Appl.new()
	var lib := FakeLib.new()
	appl._lib = lib
	var rig := FakeRig.new()
	var slot := FakeSlot.new()
	rig.slotData = slot
	rig.data = {"damage": 10.0}
	lib._caller = rig

	# выстрел не потратил патрон (кулдаун/осечка) -> возврата нет
	slot.loot_affixes = [{"stat": "ammo_save", "value": 0.9, "unit": "pct"}]
	for i in 200:
		_fire(appl, rig, 100, 100, true, true)
	ck(slot.amount == 100, "no refund when the shot did not spend a round")

	# потратил -> возврат примерно в 90% случаев
	var refunds := 0
	for i in 400:
		_fire(appl, rig, 100, 99, true, true)
		if slot.amount == 100:
			refunds += 1
	ck(refunds >= 300, "ammo_save refunds ~90%% of 400 spent shots: " + str(refunds))
	ck(rig.bullets > 0, "UpdateBullets called on refund")
	ck(rig.hud > 0, "UpdateHUD called on refund")

	# болт: amount не меняется, патронник пустеет -> возврат в amount.
	# Считаем проки за серию, а не состояние после последнего выстрела:
	# одиночный промах в конце сделал бы проверку случайной.
	var bolt_refunds := 0
	for i in 50:
		_fire(appl, rig, 5, 5, true, false)
		if slot.amount == 6:
			bolt_refunds += 1
	ck(bolt_refunds >= 35, "manual bolt: chambered round refunded into amount: " + str(bolt_refunds))

	# без аффикса возврата нет
	slot.loot_affixes = []
	_fire(appl, rig, 30, 29, true, true)
	ck(slot.amount == 29, "no ammo_save: no refund")

	# повторный post без pre не возвращает второй патрон
	slot.loot_affixes = [{"stat": "ammo_save", "value": 0.9, "unit": "pct"}]
	var doubles := 0
	for i in 200:
		rig.slotData.amount = 100
		rig.slotData.chamber = true
		appl.on_fireevent_pre()
		rig.slotData.amount = 99
		appl.on_fireevent_post()
		var after_first: int = slot.amount
		appl.on_fireevent_post()
		if slot.amount != after_first:
			doubles += 1
	ck(doubles == 0, "repeated post without pre never refunds twice: " + str(doubles))

	# слот без полей счётчика не должен падать и не должен копить мету
	var bare := FakeSlotNoCounter.new()
	rig.slotData = bare
	appl.on_fireevent_pre()
	ck(not rig.has_meta("rtl_shot_pre"), "slot without amount/chamber: no snapshot stored")
	appl.on_fireevent_post()
	ck(not rig.has_meta("rtl_shot_pre"), "slot without amount/chamber does not crash the post hook")
	rig.slotData = slot

	# --- wear: теперь сопротивление, а не ускорение износа ---
	slot.loot_affixes = [{"stat": "wear", "value": 0.12, "unit": "pct"}]
	slot.amount = 30
	slot.chamber = true
	appl.on_fireevent_pre()
	ck(rig.has_meta("rtl_shot_pre"), "wear-only weapon snapshots the shot in pre")
	appl.on_fireevent_post()

	# выстрел без траты патрона: прочность не трогаем
	slot.loot_affixes = [{"stat": "wear", "value": 1.0, "unit": "pct"}]
	slot.condition = 100
	for i in 200:
		_fire(appl, rig, 30, 30, true, true)
	ck(slot.condition == 100, "wear does not roll when the dispatch spent no round: " + str(slot.condition))

	# потратил патрон: ваниль списала 1, wear возвращает её всегда при 100%
	var restored := 0
	for i in 200:
		slot.condition = 100
		rig.slotData.amount = 30
		rig.slotData.chamber = true
		appl.on_fireevent_pre()
		rig.slotData.amount = 29
		slot.condition = 99
		appl.on_fireevent_post()
		if slot.condition == 100:
			restored += 1
	ck(restored == 200, "wear restores the lost point at 100%: " + str(restored))

	# снимок не переживает post, вышедший по slotData == null
	slot.amount = 30
	slot.chamber = true
	appl.on_fireevent_pre()
	ck(rig.has_meta("rtl_shot_pre"), "pre stores the snapshot before a bailing post")
	rig.slotData = null
	appl.on_fireevent_post()
	rig.slotData = slot
	ck(not rig.has_meta("rtl_shot_pre"), "post clears the snapshot even when slotData is null")

	# --- гаджеты входят в общие тоталы, battery_save — нет ---
	var gear := Node.new()
	gear.add_child(_make_slot({
		"itemData": {"type": "Electronics", "slots": ["Time"], "insulation": 0.0},
		"loot_affixes": [
			{"stat": "extra_loot", "value": 0.03, "unit": "pct"},
			{"stat": "sanity_drain", "value": 0.05, "unit": "pct"},
			{"stat": "battery_save", "value": 0.9, "unit": "pct"},
		],
	}))
	gear.add_child(_make_slot({
		"itemData": {"type": "Electronics", "slots": ["Light"], "insulation": 0.0},
		"loot_affixes": [{"stat": "battery_save", "value": 0.9, "unit": "pct"}],
	}))
	var gear_totals: Dictionary = Appl.totals_from_equipment(gear)
	ck(absf(float(gear_totals.get("extra_loot", 0.0)) - 0.03) < 0.001, "gadget extra_loot is counted")
	ck(absf(float(gear_totals.get("sanity_drain", 0.0)) - 0.05) < 0.001, "gadget sanity_drain is counted")
	ck(not gear_totals.has("battery_save"), "battery_save stays out of the totals")
	gear.free()

	# --- battery_save: post режет только убыль ---
	var gadget := FakeGadget.new()
	var torch_slot := FakeSlot.new()
	torch_slot.loot_affixes = [{"stat": "battery_save", "value": 0.5, "unit": "pct"}]
	torch_slot.condition = 100
	gadget.lightSlot = _make_slot(torch_slot)
	lib._caller = gadget
	appl.on_consumption_pre(0.1)
	torch_slot.condition = 90
	appl.on_consumption_post(0.1)
	ck(absf(float(torch_slot.condition) - 95.0) < 0.001, "battery_save halves the drain: " + str(torch_slot.condition))

	# без аффикса убыль не трогаем
	torch_slot.loot_affixes = []
	appl.on_consumption_pre(0.1)
	torch_slot.condition = 80
	appl.on_consumption_post(0.1)
	ck(absf(float(torch_slot.condition) - 80.0) < 0.001, "no battery_save: drain untouched")

	# зарядка/рост condition не масштабируется
	torch_slot.loot_affixes = [{"stat": "battery_save", "value": 0.5, "unit": "pct"}]
	appl.on_consumption_pre(0.1)
	torch_slot.condition = 85
	appl.on_consumption_post(0.1)
	ck(absf(float(torch_slot.condition) - 85.0) < 0.001, "battery_save never slows a recharge")

	# плеер: слот берётся из equipmentUI.get_child(20)
	var iface_node := FakeIface.new()
	var ui := Node.new()
	for i in 21:
		ui.add_child(Node.new())
	var player_slot := FakeSlot.new()
	player_slot.loot_affixes = [{"stat": "battery_save", "value": 0.9, "unit": "pct"}]
	player_slot.condition = 100
	ui.get_child(20).add_child(FakeItem.new())
	ui.get_child(20).get_child(0).slotData = player_slot
	iface_node.equipmentUI = ui
	lib._caller = iface_node
	appl.on_consumption_pre(0.1)
	player_slot.condition = 90
	appl.on_consumption_post(0.1)
	ck(absf(float(player_slot.condition) - 99.0) < 0.001, "cassette drain comes from slot 20: " + str(player_slot.condition))
	iface_node.free()
	lib._caller = rig

	# --- never_jam: replace-хук WeaponRig.Malfunction ---
	var rifle_slot := FakeSlot.new()
	rifle_slot.condition = 100
	rifle_slot.loot_affixes = [{"stat": "never_jam", "value": 1.0, "unit": "flag"}]
	rifle_slot.state = ""
	rig.slotData = rifle_slot
	lib.skipped = false
	ck(not appl._hook_weaponrig_malfunction(), "never_jam returns false (no jam)")
	ck(lib.skipped, "never_jam skips vanilla")
	rifle_slot.state = "Jammed"
	appl._hook_weaponrig_malfunction()
	ck(str(rifle_slot.state) == "", "a stale Jammed state is cleared")

	rifle_slot.condition = 0
	lib.skipped = false
	ck(not appl._hook_weaponrig_malfunction(), "broken weapon returns false from the hook")
	ck(not lib.skipped, "broken weapon falls through to vanilla")

	rifle_slot.condition = 50
	rifle_slot.loot_affixes = []
	lib.skipped = false
	appl._hook_weaponrig_malfunction()
	ck(not lib.skipped, "no affix: vanilla runs")

	# --- blocked_stats: только невзятые replace-хуки ---
	appl._noise_owned = true
	appl._never_jam_owned = true
	ck(appl.blocked_stats().is_empty(), "all replace hooks owned: nothing blocked")
	appl._noise_owned = false
	appl._never_jam_owned = false
	var blocked_now: Array = appl.blocked_stats()
	ck(blocked_now.has("noise"), "unowned noise is blocked")
	ck(blocked_now.has("never_jam"), "unowned never_jam is blocked")

	rig.free()
	appl.free()

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
