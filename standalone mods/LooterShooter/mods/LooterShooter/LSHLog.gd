extends RefCounted

const PREFIX := "[LSH] "

static func line(msg: String) -> void:
	print(PREFIX + msg)

static func warn(msg: String) -> void:
	push_warning(PREFIX + msg)
