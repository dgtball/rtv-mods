extends RefCounted
# Типизированный срез MCM-конфига: 11 ключей. Дефолты полей - это же, что
# лежит в регистрационных записях VTKMCMBridge (там плюс name/tooltip/menu_pos,
# их в рекорд не тянем). Разбор - read(), он держит прежнюю семантику
# _mcm_key_val: приоритет d["value"] внутри словаря, иначе примитив, иначе
# дефолт.

const Loc = preload("res://mods/VTK/VTKLoc.gd")

var key_ui_toggle: int = 0
var language: String = Loc.DEFAULT
var auto_equip: bool = true
var debug_log: bool = false
var tp_unlocked_shelters_only: bool = false
var kill_counter_enabled: bool = true
var kill_feed_enabled: bool = true
var season_enabled: bool = true
var season_start: String = "summer"
var season_cycle_days: int = 30
var season_visuals: bool = true


func read(cfg: ConfigFile) -> void:
	key_ui_toggle = int(_val(cfg, "Keycode", "key_ui_toggle", key_ui_toggle))
	language = str(_val(cfg, "Dropdown", "language", Loc.get_lang()))
	auto_equip = bool(_val(cfg, "Bool", "auto_equip", auto_equip))
	debug_log = bool(_val(cfg, "Bool", "debug_log", debug_log))
	tp_unlocked_shelters_only = bool(_val(cfg, "Bool", "tp_unlocked_shelters_only", tp_unlocked_shelters_only))
	kill_counter_enabled = bool(_val(cfg, "Bool", "kill_counter_enabled", kill_counter_enabled))
	kill_feed_enabled = bool(_val(cfg, "Bool", "kill_feed_enabled", kill_feed_enabled))
	season_enabled = bool(_val(cfg, "Bool", "season_enabled", season_enabled))
	season_start = str(_val(cfg, "Dropdown", "season_start", season_start))
	season_cycle_days = maxi(1, int(_val(cfg, "Int", "season_cycle_days", season_cycle_days)))
	season_visuals = bool(_val(cfg, "Bool", "season_visuals", season_visuals))


static func _val(cfg: ConfigFile, section: String, key: String, fallback: Variant) -> Variant:
	if not cfg.has_section_key(section, key):
		return fallback
	var d = cfg.get_value(section, key, {})
	if typeof(d) == TYPE_DICTIONARY and d.has("value"):
		return d["value"]
	return d if typeof(d) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else fallback
