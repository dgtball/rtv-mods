extends SceneTree

const ConfigRec = preload("res://mods/RoadToLoot/RTLConfig.gd")

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

	print("")
	if fails > 0:
		print("FAILED: %d" % fails)
		quit(1)
	else:
		print("tests passed")
		quit(0)
