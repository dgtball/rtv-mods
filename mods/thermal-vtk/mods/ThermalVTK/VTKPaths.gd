extends RefCounted
# Hard paths into the game used by ThermalVTK. Absolute NodePaths from the tree
# root, so they resolve through get_node_or_null(...) from any node. Fix here on
# a game update, not in each file.

const LOADER := "/root/Loader"
const NVG := "/root/Map/Core/UI/NVG"
const WORLD := "/root/Map/World"
const SIMULATION := "/root/Simulation"
const CAMERA_MANAGER := "/root/Map/Core/Camera/Manager"
const GAME_DATA := "res://Resources/GameData.tres"
const AI_SCRIPT_SUFFIX := "/Scripts/AI.gd"
