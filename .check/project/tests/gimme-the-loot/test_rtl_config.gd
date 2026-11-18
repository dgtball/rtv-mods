extends SceneTree

const ConfigRec = preload("res://mods/RoadToLoot/RTLConfig.gd")
const Boot = preload("res://mods/RoadToLoot/RTLBoot.gd")

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
