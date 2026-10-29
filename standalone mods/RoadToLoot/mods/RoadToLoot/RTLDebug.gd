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
	if event is InputEventKey and event.pressed and not event.echo:
		return int(event.physical_keycode) == _reroll_key
	return false

func should_log() -> bool:
	return _log
