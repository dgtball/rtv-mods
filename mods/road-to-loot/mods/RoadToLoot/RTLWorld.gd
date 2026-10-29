extends RefCounted

const Store = preload("res://mods/RoadToLoot/RTLStore.gd")

# LootSimulation rebuilds its pickups on every map load, so only the ones it
# just created may roll. A force-table calls SpawnItems() once per item and
# keeps the earlier children, hence the is_stamped filter.
static func fresh_slots(children) -> Array:
	var out: Array = []
	if not (children is Array):
		return out
	for c in children:
		if not is_instance_valid(c):
			continue
		if not ("slotData" in c):
			continue
		var sd = c.slotData
		if sd == null:
			continue
		if not ("itemData" in sd) or sd.itemData == null:
			continue
		if Store.is_stamped(sd):
			continue
		out.append(sd)
	return out

const POS_TOLERANCE := 0.05

# LoadShelter() builds a fresh pickup per saved item and copies the position out
# of the file verbatim, so a saved record and its live pickup agree on both file
# and position. Instance ids are no help here -- the pickup did not exist before
# the load. Greedy nearest match within POS_TOLERANCE, each live entry used at
# most once, so two items of the same model standing side by side stay separate.
# Entries are { "file": String, "pos": Vector3 }; the result is [[saved, live]].
static func pair_positions(saved, live) -> Array:
	var out: Array = []
	if not (saved is Array) or not (live is Array):
		return out
	var used: Dictionary = {}
	for i in saved.size():
		var s = saved[i]
		if not (s is Dictionary):
			continue
		var sfile := str(s.get("file", ""))
		var raw_saved = s.get("pos", null)
		if sfile == "" or not (raw_saved is Vector3):
			continue
		var spos: Vector3 = raw_saved
		var best := -1
		var best_d := POS_TOLERANCE
		for j in live.size():
			if used.has(j):
				continue
			var l = live[j]
			if not (l is Dictionary):
				continue
			if str(l.get("file", "")) != sfile:
				continue
			var raw_live = l.get("pos", null)
			if not (raw_live is Vector3):
				continue
			var d: float = spos.distance_to(raw_live)
			if d <= best_d:
				best = j
				best_d = d
		if best >= 0:
			used[best] = true
			out.append([i, best])
	return out
