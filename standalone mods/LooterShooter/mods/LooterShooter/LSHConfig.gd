extends RefCounted

var paint_cells: bool = true
var show_affix_block: bool = true
var freq_mult: float = 1.0
var tier_palette: int = 0
var border_width: float = 2.0
var hide_vanilla_rarity: bool = false
var debug_enabled: bool = false
var debug_force_tier: int = 0
var debug_reroll_key: int = 0
var log_rolls: bool = false
var notify_legendary: bool = false
var env_hint: bool = true

func read(cfg: ConfigFile) -> void:
	paint_cells = _b(cfg, "paint_cells", paint_cells)
	show_affix_block = _b(cfg, "show_affix_block", show_affix_block)
	freq_mult = _f(cfg, "freq_mult", freq_mult)
	tier_palette = _i(cfg, "tier_palette", tier_palette)
	border_width = _f(cfg, "border_width", border_width)
	hide_vanilla_rarity = _b(cfg, "hide_vanilla_rarity", hide_vanilla_rarity)
	debug_enabled = _b(cfg, "debug_enabled", debug_enabled)
	debug_force_tier = _i(cfg, "debug_force_tier", debug_force_tier)
	debug_reroll_key = _i(cfg, "debug_reroll_key", debug_reroll_key)
	log_rolls = _b(cfg, "log_rolls", log_rolls)
	notify_legendary = _b(cfg, "notify_legendary", notify_legendary)
	env_hint = _b(cfg, "env_hint", env_hint)

func _val(cfg: ConfigFile, key: String):
	for section in ["Bool", "Int", "Float", "Dropdown", "Keycode", "String"]:
		if cfg.has_section_key(section, key):
			var v = cfg.get_value(section, key)
			if v is Dictionary and v.has("value"):
				return v["value"]
			if v is Dictionary or v == null:
				return null
			return v
	return null

func _b(cfg: ConfigFile, key: String, def: bool) -> bool:
	var v = _val(cfg, key)
	if v is bool:
		return v
	return def

func _i(cfg: ConfigFile, key: String, def: int) -> int:
	var v = _val(cfg, key)
	if v is int:
		return v
	if v is float:
		return int(v)
	return def

func _f(cfg: ConfigFile, key: String, def: float) -> float:
	var v = _val(cfg, key)
	if v is float:
		return v
	if v is int:
		return float(v)
	return def
