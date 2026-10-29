extends SceneTree
func _init():
	var host = load("res://Host.gd").new()
	var ext = load("res://mods/LooterShooter/Scripts/SlotData.gd")
	var e = ext.new()
	host.loot.append(e)
	print("after append size=", host.loot.size())
	for x in host.loot:
		print("elem script_path=", x.get_script().resource_path, " has loot_tier=", "loot_tier" in x)
	quit()
