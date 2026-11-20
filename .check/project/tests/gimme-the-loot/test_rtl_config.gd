extends SceneTree

const ConfigRec = preload("res://mods/RoadToLoot/RTLConfig.gd")
const Boot = preload("res://mods/RoadToLoot/RTLBoot.gd")
const Display = preload("res://mods/RoadToLoot/RTLDisplay.gd")

class FakeSlot extends RefCounted:
	var loot_tier: int = 0

class PaintedCell extends Panel:
	var slotData = null

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	ck(ConfigRec.FREQ_DEFAULT == 0.5, "FREQ_DEFAULT == 0.5")
	ck(ConfigRec.new().freq_mult == ConfigRec.FREQ_DEFAULT, "fresh config uses FREQ_DEFAULT")

	# пустой config.ini (первый запуск) не сбивает дефолт
	var fresh := ConfigRec.new()
	fresh.read(ConfigFile.new())
	ck(fresh.freq_mult == 0.5, "missing key keeps 0.5, got " + str(fresh.freq_mult))

	# пользовательское значение из config.ini по-прежнему главнее
	var cfg := ConfigFile.new()
	cfg.set_value("Float", "freq_mult", {"name": "Rarity frequency", "default": 0.5, "value": 1.5})
	var user := ConfigRec.new()
	user.read(cfg)
	ck(absf(user.freq_mult - 1.5) < 0.0001, "user value 1.5 is preserved")

	# removed Rarity palette: a stale config key must no longer change colours
	var stale := ConfigFile.new()
	stale.set_value("Dropdown", "tier_palette", {"value": 1})
	var rec := ConfigRec.new()
	rec.read(stale)
	var disp := Display.new()
	disp.configure(rec)
	ck(disp._border_color(1) == Color(0.35, 0.6, 1.0), "tier 1 is default blue")
	ck(disp._border_color(2) == Color(0.7, 0.4, 1.0), "tier 2 is default purple")
	ck(disp._border_color(3) == Color(1.0, 0.8, 0.2), "tier 3 is default gold")

	# --- node_added батчится: track только кладёт узел в очередь ---
	var d := Display.new()
	var cell := PaintedCell.new()
	var qslot := FakeSlot.new()
	qslot.loot_tier = 1
	cell.slotData = qslot
	d.track(cell)
	var pending: Array = d.get("_pending")
	ck(pending.size() == 1, "track enqueues a node instead of walking it")
	ck(cell.get_node_or_null("_rtl_border") == null, "track does not paint synchronously")

	# ready надо подписывать на node_added, пока сигнал ещё не прошёл
	var bare := Panel.new()
	d.track(bare)
	ck(bare.get_signal_connection_list("ready").size() == 1,
		"ready is subscribed at node_added time, not at drain")
	d.call("_drain_pending")
	ck(cell.get_node_or_null("_rtl_border") != null, "drain paints queued cells")
	pending = d.get("_pending")
	ck(pending.is_empty(), "drain clears the queue")
	d.call("_drain_pending")
	ck(true, "drain on an empty queue is safe")
	cell.free()
	bare.free()

	# --- повторная покраска не пересоздаёт стиль, смена tier обновляет его ---
	var slot := FakeSlot.new()
	slot.loot_tier = 2
	var painted := PaintedCell.new()
	painted.slotData = slot
	var paint_disp := Display.new()
	paint_disp.paint(painted)
	var overlay := painted.get_node_or_null("_rtl_border")
	ck(overlay != null, "border created")
	var style_id: int = int(overlay.get_theme_stylebox("panel").get_instance_id())
	paint_disp.paint(painted)
	ck(painted.get_child_count() == 1, "repaint does not add another border")
	ck(int(overlay.get_theme_stylebox("panel").get_instance_id()) == style_id,
		"repaint keeps the same StyleBoxFlat instance")
	slot.loot_tier = 3
	paint_disp.paint(painted)
	ck(int(overlay.get_meta("rtl_border_tier", -1)) == 3, "tier change updates the border")
	painted.free()

	# --- debug: голый bool в любой секции включает debug ---
	var d1 := ConfigFile.new()
	d1.set_value("Bool", "debug_enabled", true)
	ck(Boot.debug_flag_wanted(d1), "plain debug_enabled=true enables debug")
	var d2 := ConfigFile.new()
	d2.set_value("Debug", "debug_enabled", false)
	ck(not Boot.debug_flag_wanted(d2), "plain false does not enable debug")
	var d3 := ConfigFile.new()
	d3.set_value("Bool", "debug_enabled", {"value": true})
	ck(Boot.debug_flag_wanted(d3), "MCM dictionary form still enables debug")
	ck(not Boot.debug_flag_wanted(ConfigFile.new()), "no key: debug stays off")

	# --- merge: голое значение переживает перезапись config.ini ---
	var declared := ConfigFile.new()
	declared.set_value("Bool", "debug_enabled", {"name": "Debug mode", "default": false, "value": false})
	declared.set_value("Float", "freq_mult", {"name": "Rarity frequency", "default": 0.5, "value": 0.5})
	var existing := ConfigFile.new()
	existing.set_value("Bool", "debug_enabled", true)
	existing.set_value("Float", "freq_mult", 1.5)
	Boot.merge_user_values(declared, existing)
	ck(bool(declared.get_value("Bool", "debug_enabled")["value"]),
		"plain bool carried into the dictionary form")
	ck(absf(float(declared.get_value("Float", "freq_mult")["value"]) - 1.5) < 0.0001,
		"plain float carried into the dictionary form")

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
