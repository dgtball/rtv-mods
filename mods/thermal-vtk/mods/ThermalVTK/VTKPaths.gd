extends RefCounted
# Hard paths into the game used by ThermalVTK. Absolute NodePaths from the tree
# root, so they resolve through get_node_or_null(...) from any node. Fix here on
# a game update, not in each file.
#
# Also the one reader of the mod's own version file: the version is written from
# mod.txt at build time, and only ever displayed (MCM Info, debug log header),
# so nothing in the mod gates on it.

const LOADER := "/root/Loader"
const NVG := "/root/Map/Core/UI/NVG"
const WORLD := "/root/Map/World"
const SIMULATION := "/root/Simulation"
const CAMERA_MANAGER := "/root/Map/Core/Camera/Manager"
const GAME_DATA := "res://Resources/GameData.tres"
const VERSION_FILE := "res://mods/ThermalVTK/version.txt"

static func mod_version() -> String:
	var vf := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if vf == null:
		return "unknown"
	var v := vf.get_as_text().strip_edges()
	vf.close()
	return v if v != "" else "unknown"
