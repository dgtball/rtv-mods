extends "res://Scripts/CatFeeder.gd"

const Rules = preload("res://mods/MoreCatFood/MoreCatFoodRules.gd")

func CreateFeedString() -> String:
	var visible: Array = []
	for element in feedItems:
		var path: String = str(element.resource_path)
		if not Rules.is_beer_path(path):
			visible.append(element)
	var string := ""
	var stringSize := visible.size()
	for element in visible:
		string += String(element.display)
		stringSize -= 1
		if stringSize > 0:
			string += ", "
	return string

func TryFeeding() -> void:
	var beer := false
	var iface = get_tree().current_scene.get_node_or_null("/root/Map/Core/UI/Interface")
	if iface and iface.inventoryGrid:
		for child in iface.inventoryGrid.get_children():
			if child.slotData and child.slotData.itemData:
				var data = child.slotData.itemData
				if data in feedItems:
					beer = Rules.is_beer_path(str(data.resource_path))
					break

	super.TryFeeding()

	if beer:
		var mod = get_node_or_null("/root/MoreCatFood")
		if mod != null and mod.has_method("start_oiia"):
			mod.start_oiia(self)