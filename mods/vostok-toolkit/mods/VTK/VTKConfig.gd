extends RefCounted
# Типизированный срез MCM-конфига: 11 ключей. Дефолты живут в DEFAULTS, и его
# читают объявления полей, регистрация VTKMCMBridge и тест. Разбор - read(), он
# держит прежнюю семантику _mcm_key_val: приоритет d["value"] внутри словаря,
# иначе примитив, иначе дефолт.

const Loc = preload("res://mods/VTK/VTKLoc.gd")

# Единственный источник дефолтов: объявления полей, регистрация MCM и тест
# читают этот словарь. "language" берётся из Loc.DEFAULT: константа чужого
# скрипта внутри const-словаря компилируется в 4.6.3 (проверено на стенде:
# опечатка в имени члена там падает Parse Error, то есть проверка настоящая),
# а литерал "en" второй раз не нужен.
const DEFAULTS := {
	"key_ui_toggle": 0,
	"language": Loc.DEFAULT,
	"auto_equip": true,
	"debug_log": false,
	"tp_unlocked_shelters_only": false,
	"kill_counter_enabled": true,
	"kill_feed_enabled": true,
	"season_enabled": true,
	"season_start": "summer",
	"season_cycle_days": 30,
	"season_visuals": true,
}

# Те же числа, что в minRange/maxRange регистрации MCM. Кламп здесь, а не только
# в UI: config.ini правится руками, а MCM можно обойти.
const SEASON_MIN_DAYS := 1
const SEASON_MAX_DAYS := 120

var key_ui_toggle: int = DEFAULTS["key_ui_toggle"]
var language: String = DEFAULTS["language"]
var auto_equip: bool = DEFAULTS["auto_equip"]
var debug_log: bool = DEFAULTS["debug_log"]
var tp_unlocked_shelters_only: bool = DEFAULTS["tp_unlocked_shelters_only"]
var kill_counter_enabled: bool = DEFAULTS["kill_counter_enabled"]
var kill_feed_enabled: bool = DEFAULTS["kill_feed_enabled"]
var season_enabled: bool = DEFAULTS["season_enabled"]
var season_start: String = DEFAULTS["season_start"]
var season_cycle_days: int = DEFAULTS["season_cycle_days"]
var season_visuals: bool = DEFAULTS["season_visuals"]


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
	season_cycle_days = clampi(int(_val(cfg, "Int", "season_cycle_days", season_cycle_days)), SEASON_MIN_DAYS, SEASON_MAX_DAYS)
	season_visuals = bool(_val(cfg, "Bool", "season_visuals", season_visuals))


static func _val(cfg: ConfigFile, section: String, key: String, fallback: Variant) -> Variant:
	if not cfg.has_section_key(section, key):
		return fallback
	var d = cfg.get_value(section, key, {})
	if typeof(d) == TYPE_DICTIONARY and d.has("value"):
		return d["value"]
	return d if typeof(d) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else fallback
