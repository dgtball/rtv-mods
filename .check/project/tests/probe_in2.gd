extends SceneTree

func _init() -> void:
	# Scripted node WITHOUT a PIP member: does "PIP" in obj stay false?
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar alpha := 1.0\nfunc Ping() -> void:\n\tpass\n"
	s.reload()
	var n = s.new()
	print("script_no_member: ", "PIP" in n)
	# Script WITH a function named PIP (no property)
	var s2 := GDScript.new()
	s2.source_code = "extends Node3D\nfunc PIP() -> void:\n\tpass\n"
	s2.reload()
	var n2 = s2.new()
	print("script_func_pip: ", "PIP" in n2)
	# Script with static/member signal named PIP
	var s3 := GDScript.new()
	s3.source_code = "extends Node3D\nsignal PIP\n"
	s3.reload()
	var n3 = s3.new()
	print("script_signal_pip: ", "PIP" in n3)
	# Node has a meta named PIP set via set() (not set_meta)
	var p := Node3D.new()
	p.name = "PIP"
	n.add_child(p)
	print("child_named_PIP_from_parent: ", "PIP" in n)
	quit(0)
