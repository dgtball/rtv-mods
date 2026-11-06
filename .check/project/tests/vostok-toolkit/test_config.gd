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
	t_defaults_cover_every_field()
	t_cycle_days_is_clamped()
	t_key_default_is_f3()
	t_player_name_round_trip()
	t_player_name_invalid_values()
	t_player_name_is_cleaned()
	t_zero_key_falls_back_to_default()
	print("")
	if fails == 0:
		print("Config tests passed")
		quit(0)
	else:
		print("Config tests failed: ", fails)
		quit(1)

func t_empty_cfg_keeps_defaults() -> void:
	# Пустой ConfigFile - свежая установка без config.ini. Дефолты берём из
	# DEFAULTS, а не переписываем руками: литерал жил в трёх местах.
	var c: ConfigRec = ConfigRec.new()
	c.read(ConfigFile.new())
	for key in ConfigRec.DEFAULTS:
		if key == "language":
			continue
		ck(c.get(key) == ConfigRec.DEFAULTS[key],
			"%s default берётся из DEFAULTS" % key)
	ck(c.language == Loc.get_lang(), "language default = текущий язык (свежий = en)")
	ck(ConfigRec.DEFAULTS["language"] == Loc.DEFAULT, "DEFAULTS.language = Loc.DEFAULT")

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
	ck(c.key_ui_toggle == ConfigRec.DEFAULTS["key_ui_toggle"], "key_ui_toggle недоступен - дефолт из DEFAULTS")

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
	# Все 12 ключей разом - как их пишет MCM в config.ini.
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
	cfg.set_value("String", "player_name", {"value": "Vasya"})
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
	ck(c.player_name == "Vasya", "round trip player_name")

func t_float_int_coercion() -> void:
	# Int-секция может приехать как число с плавающей точкой - кастуем,
	# а не оставляем как есть. (Float-полей в 5.2.0 не осталось.)
	var cfg := ConfigFile.new()
	cfg.set_value("Int", "season_cycle_days", {"value": 2.0})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.season_cycle_days == 2, "Int-значение приводится к int")

func t_defaults_cover_every_field() -> void:
	# Словарь и объявления полей не могут разъехаться: иначе регистрация MCM
	# получит другой дефолт, чем свежая установка. Список полей не переписываем -
	# читаем его у самого объекта.
	var c: ConfigRec = ConfigRec.new()
	var fields := {}
	for p in c.get_property_list():
		if not (int(p.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		fields[str(p.get("name"))] = true
	ck(fields.size() == ConfigRec.DEFAULTS.size(), "полей и ключей DEFAULTS поровну")
	for key in ConfigRec.DEFAULTS:
		ck(fields.has(key), "DEFAULTS-ключ %s объявлен полем" % key)
	for key in fields:
		ck(ConfigRec.DEFAULTS.has(key), "поле %s есть в DEFAULTS" % key)

func t_key_default_is_f3() -> void:
	# Дефолт хоткея - F3: старый ноль оставлял окно без клавиши, а README
	# обещал F3. Сверка с глобальной константой, а не с числом.
	ck(ConfigRec.DEFAULTS["key_ui_toggle"] == KEY_F3, "DEFAULTS.key_ui_toggle = KEY_F3")
	var c: ConfigRec = ConfigRec.new()
	c.read(ConfigFile.new())
	ck(c.key_ui_toggle == KEY_F3, "свежий конфиг читает ключ как KEY_F3")

func t_zero_key_falls_back_to_default() -> void:
	# У игрока со старой установкой в config.ini лежит value = 0 («клавиши
	# нет», выбор ничего): MCM-merge сохранит его как пользовательское
	# значение, а ноль осмысленной клавишей быть не может - трактуем как
	# «не выбрано» и подставляем дефолт.
	var cfg := ConfigFile.new()
	cfg.set_value("Keycode", "key_ui_toggle", {"value": 0})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.key_ui_toggle == KEY_F3, "ноль в конфиге поднимается до дефолта")
	cfg.set_value("Keycode", "key_ui_toggle", {"value": KEY_F4})
	c.read(cfg)
	ck(c.key_ui_toggle == KEY_F4, "осознанное значение клавиши проходит как есть")

func t_cycle_days_is_clamped() -> void:
	# Нижняя граница была, верхней не было: 100000 из ручной правки конфига
	# уводил сезон в бесконечность одного сезона.
	var cfg := ConfigFile.new()
	cfg.set_value("Int", "season_cycle_days", {"value": 100000})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.season_cycle_days == ConfigRec.SEASON_MAX_DAYS, "верхняя граница дней сезона")
	cfg.set_value("Int", "season_cycle_days", {"value": 0})
	c.read(cfg)
	ck(c.season_cycle_days == ConfigRec.SEASON_MIN_DAYS, "нижняя граница дней сезона")

func t_player_name_round_trip() -> void:
	# MCM пишет словарь, ручная правка config.ini - голую строку; обе формы живут.
	var cfg := ConfigFile.new()
	cfg.set_value("String", "player_name", {"value": "Vasya"})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.player_name == "Vasya", "player_name из словаря MCM")
	cfg.set_value("String", "player_name", "Kolya")
	c.read(cfg)
	ck(c.player_name == "Kolya", "player_name из голой строки")

func t_player_name_invalid_values() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("String", "player_name", {"value": 42})
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	ck(c.player_name == "Player", "нестроковое value -> Player")
	cfg.set_value("String", "player_name", 7)
	c.read(cfg)
	ck(c.player_name == "Player", "нестроковый примитив -> Player")

func t_player_name_is_cleaned() -> void:
	ck(ConfigRec.clean_player_name("  Vasya  ") == "Vasya", "пробелы по краям срезаны")
	ck(ConfigRec.clean_player_name("ABCDEFGHIJKLMNOPQRST") == "ABCDEFGHIJKLMNO", "20 символов -> 15")
	ck(ConfigRec.clean_player_name("ABCDEFGHIJKLMN x") == "ABCDEFGHIJKLMN", "пробел на 15-й позиции срезается")
	ck(ConfigRec.clean_player_name("Вася") == "Player", "кириллица выкинута -> Player")
	ck(ConfigRec.clean_player_name("   ") == "Player", "пробелы -> Player")
	ck(ConfigRec.clean_player_name("") == "Player", "пусто -> Player")
	ck(ConfigRec.clean_player_name('A "B" \\ C') == 'A "B" \\ C', "кавычки и слэш остаются текстом")
