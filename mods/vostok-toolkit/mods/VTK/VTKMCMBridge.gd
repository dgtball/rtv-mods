extends RefCounted
# Мост между MCM и модом: регистрация настроек, свёртка config.ini (секции и
# ключи свежие, Info перезаписывается, пользовательские value живут) и разбор
# конфига в типизированный VTKConfig. Узлы и тумблеры остаются в
# VTKFeatureHost - мост их только дёргает, а UI остаётся в VTKUI.

const Loc = preload("res://mods/VTK/VTKLoc.gd")
const Log = preload("res://mods/VTK/VTKLog.gd")
const ConfigRec := preload("res://mods/VTK/VTKConfig.gd")

var features: RefCounted = null
var rebuild_ui: Callable = Callable()
var set_key_ui_toggle: Callable = Callable()
var _live_cfg: ConfigFile = null

func register(host: RefCounted, on_rebuild: Callable, on_key: Callable) -> void:
	features = host
	rebuild_ui = on_rebuild
	set_key_ui_toggle = on_key
	if not ResourceLoader.exists("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"):
		# Без MCM apply() раньше не звался вовсе: хоткей и тумблеры оставались
		# на нулях хоста, окно было нечем открыть. Полный путь применит
		# дефолты из конфига-заглушки (или из завалявшегося config.ini).
		apply(ConfigFile.new())
		return
	var MCM = load("res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres")
	if MCM == null or not MCM.has_method("RegisterConfiguration"):
		return
	var cfg = ConfigFile.new()
	var CAT := "01. General"
	cfg.set_value("Keycode", "key_ui_toggle", {"name": "Hotkey: Toggle UI", "default": ConfigRec.DEFAULTS["key_ui_toggle"], "default_type": "Keycode", "value": ConfigRec.DEFAULTS["key_ui_toggle"], "category": CAT, "menu_pos": 0, "tooltip": "Press once to open/close the Loadouts UI."})
	cfg.set_value("Dropdown", "language", {"name": "Language", "default": ConfigRec.DEFAULTS["language"], "value": Loc.get_lang(), "options": {"en": "English", "ru": "Русский"}, "category": CAT, "menu_pos": 1, "tooltip": "Interface language of the Loadouts window. English is the source language."})
	cfg.set_value("Bool", "auto_equip", {"name": "Auto-equip on pickup", "default": ConfigRec.DEFAULTS["auto_equip"], "value": ConfigRec.DEFAULTS["auto_equip"], "category": CAT, "menu_pos": 2, "tooltip": "When a picked-up item fits an empty equipment slot it is equipped right away. Stackables top up an already equipped stack; loading a save or starting a new game is left untouched."})
	var TR := "03. Travel"
	cfg.set_value("Bool", "tp_unlocked_shelters_only", {"name": "Unlocked shelters only", "default": ConfigRec.DEFAULTS["tp_unlocked_shelters_only"], "value": ConfigRec.DEFAULTS["tp_unlocked_shelters_only"], "category": TR, "menu_pos": 0, "tooltip": "When enabled, teleporting to a locked shelter is refused."})
	var KF := "04. KillFeed"
	cfg.set_value("Bool", "kill_counter_enabled", {"name": "Kill counter", "default": ConfigRec.DEFAULTS["kill_counter_enabled"], "value": ConfigRec.DEFAULTS["kill_counter_enabled"], "category": KF, "menu_pos": 0, "tooltip": "Show the kill counter HUD line (Killed / Enemies / Nomads)."})
	cfg.set_value("Bool", "kill_feed_enabled", {"name": "Kill feed", "default": ConfigRec.DEFAULTS["kill_feed_enabled"], "value": ConfigRec.DEFAULTS["kill_feed_enabled"], "category": KF, "menu_pos": 1, "tooltip": "Show the kill feed under the counter: killer, weapon/headshot icons, victim."})
	cfg.set_value("String", "player_name", {"name": "Player name", "default": ConfigRec.DEFAULTS["player_name"], "value": ConfigRec.DEFAULTS["player_name"], "category": KF, "menu_pos": 2, "tooltip": "Name shown for you in the kill feed. Up to 15 English letters, digits, symbols or spaces."})
	cfg.set_value("Bool", "kill_streak_enabled", {"name": "Show kill achievements", "default": ConfigRec.DEFAULTS["kill_streak_enabled"], "value": ConfigRec.DEFAULTS["kill_streak_enabled"], "category": KF, "menu_pos": 3, "tooltip": "Show the kill streak counter plus New longest kill / Long shot toasts."})
	cfg.set_value("Dropdown", "hud_anchor", {"name": "HUD position", "default": ConfigRec.DEFAULTS["hud_anchor"], "value": ConfigRec.DEFAULTS["hud_anchor"], "options": {"top_left": "Top left", "top_center": "Top center", "top_right": "Top right", "bottom_left": "Bottom left", "bottom_center": "Bottom center", "bottom_right": "Bottom right"}, "category": KF, "on_value_changed": "on_setting_changed", "menu_pos": 4, "tooltip": "Corner/center anchor for the kill feed block."})
	cfg.set_value("Int", "hud_offset_x", {"name": "HUD offset X", "default": ConfigRec.DEFAULTS["hud_offset_x"], "value": ConfigRec.DEFAULTS["hud_offset_x"], "on_value_changed": "on_setting_changed", "minRange": -1000, "maxRange": 1000, "step": 1, "category": KF, "menu_pos": 5, "tooltip": "Horizontal distance/shift of the kill feed block from its anchor."})
	cfg.set_value("Int", "hud_offset_y", {"name": "HUD offset Y", "default": ConfigRec.DEFAULTS["hud_offset_y"], "value": ConfigRec.DEFAULTS["hud_offset_y"], "on_value_changed": "on_setting_changed", "minRange": -1000, "maxRange": 1000, "step": 1, "category": KF, "menu_pos": 6, "tooltip": "Vertical distance/shift of the kill feed block from its anchor."})
	cfg.set_value("Int", "hud_font_size", {"name": "HUD font size", "default": ConfigRec.DEFAULTS["hud_font_size"], "value": ConfigRec.DEFAULTS["hud_font_size"], "on_value_changed": "on_setting_changed", "minRange": 12, "maxRange": 32, "step": 1, "category": KF, "menu_pos": 7, "tooltip": "One font size for the counter, streak and feed."})
	cfg.set_value("Bool", "show_kill_distance", {"name": "Show kill distance", "default": ConfigRec.DEFAULTS["show_kill_distance"], "value": ConfigRec.DEFAULTS["show_kill_distance"], "category": KF, "menu_pos": 8, "tooltip": "Show shot distance in meters on feed rows."})
	cfg.set_value("Int", "longshot_distance_meters", {"name": "Long-shot distance", "default": ConfigRec.DEFAULTS["longshot_distance_meters"], "value": ConfigRec.DEFAULTS["longshot_distance_meters"], "on_value_changed": "on_setting_changed", "minRange": 75, "maxRange": 150, "step": 5, "category": KF, "menu_pos": 9, "tooltip": "Minimum distance in meters for a Long shot callout."})
	var SN := "05. Seasons"
	cfg.set_value("Bool", "season_enabled", {"name": "Dynamic seasons", "default": ConfigRec.DEFAULTS["season_enabled"], "value": ConfigRec.DEFAULTS["season_enabled"], "on_value_changed": "on_setting_changed", "category": SN, "menu_pos": 0, "tooltip": "Cycle spring, summer, autumn and winter by day during a run started with the Dynamic season in the New Game menu. Winter brings the real snow and cold; the other seasons recolour trees, grass and light so they look distinct."})
	cfg.set_value("Dropdown", "season_start", {"name": "Starting season", "default": ConfigRec.DEFAULTS["season_start"], "value": ConfigRec.DEFAULTS["season_start"], "on_value_changed": "on_setting_changed", "options": {"random": "Random", "spring": "Spring", "summer": "Summer", "autumn": "Autumn", "winter": "Winter"}, "category": SN, "menu_pos": 1, "tooltip": "Which season a fresh Dynamic run begins with. Random picks one for each new run."})
	cfg.set_value("Int", "season_cycle_days", {"name": "Days per season", "default": ConfigRec.DEFAULTS["season_cycle_days"], "value": ConfigRec.DEFAULTS["season_cycle_days"], "on_value_changed": "on_setting_changed", "minRange": ConfigRec.SEASON_MIN_DAYS, "maxRange": ConfigRec.SEASON_MAX_DAYS, "step": 1, "category": SN, "menu_pos": 2, "tooltip": "How many in-game days each season lasts before the next one begins. 30 = one season per month; lower means faster cycling."})
	cfg.set_value("Bool", "season_visuals", {"name": "Seasonal colours", "default": ConfigRec.DEFAULTS["season_visuals"], "value": ConfigRec.DEFAULTS["season_visuals"], "on_value_changed": "on_setting_changed", "category": SN, "menu_pos": 3, "tooltip": "Recolour trees, grass and lighting for spring, summer and autumn. Turn off to keep vanilla colours while the season still changes."})
	var DBG := "06. Debug"
	cfg.set_value("Bool", "debug_log", {"name": "Mod debug log", "default": ConfigRec.DEFAULTS["debug_log"], "value": ConfigRec.DEFAULTS["debug_log"], "category": DBG, "menu_pos": 0, "tooltip": "Print mod diagnostics (item resolution, hooks, teleports, saves) to the game log. Off during normal play; turn on only to troubleshoot."})
	cfg.set_value("Info", "version", version())
	cfg.set_value("Info", "author", "opencode")
	var path = "user://MCM/vostok-toolkit"
	DirAccess.make_dir_recursive_absolute(path)
	var cfile = path + "/config.ini"
	if FileAccess.file_exists(cfile):
		var existing = ConfigFile.new()
		existing.load(cfile)
		var stale_sections := []
		for s in existing.get_sections():
			if s != "Info" and not cfg.has_section(s):
				stale_sections.append(s)
		for s in stale_sections:
			existing.erase_section(s)
		for s in cfg.get_sections():
			var stale_keys: Array = []
			if existing.has_section(s):
				for k in existing.get_section_keys(s):
					if not cfg.has_section_key(s, k):
						stale_keys.append(k)
			for k in stale_keys:
				existing.erase_section_key(s, k)
		for s in cfg.get_sections():
			for k in cfg.get_section_keys(s):
				if s == "Info":
					existing.set_value(s, k, cfg.get_value(s, k, {}))
					continue
				# На первом запуске после обновления мода новые ключи (которых
				# ещё нет в старом config.ini) попадают в existing только через
				# слияние. Но apply() не пишет файл - сохранение происходит по
				# кнопке "Save" в MCM. Чтобы новый ключ появился в файле без
				# нажатия Save, добавляем все отсутствующие ключи ДО слияния
				# ( preserves user values for existing keys).
				if not existing.has_section_key(s, k):
					existing.set_value(s, k, cfg.get_value(s, k, {}))
				var old_v = existing.get_value(s, k, {})
				var new_v = cfg.get_value(s, k, {})
				if typeof(old_v) == TYPE_DICTIONARY and typeof(new_v) == TYPE_DICTIONARY:
					var merged = new_v.duplicate()
					merged["value"] = old_v.get("value", new_v.get("value"))
					existing.set_value(s, k, merged)
		existing.save(cfile)
	# Normalize cfg to the full schema and preserve any old user values before writing.
	if FileAccess.file_exists(cfile):
		var _existing = ConfigFile.new()
		if _existing.load(cfile) == OK:
			for _s in _existing.get_sections():
				if _s == "Info":
					continue
				for _k in _existing.get_section_keys(_s):
					var _d = cfg.get_value(_s, _k, {})
					var _u = _existing.get_value(_s, _k, {})
					if typeof(_d) == TYPE_DICTIONARY and typeof(_u) == TYPE_DICTIONARY and _u.has("value"):
						_d["value"] = _u["value"]
						cfg.set_value(_s, _k, _d)
	cfg.save(cfile)
	if not FileAccess.file_exists(cfile):
		cfg.save(cfile)
	# Update every profile-specific ini in the mod folder to the full schema,
	# preserving user values, so MCM profiles cannot keep an old key set.
	var _dir = DirAccess.open(path)
	if _dir == null:
		DirAccess.make_dir_recursive_absolute(path)
		_dir = DirAccess.open(path)
	if _dir:
		_dir.list_dir_begin()
		var _paths: Array = []
		var _f = _dir.get_next()
		while _f != "":
			if (not _dir.current_is_dir()) and _f.ends_with(".ini"):
				_paths.append(_f)
			_f = _dir.get_next()
		_dir.list_dir_end()
		for _p in _paths:
			var _pf = path + "/" + _p
			var _existing = ConfigFile.new()
			if _existing.load(_pf) != OK:
				continue
			for _s in cfg.get_sections():
				for _k in cfg.get_section_keys(_s):
					var _nd = cfg.get_value(_s, _k, {})
					if _existing.has_section_key(_s, _k):
						var _ud = _existing.get_value(_s, _k, {})
						if typeof(_nd) == TYPE_DICTIONARY and typeof(_ud) == TYPE_DICTIONARY:
							var _m2 = _nd.duplicate()
							if _ud.has("value"):
								_m2["value"] = _ud["value"]
							_existing.set_value(_s, _k, _m2)
					else:
						_existing.set_value(_s, _k, _nd)
			for _s in _existing.get_sections():
				var _stale: Array = []
				for _k in _existing.get_section_keys(_s):
					if not cfg.has_section_key(_s, _k):
						_stale.append(_k)
				for _k in _stale:
					_existing.erase_section_key(_s, _k)
			_existing.save(_pf)

	MCM.RegisterConfiguration("vostok-toolkit", "Vostok Toolkit", path, "Loadouts, ESP and teleport", Callable(self, "apply"), self)
	apply(ConfigFile.new())

func version() -> String:
	# Единственный источник версии - version.txt, который пишет pack.ps1.
	# res://mod.txt не читаем: он общий для всех модов и в заголовке может
	# оказаться чужая версия.
	var vf = FileAccess.open("res://mods/VTK/version.txt", FileAccess.READ)
	if vf == null:
		return "unknown"
	var v := vf.get_as_text().strip_edges()
	vf.close()
	return v if v != "" else "unknown"

func load_lang() -> void:
	Loc.set_lang(Loc.DEFAULT)
	var cf := ConfigFile.new()
	if cf.load("user://MCM/vostok-toolkit/config.ini") != OK:
		return
	var d = cf.get_value("Dropdown", "language", {})
	if typeof(d) == TYPE_DICTIONARY:
		Loc.set_lang(str(d.get("value", Loc.DEFAULT)))

func apply(cfg: ConfigFile) -> void:
	var cpath = "user://MCM/vostok-toolkit/config.ini"
	if cfg.get_sections().is_empty() and FileAccess.file_exists(cpath):
		cfg.load(cpath)
	_live_cfg = cfg
	var c: ConfigRec = ConfigRec.new()
	c.read(cfg)
	var want: String = c.language
	if want != Loc.get_lang():
		Loc.set_lang(want)
		if Loc.get_lang() == want and rebuild_ui.is_valid():
			rebuild_ui.call()
	if set_key_ui_toggle.is_valid():
		set_key_ui_toggle.call(c.key_ui_toggle)
	Log.enabled = c.debug_log
	if features != null:
		features.apply_config(c)


func on_setting_changed(valueId: String, newValue, menu) -> void:
	var cpath := "user://MCM/vostok-toolkit/config.ini"
	# Live preview in MCM: changing a HUD setting moves the block right away.
	# Persistence still only happens on Save Config.
	if _live_cfg == null:
		_live_cfg = ConfigFile.new()
		_live_cfg.load(cpath)
	var found := false
	for s in _live_cfg.get_sections():
		if _live_cfg.has_section_key(s, valueId):
			var d = _live_cfg.get_value(s, valueId, {})
			if typeof(d) == TYPE_DICTIONARY:
				d["value"] = newValue
				_live_cfg.set_value(s, valueId, d)
			else:
				_live_cfg.set_value(s, valueId, newValue)
			found = true
			break
	if not found:
		# В свежем конфиге ключ может отсутствовать - ничего не применяем.
		return
	apply(_live_cfg)
