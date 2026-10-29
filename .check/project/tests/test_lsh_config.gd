extends SceneTree

const Config = preload("res://mods/LooterShooter/LSHConfig.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	var c = Config.new()
	ck(c.paint_cells == true, "paint_cells default true")
	ck(c.show_affix_block == true, "show_affix_block default true")
	ck(is_equal_approx(c.freq_mult, 1.0), "freq_mult default 1.0")
	ck(c.debug_enabled == false, "debug_enabled default false")
	ck(c.debug_force_tier == 0, "debug_force_tier default 0")

	var cfg := ConfigFile.new()
	cfg.set_value("Bool", "paint_cells", {"default": true, "value": false})
	cfg.set_value("Float", "freq_mult", {"default": 1.0, "value": 2.0})
	cfg.set_value("Dropdown", "tier_palette", {"value": 1})
	cfg.set_value("Int", "debug_force_tier", {"value": 3})
	cfg.set_value("Bool", "debug_enabled", {"default": false, "value": true})
	cfg.set_value("Keycode", "debug_reroll_key", {"value": 4194332})
	cfg.set_value("Bool", "log_rolls", {"default": false, "value": true})
	c.read(cfg)
	ck(c.paint_cells == false, "read bool value")
	ck(is_equal_approx(c.freq_mult, 2.0), "read float value")
	ck(c.tier_palette == 1, "read dropdown value")
	ck(c.debug_force_tier == 3, "read int value")
	ck(c.debug_enabled == true, "read debug toggle")
	ck(c.debug_reroll_key == 4194332, "read keycode")
	ck(c.log_rolls == true, "read log toggle")

	var partial := ConfigFile.new()
	c.read(partial)
	ck(c.freq_mult >= 0.5 and c.freq_mult <= 2.0, "missing keys keep valid freq_mult")

	print("")
	if fails == 0:
		print("LSH Config tests passed")
		quit(0)
	else:
		print("LSH Config tests failed: ", fails)
		quit(1)
