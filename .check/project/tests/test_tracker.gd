extends SceneTree

const T = preload("res://mods/ThermalVTK/VTKTracker.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_new_entry()
	t_apply_state_change_gate()
	t_death_cools()
	t_pick_nearest_cap()
	t_nomad_detection()
	t_read_faction()
	t_tag_trig()
	t_pick_trig_priority_and_erasure()
	t_trig_fade()
	t_empty_window_shared()
	t_pick_nearest_reuses_out()
	print("")
	if fails == 0:
		print("Tracker tests passed")
		quit(0)
	else:
		print("Tracker tests failed: ", fails)
		quit(1)

func t_new_entry() -> void:
	var e: Dictionary = T.new_entry(7, false, 100.0)
	ck(int(e["id"]) == 7, "id stored")
	ck(e["nomad"] == false, "nomad false")
	ck(e["dead"] == false, "dead false")
	ck(int(e["cat"]) == 0, "cat defaults NORMAL")

func t_apply_state_change_gate() -> void:
	var e: Dictionary = T.new_entry(1, false, 0.0)
	ck(T.apply_state(e, 8) == true, "first state 8 reports change")
	ck(int(e["cat"]) == 1, "cat COMBAT (==1) after state 8")
	ck(T.apply_state(e, 11) == false, "state 11 (Attack) same category reports no change")
	ck(T.apply_state(e, 5) == true, "state 5 (Cover) moves to DEFEND")
	ck(int(e["cat"]) == 2, "cat DEFEND (==2) after state 5")
	ck(T.apply_state(e, 0) == true, "state 0 reports change back to NORMAL")
	ck(int(e["cat"]) == 0, "cat NORMAL (==0) after state 0")

func t_death_cools() -> void:
	var e: Dictionary = T.new_entry(1, false, 10.0)
	T.mark_dead(e, 10.0)
	ck(e["dead"] == true, "dead set")
	ck(is_equal_approx(T.cool_factor(e, 10.0, 8.0), 0.0), "cool 0 at death")
	ck(is_equal_approx(T.cool_factor(e, 14.0, 8.0), 0.5), "cool 0.5 at half decay")
	ck(is_equal_approx(T.cool_factor(e, 30.0, 8.0), 1.0), "cool clamps to 1")
	ck(is_equal_approx(T.cool_factor(e, 30.0, 0.0), 0.0), "decay 0 keeps cool 0")

func t_pick_nearest_cap() -> void:
	var cand := []
	for i in 30:
		cand.append({"id": i, "dist": float(30 - i)})
	var picked: Array = T.pick_nearest(cand, 24)
	ck(picked.size() == 24, "cap 24 respected")
	ck(int(picked[0]) == 29, "nearest first (id 29, dist 1)")

func t_nomad_detection() -> void:
	ck(T.is_nomad_faction(0) == true, "faction 0 -> nomad")
	ck(T.is_nomad_faction(1) == false, "faction 1 -> hostile")
	ck(T.is_nomad_faction(4) == false, "faction 4 -> hostile")

func t_read_faction() -> void:
	ck(T.read_faction(null) == 1, "null variant -> hostile 1")
	var d: Dictionary = {"faction": 0}
	ck(T.read_faction(d) == 0, "dict faction 0 -> nomad")
	var d2: Dictionary = {"faction": 3}
	ck(T.read_faction(d2) == 3, "dict faction 3")

# ---------------------------------------------------------------------------
# Trigger mode
# ---------------------------------------------------------------------------

func t_tag_trig() -> void:
	var e: Dictionary = T.new_entry(1, false, 0.0)
	ck(T.pick_trig(e, 1.0).is_empty(), "untagged entry shows nothing")
	T.tag_trig(e, "fire", 100.0, 5.0, 5.0)
	var ev: Dictionary = T.pick_trig(e, 1.0)
	ck(not ev.is_empty(), "tagged entry shows")
	ck(str(ev["source"]) == "fire" and is_equal_approx(float(ev["dist"]), 100.0), "source and dist carried")
	T.tag_trig(e, "voice", 20.0, 4.0, 5.0)
	ck(str(T.pick_trig(e, 1.0)["source"]) == "fire", "second source does not outrank fire")

func t_pick_trig_priority_and_erasure() -> void:
	var e: Dictionary = T.new_entry(1, false, 0.0)
	# fire window lives 6 s, voice window 5 s: past 6 s only voice remains, but
	# expired entries are erased by pick itself.
	T.tag_trig(e, "fire", 100.0, 6.0, 6.0)
	T.tag_trig(e, "voice", 20.0, 7.0, 5.0)
	ck(str(T.pick_trig(e, 5.0)["source"]) == "fire", "fire outranks voice while alive")
	ck(str(T.pick_trig(e, 6.2)["source"]) == "voice", "expired fire falls away")
	T.tag_trig(e, "walk", 10.0, 10.0, 1.5)
	T.tag_trig(e, "pain", 15.0, 9.0, 3.0)
	T.tag_trig(e, "reload", 12.0, 12.0, 2.0)
	T.tag_trig(e, "grenade", 60.0, 12.5, 6.0)
	ck(str(T.pick_trig(e, 8.0)["source"]) == "grenade", "grenade outranks pain/reload/walk")
	ck(str(T.pick_trig(e, 12.1)["source"]) == "grenade", "grenade outlives pain/reload/walk")
	ck(T.pick_trig(e, 12.6).is_empty(), "everything expired -> nothing drawn")
	ck(e["trig"].is_empty(), "pick erases expired windows from the entry")

	# Walk and idle share the lowest tier: the later expiry must not outrank a
	# live walk window, so movement stays visible while the bot creeps about.
	T.tag_trig(e, "walk", 10.0, 14.0, 1.0)
	T.tag_trig(e, "idle", 5.0, 14.2, 2.0)
	ck(str(T.pick_trig(e, 12.2)["source"]) == "walk", "walk outranks idle despite idle's later expiry")

func t_trig_fade() -> void:
	var e: Dictionary = T.new_entry(1, false, 0.0)
	T.tag_trig(e, "fire", 100.0, 6.0, 6.0)
	var ev: Dictionary = T.pick_trig(e, 0.0)
	ck(is_equal_approx(T.fade_factor(ev, 0.0), 1.0), "fade 1 at the tag")
	ck(is_equal_approx(T.fade_factor(ev, 3.0), 0.5), "fade 0.5 halfway")
	ck(is_equal_approx(T.fade_factor(ev, 5.9), 0.1 / 6.0), "fade nears zero at the tail")
	ck(is_equal_approx(T.fade_factor(T.pick_trig(e, 5.99), 6.0), 0.0), "fade clamps to 0 at expiry")

func t_empty_window_shared() -> void:
	var a: Dictionary = T.pick_trig({"trig": {}}, 0.0)
	var b: Dictionary = T.pick_trig({"trig": {}}, 0.0)
	# Godot 4.6 pools a const Dictionary per access site, so the returned window
	# is never the same instance as T.EMPTY_WINDOW read from here; what the
	# constant does guarantee is an empty, read-only, shared container.
	ck(a.is_empty() and a == T.EMPTY_WINDOW and a.is_read_only(), "no window returns the shared constant")
	ck(is_same(a, b), "two calls do not allocate separate windows")

func t_pick_nearest_reuses_out() -> void:
	var cands := [{"id": 3, "dist": 30.0}, {"id": 1, "dist": 10.0}, {"id": 2, "dist": 20.0}]
	var out: Array = [99]
	var same: Array = T.pick_nearest(cands, 2, out)
	ck(is_same(same, out), "the caller's array is returned")
	ck(out == [1, 2], "nearest two ids filled into it")
	ck(cands[0]["id"] == 3, "the input array is not reordered")
	ck(T.pick_nearest(cands, 2) == [1, 2], "the two-argument call still works")
