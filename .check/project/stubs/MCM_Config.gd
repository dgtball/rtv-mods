class_name MCM_Config
extends RefCounted

enum MCM_Key_Types { KEY, MOUSE }

func _init(_mod_id: String, _name: String, _desc: String, _save_cb, _obj = null) -> void:
	pass

func CreateKeycodeValue(_id: String, _name: String, _tooltip: String, _default: Key, _type: int):
	return self

func setCategory(_category: String):
	return self

func RegisterMod() -> void:
	pass
