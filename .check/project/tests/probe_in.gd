extends SceneTree

func _init() -> void:
	var pip := Node3D.new()
	pip.name = "PIP"
	var mid := Node3D.new()
	mid.name = "MID"
	var top := Node3D.new()
	top.name = "TOP"
	top.add_child(mid)
	mid.add_child(pip)
	# "in" on Object: does it match the node's own name? a child's name? meta?
	print("ownname_PIP: ", "PIP" in pip)
	print("ownname_TOP: ", "PIP" in top)
	print("meta_parent_name: ", "PIP" in mid)
	pip.set_meta("PIP", true)
	print("meta_set_on_pip: ", "PIP" in pip)
	top.set_meta("PIP", 1)
	print("meta_set_on_top_seen_from_mid: ", "PIP" in mid)
	# properties (script var) case
	var s := GDScript.new()
	s.source_code = "extends Node3D\nvar PIP := false\n"
	s.reload()
	var scripted = s.new()
	print("script_var_true_false: ", "PIP" in scripted)
	scripted.PIP = true
	print("script_var_true: ", "PIP" in scripted)
	quit(0)
