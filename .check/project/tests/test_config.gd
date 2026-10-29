extends SceneTree

const ConfigRec = preload("res://mods/VTK/VTKConfig.gd")
const Loc = preload("res://mods/VTK/VTKLoc.gd")

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
	t_empty_cfg_keeps_defaults()
	t_dict_value_wins()
	t_missing_key_uses_default()
	t_primitive_and_plain_string_fall_back()
	t_full_round_trip()
	t_float_int_coercion()
	print("")
	if fails == 0:
		print("Config tests passed")
		quit(0)
	else:
		print("Config tests failed: ", fails)
		quit(1)

func t_empty_cfg_keeps_defaults() -> void:
	# Пустой ConfigFile - свежая установка без config.ini. Дефолты обязаны
	# совпасть с регистрационными записями VTKMCMBridge.
	var c: ConfigRec = ConfigRec.new()
	c.read(ConfigFile.new())
	ck(c.key_ui_toggle == 0, "key_ui_toggle default 0")
	ck(c.language == Loc.get_lang(), "language default = текущий язык (свежий = en)")
	ck(c.auto_equip == true, "auto_equip default true")
	ck(c.debug_log == false, "debug_log default false")
	ck(c.tp_unlocked_shelters_only == false, "tp_unlocked_shelters_only default false")
	ck(c.kill_counter_enabled == true, "kill_counter_enabled default true")
	ck(c.kill_feed_enabled == true, "kill_feed_enabled default true")
	ck(c.season_enabled == true, "season_enabled default true")
	ck(c.season_start == "summer", "season_start default summer")
	ck(c.season_cycle_days == 30, "season_cycle_days default 30")
	ck(c.season_visuals == true, "season_visuals default true")

func t_dict_value_wins() -> void:
	# Типовой случай: MCM кладёт словарь с name/tooltip и внутри value.
	var cfg := ConfigFile.new()
	cfg.set_value("Keycode", "key_ui_toggle", {"name": "Hotkey", "default": 0, "value": 4194332})
	cfg.set_value("Bool", "auto_equip", {"default": true, "value": false})
	cfg.set_value("Bool", "debug_log", {"default": false, "value": true})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.key_ui_toggle == 4194332, "keycode берёт d.value, а не default")
	ck(c.auto_equip == false, "auto_equip false из d.value")
	ck(c.debug_log == true, "debug_log true из d.value")

func t_missing_key_uses_default() -> void:
	# Частичный конфиг: недостающие ключи не должны обнуляться.
	var cfg := ConfigFile.new()
	cfg.set_value("Bool", "kill_feed_enabled", {"default": true, "value": false})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.kill_feed_enabled == false, "kill_feed_enabled из конфига")
	ck(c.kill_counter_enabled == true, "kill_counter_enabled недоступен - default true")
	ck(c.season_cycle_days == 30, "season_cycle_days недоступен - default 30")
	ck(c.key_ui_toggle == 0, "key_ui_toggle недоступен - default 0")

func t_primitive_and_plain_string_fall_back() -> void:
	# _mcm_key_val отбрасывает всё, кроме примитива и словаря с value:
	# строка-значение (например language, записанный напрямую) не должна
	# затирать текущий язык.
	var cfg := ConfigFile.new()
	cfg.set_value("Bool", "season_enabled", "true")
	cfg.set_value("Dropdown", "language", "ru")
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.season_enabled == true, "примитив-строка отброшен - default true")
	ck(c.language == Loc.get_lang(), "language-строка отброшена - текущий язык")

func t_full_round_trip() -> void:
	# Все 11 ключей разом - как их пишет MCM в config.ini.
	var cfg := ConfigFile.new()
	cfg.set_value("Keycode", "key_ui_toggle", {"value": 90})
	cfg.set_value("Dropdown", "language", {"value": "ru"})
	cfg.set_value("Bool", "auto_equip", {"value": false})
	cfg.set_value("Bool", "debug_log", {"value": true})
	cfg.set_value("Bool", "tp_unlocked_shelters_only", {"value": true})
	cfg.set_value("Bool", "kill_counter_enabled", {"value": false})
	cfg.set_value("Bool", "kill_feed_enabled", {"value": false})
	cfg.set_value("Bool", "season_enabled", {"value": false})
	cfg.set_value("Dropdown", "season_start", {"value": "winter"})
	cfg.set_value("Int", "season_cycle_days", {"value": 7})
	cfg.set_value("Bool", "season_visuals", {"value": false})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.key_ui_toggle == 90, "round trip key_ui_toggle")
	ck(c.language == "ru", "round trip language")
	ck(c.auto_equip == false, "round trip auto_equip")
	ck(c.debug_log == true, "round trip debug_log")
	ck(c.tp_unlocked_shelters_only == true, "round trip tp_unlocked_shelters_only")
	ck(c.kill_counter_enabled == false, "round trip kill_counter_enabled")
	ck(c.kill_feed_enabled == false, "round trip kill_feed_enabled")
	ck(c.season_enabled == false, "round trip season_enabled")
	ck(c.season_start == "winter", "round trip season_start")
	ck(c.season_cycle_days == 7, "round trip season_cycle_days")
	ck(c.season_visuals == false, "round trip season_visuals")

func t_float_int_coercion() -> void:
	# Int-секция может приехать как число с плавающей точкой - кастуем,
	# а не оставляем как есть. (Float-полей в 5.2.0 не осталось.)
	var cfg := ConfigFile.new()
	cfg.set_value("Int", "season_cycle_days", {"value": 2.0})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.season_cycle_days == 2, "Int-значение приводится к int")
