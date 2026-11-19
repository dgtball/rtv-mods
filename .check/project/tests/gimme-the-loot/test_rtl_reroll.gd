extends SceneTree

const DebugMod = preload("res://mods/RoadToLoot/RTLDebug.gd")
const Display = preload("res://mods/RoadToLoot/RTLDisplay.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

class FakeCfg extends RefCounted:
	var debug_enabled: bool = true
	var debug_force_tier: int = 0
	var debug_reroll_key: int = 4194443 # KEY_KP_5
	var log_rolls: bool = false

class FakeSlotData extends Resource:
	var itemData = {"name": "Probe"}

class FakeItem extends Node:
	var slotData = null

class FakeHost extends RefCounted:
	var calls: int = 0
	func reroll_item(_item) -> bool:
		calls += 1
		return true

# Mirrors the vanilla Interface surface the reroll path touches: hoverItem plus
# a Hover() that re-reads it from the grid, exactly like Interface.Hover().
class FakeIface extends Node:
	var hoverItem = null
	var _grid_item = null
	var hover_calls: int = 0
	func Hover() -> void:
		hover_calls += 1
		hoverItem = _grid_item

func _key(code: int, physical: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.pressed = true
	e.echo = false
	e.keycode = code
	e.physical_keycode = physical
	return e

func _init() -> void:
	var dbg := DebugMod.new()
	dbg.configure(FakeCfg.new())

	# --- key matching is robust to how the event reports the code -----------
	ck(dbg.matches_reroll(_key(0, 4194443)), "physical keycode matches")
	ck(dbg.matches_reroll(_key(4194443, 0)), "logical keycode matches when physical is 0")
	ck(not dbg.matches_reroll(_key(32, 32)), "unrelated key does not match")

	# released / echo events never match
	var rel := _key(0, 4194443)
	rel.pressed = false
	ck(not dbg.matches_reroll(rel), "release does not match")
	var echo := _key(0, 4194443)
	echo.echo = true
	ck(not dbg.matches_reroll(echo), "echo does not match")

	# debug off disables the whole path even for a matching key
	var off := DebugMod.new()
	var off_cfg := FakeCfg.new()
	off_cfg.debug_enabled = false
	off.configure(off_cfg)
	ck(not off.matches_reroll(_key(0, 4194443)), "debug off: no reroll")

	# --- consecutive presses both reroll, and a stale hover is refreshed ----
	var tree := SceneTree.new()
	var map := Node.new()
	map.name = "Map"
	tree.root.add_child(map)
	var core := Node.new()
	core.name = "Core"
	map.add_child(core)
	var ui := Node.new()
	ui.name = "UI"
	core.add_child(ui)
	var iface := FakeIface.new()
	iface.name = "Interface"
	ui.add_child(iface)

	var item := FakeItem.new()
	item.slotData = FakeSlotData.new()
	iface._grid_item = item
	iface.hoverItem = item
	var host := FakeHost.new()
	var disp := Display.new()
	disp.set_host(host)

	ck(disp.reroll_hovered(tree), "press 1 rerolls the hovered item")
	ck(host.calls == 1, "press 1 counted once")

	# Second press without any mouse movement: hoverItem went stale (null),
	# the reroll path must re-acquire it instead of silently doing nothing.
	iface.hoverItem = null
	ck(disp.reroll_hovered(tree), "press 2 rerolls after stale hover without mouse movement")
	ck(host.calls == 2, "press 2 counted once")
	ck(iface.hover_calls > 0, "stale hover triggered a fresh Hover() lookup")

	# Item with no slot data is still refused.
	var bare := FakeItem.new()
	iface._grid_item = bare
	iface.hoverItem = null
	ck(not disp.reroll_hovered(tree), "hover with no slotData is refused")

	tree.free()

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
