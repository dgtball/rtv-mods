extends RefCounted

var _enabled: bool = false
var _force_tier: int = 0
var _reroll_key: int = 0
var _log: bool = false

func configure(cfg) -> void:
	_enabled = cfg.debug_enabled
	_force_tier = cfg.debug_force_tier
	_reroll_key = cfg.debug_reroll_key
	_log = cfg.log_rolls

func force_tier() -> int:
	if not _enabled:
		return 0
	return _force_tier

func reroll_enabled() -> bool:
	return _enabled and _reroll_key != 0

func matches_reroll(event: InputEvent) -> bool:
	if not reroll_enabled():
		return false
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	# MCM stores a physical keycode, but a key event may arrive with only the
	# logical keycode populated (and vice versa on some layouts). Accept either
	# so a repeated press is never silently dropped by a zero code field.
	var physical := int(event.physical_keycode)
	if physical != 0 and physical == _reroll_key:
		return true
	return int(event.keycode) == _reroll_key

func should_log() -> bool:
	return _log
