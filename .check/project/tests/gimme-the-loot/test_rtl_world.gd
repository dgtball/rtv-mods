extends SceneTree

const Store = preload("res://mods/RoadToLoot/RTLStore.gd")
const World = preload("res://mods/RoadToLoot/RTLWorld.gd")
const Boot = preload("res://mods/RoadToLoot/RTLBoot.gd")
const RTLSidecar = preload("res://mods/RoadToLoot/RTLSidecar.gd")

var fails := 0

# RefCounted stand-ins instead of Nodes: fresh_slots only reads properties, and
# Nodes left unparented at quit would leak into the ObjectDB warning. Slot keeps
# itemData untyped: Task 2 hands it a fake ItemData that answers get(), while
# fresh_slots only compares it against null.
class Marker extends RefCounted:
	pass

class Slot extends RefCounted:
	var itemData = null

class Pickup extends RefCounted:
	var slotData = null

# A ground pickup stand-in for the shelter path: _carry_pairs reads slotData and
# global_position, nothing else, so a RefCounted is enough.
class Ground extends RefCounted:
	var slotData = null
	var global_position := Vector3.ZERO

# FakeItem answers get() like the game's ItemData: Category.of_item() and
# Roll.build_affixes() read "type"/"slots"/needs fields through it.
class FakeItem extends RefCounted:
	var name := "AKM"
	var file := "res://Items/Weapons/AKM/AKM.tres"
	var type := "Weapon"
	var slots := ["Primary"]

class FakeRoot extends RefCounted:
	var kids: Array = []
	var rarityRoll = 100

	func get_children() -> Array:
		return kids

class FakeLib extends RefCounted:
	var _caller = null

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _slot(item):
	var sd = Slot.new()
	sd.itemData = item
	return sd

func _world_slot():
	var sd = Slot.new()
	sd.itemData = FakeItem.new()
	return sd

func _init() -> void:
	# --- dirty input ---
	ck(World.fresh_slots([]).is_empty(), "empty children -> empty")
	ck(World.fresh_slots(null).is_empty(), "null children -> empty")
	ck(World.fresh_slots([null]).is_empty(), "null child is skipped")
	# LootSimulation._ready() frees get_child(0); that marker has no slotData.
	ck(World.fresh_slots([Marker.new()]).is_empty(), "marker without slotData is skipped")
	var empty := Pickup.new()
	ck(World.fresh_slots([empty]).is_empty(), "pickup without slotData is skipped")
	var no_item := Pickup.new()
	no_item.slotData = Slot.new()
	ck(World.fresh_slots([no_item]).is_empty(), "slotData without itemData is skipped")

	# --- a fresh pickup is selected ---
	var fresh := Pickup.new()
	var sd = _slot("AKM")
	fresh.slotData = sd
	var picked: Array = World.fresh_slots([Marker.new(), fresh])
	ck(picked.size() == 1, "fresh pickup is selected")
	ck(picked[0] == sd, "the slotData itself is returned, not the node")

	# --- a rolled pickup is skipped (force tables call SpawnItems repeatedly) ---
	var rolled := Pickup.new()
	var rsd = _slot("Mosin")
	Store.stamp(rsd, 2, [])
	rolled.slotData = rsd
	ck(World.fresh_slots([rolled]).is_empty(), "already rolled pickup is skipped")
	ck(World.fresh_slots([Marker.new(), fresh, rolled]).size() == 1,
		"mixed list keeps only the fresh pickup")

	# --- a Common roll is tier 0 but still a roll: skip it too ---
	var common := Pickup.new()
	var csd = _slot("Mosin")
	Store.stamp(csd, 0, [])
	common.slotData = csd
	ck(World.fresh_slots([common]).is_empty(), "tier-0 stamped pickup is skipped")

	# --- persist=false: the roll lands on the slot, the sidecar stays untouched ---
	var boot = Boot.new()
	var dbg: Variant = boot._debug
	dbg._enabled = true
	dbg._force_tier = 3
	var live = _world_slot()
	boot._roll_into(live, {"rarity_roll": 100}, false)
	ck(Store.tier(live) == 3, "world roll stamps the forced tier")
	ck(not live.has_meta("rtl_uid"), "world roll does not mint a sidecar uid")

	# --- the hook callback rolls every fresh pickup on the caller ---
	var root := FakeRoot.new()
	var first := Pickup.new()
	first.slotData = _world_slot()
	var second := Pickup.new()
	second.slotData = _world_slot()
	root.kids = [Marker.new(), first, second]
	var lib := FakeLib.new()
	lib._caller = root
	boot._lib = lib
	boot.on_world_loot_spawned()
	ck(Store.tier(first.slotData) == 3, "callback rolls the first pickup")
	ck(Store.tier(second.slotData) == 3, "callback rolls the second pickup")
	ck(not first.slotData.has_meta("rtl_uid"), "callback leaves the first pickup without a uid")
	ck(not second.slotData.has_meta("rtl_uid"), "callback leaves the second pickup without a uid")

	# --- a second call (force tables) must not restamp anything ---
	ck(World.fresh_slots(root.kids).is_empty(), "after the callback no pickup is fresh")
	boot.on_world_loot_spawned()
	ck(Store.tier(first.slotData) == 3, "second call keeps the tier")

	# --- no modloader lib: the callback is a no-op, not a crash ---
	var bare = Boot.new()
	bare.on_world_loot_spawned()
	ck(true, "callback without a lib does not crash")

	# --- a non-zero arity would make the hook a silent no-op (callv mismatch) ---
	ck(Callable(boot, "on_world_loot_spawned").get_argument_count() == 0,
		"world callback takes no arguments")

	# --- pair_positions: saved shelter records vs live pickups ---
	var s0 := {"file": "AKM", "pos": Vector3(1, 0, 2)}
	var l0 := {"file": "AKM", "pos": Vector3(1, 0, 2.02)}
	ck(World.pair_positions([s0], [l0]).size() == 1, "close position pairs")
	ck(World.pair_positions([s0], [l0])[0] == [0, 0], "pair is [saved, live]")
	ck(World.pair_positions([{"file": "AKM", "pos": Vector3.ZERO}],
		[{"file": "AKM", "pos": Vector3(1, 0, 0)}]).is_empty(), "out of tolerance does not pair")
	ck(World.pair_positions([{"file": "AKM", "pos": Vector3.ZERO}],
		[{"file": "Mosin", "pos": Vector3.ZERO}]).is_empty(), "different file does not pair")
	# two saved items of the same model standing side by side stay separate
	var pair2: Array = World.pair_positions(
		[{"file": "AKM", "pos": Vector3(0, 0, 0)}, {"file": "AKM", "pos": Vector3(0.5, 0, 0)}],
		[{"file": "AKM", "pos": Vector3(0, 0, 0.01)}, {"file": "AKM", "pos": Vector3(0.5, 0, 0.01)}])
	ck(pair2.size() == 2, "duplicate file pairs twice")
	ck(int(pair2[0][0]) == 0 and int(pair2[1][0]) == 1, "saved order is kept")
	ck(int(pair2[0][1]) != int(pair2[1][1]), "one live pickup is used once")
	# dirty input
	ck(World.pair_positions(null, []).is_empty(), "null saved -> empty")
	ck(World.pair_positions([], null).is_empty(), "null live -> empty")
	ck(World.pair_positions([null, "x", {}], [null, {}]).is_empty(), "broken entries are skipped")

	# --- _carry_roll: a SlotData of its own, mod data copied, vanilla fields kept ---
	var src_sd := SlotData.new()
	src_sd.itemData = FakeItem.new()
	src_sd.amount = 30
	Store.stamp(src_sd, 3, [{"stat": "damage", "unit": "pct", "value": 0.2}])
	RTLSidecar.set_uid(src_sd, "AKM|1|2")
	var dst_sd := SlotData.new()
	dst_sd.itemData = src_sd.itemData
	dst_sd.amount = 7
	var ground := Pickup.new()
	ground.slotData = dst_sd
	ck(boot._carry_roll(src_sd, ground), "carry_roll reports a transfer")
	ck(ground.slotData != dst_sd, "pickup gets a SlotData of its own")
	ck(Store.tier(ground.slotData) == 3, "tier copied")
	ck(Store.affixes(ground.slotData).size() == 1, "affixes copied")
	ck(RTLSidecar.get_uid(ground.slotData) == "AKM|1|2", "uid copied")
	ck(int(ground.slotData.amount) == 7, "vanilla amount kept")
	ck(not Store.is_stamped(dst_sd), "the destination slotData is left untouched")
	# nothing to carry
	var plain := SlotData.new()
	plain.itemData = src_sd.itemData
	var plain_node := Pickup.new()
	plain_node.slotData = SlotData.new()
	ck(not boot._carry_roll(plain, plain_node), "no roll -> no transfer")
	ck(not boot._carry_roll(src_sd, plain_node), "node without itemData -> no transfer")
	ck(not boot._carry_roll(null, plain_node), "null source -> false")
	ck(not boot._carry_roll(src_sd, Marker.new()), "node without slotData -> false")

	# --- _new_children: id-diff keeps the pre-existing node out, file filter narrows ---
	var old_node := Pickup.new()
	old_node.slotData = SlotData.new()
	old_node.slotData.itemData = FakeItem.new()
	var kids_root := FakeRoot.new()
	kids_root.kids = [old_node]
	var before: Dictionary = boot._id_set(kids_root)
	var other_item := FakeItem.new()
	other_item.file = "res://Items/Weapons/Mosin/Mosin.tres"
	var other_sd := SlotData.new()
	other_sd.itemData = other_item
	var homonym := Pickup.new()
	homonym.slotData = other_sd
	var added := Pickup.new()
	added.slotData = SlotData.new()
	added.slotData.itemData = FakeItem.new()
	kids_root.kids = [old_node, homonym, added]
	ck(boot._new_children(kids_root, before).size() == 2, "id-diff keeps only the nodes added later")
	ck(boot._new_children(kids_root, before, "res://Items/Weapons/AKM/AKM.tres").size() == 1,
		"file filter drops the other model")
	ck(boot._new_children(kids_root, {}).size() == 3, "empty snapshot sees every node")
	ck(boot._new_children(null, {}).is_empty(), "null map -> empty")

	# --- _carry_pairs: each saved record finds its own live node ---
	var saved_a := SlotData.new()
	saved_a.itemData = FakeItem.new()
	Store.stamp(saved_a, 2, [])
	var saved_c := SlotData.new()
	saved_c.itemData = FakeItem.new()
	Store.stamp(saved_c, 3, [])
	var ground_a := Ground.new()
	ground_a.slotData = SlotData.new()
	ground_a.slotData.itemData = saved_a.itemData
	ground_a.global_position = Vector3(1, 0, 1)
	var ground_c := Ground.new()
	ground_c.slotData = SlotData.new()
	ground_c.slotData.itemData = saved_c.itemData
	ground_c.global_position = Vector3(3, 0, 3)
	var saved_pairs := [
		{"file": "res://Items/Weapons/AKM/AKM.tres", "pos": Vector3(1, 0, 1), "slotData": saved_a},
		{"file": "res://Items/Weapons/AKM/AKM.tres", "pos": Vector3(3, 0, 3), "slotData": saved_c},
	]
	ck(boot._carry_pairs(saved_pairs, [ground_a, ground_c]) == 2, "both saved items are carried")
	ck(Store.tier(ground_a.slotData) == 2, "the first live node got its saved roll")
	ck(Store.tier(ground_c.slotData) == 3, "the second live node got its saved roll")
	ck(boot._carry_pairs([], [ground_a]) == 0, "no saved items -> nothing carried")
	ck(boot._carry_pairs(saved_pairs, [Marker.new()]) == 0, "node without slotData is skipped")

	# --- arity: one argument each, or callv silently drops the hook ---
	ck(Callable(boot, "on_drop_pre").get_argument_count() == 1, "drop pre takes 1 argument")
	ck(Callable(boot, "on_drop_post").get_argument_count() == 1, "drop post takes 1 argument")
	ck(Callable(boot, "on_shelter_pre").get_argument_count() == 1, "shelter pre takes 1 argument")
	ck(Callable(boot, "on_shelter_loaded").get_argument_count() == 1, "shelter post takes 1 argument")
	ck(boot._shelter_saved_items("").is_empty(), "empty shelter name -> no records")
	ck(boot._shelter_saved_items(null).is_empty(), "null shelter name -> no records")

	boot.free()
	bare.free()

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
