extends Node

const Log = preload("res://mods/LooterShooter/LSHLog.gd")

var _lib = null

func _ready() -> void:
	Log.line("booted")

func reroll_item(_item) -> bool:
	return false
