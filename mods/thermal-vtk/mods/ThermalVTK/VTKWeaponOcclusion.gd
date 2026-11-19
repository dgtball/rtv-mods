extends RefCounted
# 2.10.x diagnostic baseline stub: main-pass weapon occlusion patching and ESP
# buffer weapon occluders are intentionally disabled/removed. Preserve the API
# used by callers and scope debug with safe no-op behavior.

var _mgr: Node = null
var _dbg_patched: int = 0
var _dbg_layer_skip: int = 0

func set_buffer_occlusion(_enabled: bool, _layer_bit: int = 1 << 19) -> void:
	pass

func tick() -> void:
	pass

func set_scope_mode(_scoped: bool, _pip: bool) -> void:
	pass
