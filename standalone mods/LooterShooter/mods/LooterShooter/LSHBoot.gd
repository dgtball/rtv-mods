extends Node

const Log = preload("res://mods/LooterShooter/LSHLog.gd")
const ConfigRec = preload("res://mods/LooterShooter/LSHConfig.gd")
const DebugMod = preload("res://mods/LooterShooter/LSHDebug.gd")

const MCM_HELPERS := "res://ModConfigurationMenu/Scripts/Doink Oink/MCM_Helpers.tres"

var _lib = null
var _cfg = ConfigRec.new()
var _debug = DebugMod.new()

func _ready() -> void:
	register_mcm()
	_debug.configure(_cfg)
	Log.line("booted (debug=" + str(_cfg.debug_enabled) + ")")

func register_mcm() -> void:
	if not ResourceLoader.exists(MCM_HELPERS):
		_cfg.read(ConfigFile.new())
		return
	var mcm = load(MCM_HELPERS)
	if mcm == null or not mcm.has_method("RegisterConfiguration"):
		_cfg.read(ConfigFile.new())
		return
	var cfg := ConfigFile.new()
	var cat := "01. Display"
	cfg.set_value("Bool", "paint_cells", {"name": "Paint item cells", "default": true, "value": true, "category": cat, "menu_pos": 0, "tooltip": "Tint the inventory cell by loot rarity."})
	cfg.set_value("Bool", "show_affix_block", {"name": "Show affix block in tooltip", "default": true, "value": true, "category": cat, "menu_pos": 1, "tooltip": "List the rolled affixes below the item tooltip."})
	cfg.set_value("Float", "border_width", {"name": "Border width", "default": 2.0, "value": 2.0, "minRange": 1.0, "maxRange": 6.0, "step": 1.0, "category": cat, "menu_pos": 2, "tooltip": "Thickness of the rarity border."})
	cfg.set_value("Dropdown", "tier_palette", {"name": "Rarity palette", "default": 0, "value": 0, "options": {"0": "Default (blue/purple/gold)", "1": "High contrast"}, "category": cat, "menu_pos": 3, "tooltip": "Colour set for the rarity tiers."})
	cfg.set_value("Bool", "hide_vanilla_rarity", {"name": "Hide vanilla rarity line", "default": false, "value": false, "category": cat, "menu_pos": 4, "tooltip": "Hide the vanilla rarity word; the mod's own rarity line still shows."})

	var bal := "02. Balance"
	cfg.set_value("Float", "freq_mult", {"name": "Rarity frequency", "default": 1.0, "value": 1.0, "minRange": 0.5, "maxRange": 2.0, "step": 0.5, "category": bal, "menu_pos": 0, "tooltip": "Scales how often higher tiers appear."})
	cfg.set_value("Bool", "notify_legendary", {"name": "Notify on legendary find", "default": false, "value": false, "category": bal, "menu_pos": 1, "tooltip": "Show an on-screen message when a legendary drops."})
	cfg.set_value("Bool", "env_hint", {"name": "Container context hint", "default": true, "value": true, "category": bal, "menu_pos": 2, "tooltip": "Let military and elite containers shift the odds upward."})

	var dbg := "03. Debug"
	cfg.set_value("Bool", "debug_enabled", {"name": "Debug mode", "default": false, "value": false, "category": dbg, "menu_pos": 0, "tooltip": "Enable the debug tools below."})
	cfg.set_value("Int", "debug_force_tier", {"name": "Force tier (0=off)", "default": 0, "value": 0, "minRange": 0, "maxRange": 3, "step": 1, "category": dbg, "menu_pos": 1, "tooltip": "1=Common, 2=Rare, 3=Legendary."})
	cfg.set_value("Keycode", "debug_reroll_key", {"name": "Re-roll hovered item", "default": 0, "default_type": "Keycode", "value": 0, "category": dbg, "menu_pos": 2, "tooltip": "Press to re-roll the item under the cursor."})
	cfg.set_value("Bool", "log_rolls", {"name": "Log rolls", "default": false, "value": false, "category": dbg, "menu_pos": 3, "tooltip": "Print every loot roll to the log."})
	cfg.set_value("Info", "version", "0.1.0")

	var path := "user://MCM/lootershooter"
	DirAccess.make_dir_recursive_absolute(path)
	var cfile := path + "/config.ini"
	if FileAccess.file_exists(cfile):
		var existing := ConfigFile.new()
		if existing.load(cfile) == OK:
			for section in existing.get_sections():
				if not cfg.has_section(section):
					existing.erase_section(section)
					continue
				for key in existing.get_section_keys(section):
					if not cfg.has_section_key(section, key):
						existing.erase_section_key(section, key)
						continue
					var old_v = existing.get_value(section, key)
					var new_v = cfg.get_value(section, key)
					if old_v is Dictionary and new_v is Dictionary:
						new_v["value"] = old_v.get("value", new_v.get("value"))
						existing.set_value(section, key, new_v)
			existing.save(cfile)
	else:
		cfg.save(cfile)
	mcm.RegisterConfiguration("lootershooter", "LooterShooter", path, "Per-instance loot rarity and affixes", Callable(self, "apply_config"), self)
	apply_config(ConfigFile.new())

func apply_config(cfg: ConfigFile) -> void:
	if cfg == null or cfg.get_sections().is_empty():
		var path := "user://MCM/lootershooter/config.ini"
		if FileAccess.file_exists(path):
			var c := ConfigFile.new()
			c.load(path)
			_cfg.read(c)
	if cfg != null and not cfg.get_sections().is_empty():
		_cfg.read(cfg)
	_debug.configure(_cfg)

func reroll_item(_item) -> bool:
	return false
