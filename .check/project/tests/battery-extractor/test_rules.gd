extends SceneTree

const Rules = preload("res://mods/BatteryExtractor/BatteryRules.gd")
const Mod = preload("res://mods/BatteryExtractor/BatteryExtractor.gd")

var fails := 0


class FakeItem extends Resource:
	var file: String = ""
	var name: String = ""
	var display: String = ""
	var showCondition: bool = false
	var stackable: bool = true
	var maxAmount: int = 1
	var condition = 100

	func _init(f: String = "Batteries", n: String = "Batteries") -> void:
		file = f
		name = n


func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)


func _init() -> void:
	t_is_target()
	t_can_extract()
	t_charge_for()
	t_mark_partial_contract()
	t_plain_battery_unmarked()
	t_partial_gets_stored_charge()
	t_mod_contract()
	print("")
	if fails == 0:
		print("BatteryExtractor tests passed")
		quit(0)
	else:
		print("BatteryExtractor tests failed: ", fails)
		quit(1)


func t_is_target() -> void:
	ck(Rules.is_target("Polaris"), "Polaris is a target")
	ck(Rules.is_target("Narva"), "Narva is a target")
	ck(Rules.is_target("Phoenix"), "Phoenix is a target")
	ck(Rules.is_target("PV7"), "PV7 is a target")
	ck(Rules.is_target("Casette_Player"), "Casette_Player is a target")
	ck(not Rules.is_target("VIRVE"), "VIRVE is not a target")
	ck(not Rules.is_target("Alarm_Clock"), "Alarm_Clock is not a target")
	ck(not Rules.is_target("Battery"), "car Battery is not a target")
	ck(not Rules.is_target("Batteries"), "Batteries itself is not a target")
	ck(not Rules.is_target(""), "empty file is not a target")


func t_can_extract() -> void:
	ck(not Rules.can_extract(0), "zero charge cannot be extracted")
	ck(not Rules.can_extract(-1), "negative charge cannot be extracted")
	ck(not Rules.can_extract(null), "null charge cannot be extracted")
	ck(not Rules.can_extract("n/a"), "non-numeric charge cannot be extracted")
	ck(Rules.can_extract(0.1), "small positive charge can be extracted")
	ck(Rules.can_extract(37.5), "fractional charge can be extracted")
	ck(Rules.can_extract(100), "full charge can be extracted")


func t_charge_for() -> void:
	ck(is_equal_approx(Rules.charge_for(37.5), 37.5), "fractional charge kept")
	ck(is_equal_approx(Rules.charge_for(0), 0.0), "zero charge kept")
	ck(is_equal_approx(Rules.charge_for(-5), 0.0), "negative charge clamped to zero")
	ck(is_equal_approx(Rules.charge_for(150), 100.0), "overcharge clamped to 100")
	ck(is_equal_approx(Rules.charge_for("n/a"), 0.0), "non-numeric charge is zero")


func t_mark_partial_contract() -> void:
	var item := FakeItem.new()
	ck(Rules.mark_partial(item), "mark_partial accepts an item")
	ck(Rules.is_partial(item), "marked item is partial")
	ck(item.display == "Battery (partial)", "display names the partial battery")
	ck(item.showCondition, "condition is shown on the item")
	ck(item.file == "Batteries", "file stays Batteries for CombineCheck")
	ck(item.name == "Batteries", "name stays Batteries for CombineCheck")
	ck(not item.stackable, "partial battery does not merge")
	ck(item.maxAmount == 0, "partial battery has no stack size")


func t_plain_battery_unmarked() -> void:
	var item := FakeItem.new()
	ck(not Rules.is_partial(item), "ordinary battery has no partial marker")
	ck(not Rules.is_partial(null), "null is not partial")
	ck(not Rules.is_partial("Batteries"), "plain string is not partial")


func t_partial_gets_stored_charge() -> void:
	var item := FakeItem.new()
	Rules.mark_partial(item)
	item.condition = 37.5
	ck(is_equal_approx(Rules.charge_for(item.condition), 37.5), "partial battery keeps 37.5 charge")
	item.condition = 100
	ck(is_equal_approx(Rules.charge_for(item.condition), 100.0), "full partial battery keeps 100 charge")
	ck(not Rules.is_partial(FakeItem.new()), "plain battery has no stored charge marker")


func t_mod_contract() -> void:
	var m = Mod.new()
	var script = m.get_script()
	var consts: Dictionary = script.get_script_constant_map()
	ck(consts.has(&"RULES"), "autoload declares RULES")
	ck(consts.has(&"BATTERIES_PATH"), "autoload declares BATTERIES_PATH")
	ck(consts.has(&"CONTEXT_HOOK"), "autoload declares CONTEXT_HOOK")
	ck(consts.has(&"RELEASE_PRE_HOOK"), "autoload declares RELEASE_PRE_HOOK")
	ck(consts.has(&"RELEASE_POST_HOOK"), "autoload declares RELEASE_POST_HOOK")
	ck(m.has_method("_on_context_update"), "autoload has context hook")
	ck(m.has_method("_on_extract_pressed"), "autoload has extraction action")
	ck(m.has_method("_on_release_pre"), "autoload has release pre-hook")
	ck(m.has_method("_on_release_post"), "autoload has release post-hook")
	ck(m.has_method("_apply_partial_charge"), "autoload has partial-charge applier")
	m.free()
