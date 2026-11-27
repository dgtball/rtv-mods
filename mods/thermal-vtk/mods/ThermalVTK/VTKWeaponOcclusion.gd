extends RefCounted
# Vanilla optics, nothing else. Every runtime patch that used to touch the
# sight materials is gone: the Mask depth swap, the hidden post-mask layers and
# the Objective lens copy all changed what the optic looked like, and together
# they broke the zoom with PIP on. The module stays as a stable no-op so callers
# and VTKScopeDebug keep working.

var _mgr: Node = null
var _dbg_patched: int = 0
var _dbg_layer_skip: int = 0


func set_buffer_occlusion(_enabled: bool, _layer_bit: int = 1 << 19) -> void:
	pass


func tick() -> void:
	pass


func set_scope_mode(_scoped: bool, _pip: bool) -> void:
	pass
