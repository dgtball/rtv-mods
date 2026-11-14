extends RefCounted
# Pure logic: AI.State ints -> awareness category and display defaults/names.
# No scene access, no load(), no paths into the game, so it runs headless
# (test_states.gd). State ints from AI.gd: Idle=0..Group=16. Anything unknown
# reads as NORMAL.

const NORMAL := 0
const COMBAT := 1
const DEFEND := 2

const NORMAL_STATES: Array[int] = [0, 1, 2, 3, 4, 16]
const COMBAT_STATES: Array[int] = [8, 9, 11, 13]
const DEFEND_STATES: Array[int] = [5, 6, 7, 10, 12, 14, 15]

# The ONLY place the three default ESP display colours exist. VTKSettings
# derives both the MCM defaults (DESCRIPTORS "def") and the typed Rec defaults
# from here, and ESP/direct materials use them when a profile carries none.
const DEFAULT_NORMAL := Color(0.98, 0.96, 0, 1)
const DEFAULT_COMBAT := Color(0.95, 0.18, 0.15)
const DEFAULT_DEFEND := Color(0.11, 0.6, 0.96, 1)
# Display colour of the direct mine highlight. Not a state category.
const DEFAULT_MINE := Color(1.0, 0.2, 0.85, 1)

static var _map: Dictionary = {}

static func _build() -> void:
	if not _map.is_empty():
		return
	for s in NORMAL_STATES:
		_map[s] = NORMAL
	for s in COMBAT_STATES:
		_map[s] = COMBAT
	for s in DEFEND_STATES:
		_map[s] = DEFEND

static func category_of(state: int) -> int:
	_build()
	return int(_map.get(state, NORMAL))

const STATE_NAMES: Array[String] = [
	"Idle", "Wander", "Loot", "Guard", "Patrol", "Cover", "Hide", "Ambush",
	"Combat", "Hunt", "Defend", "Attack", "Vantage", "Grenade", "Lurk",
	"Switch", "Group",
]

static func state_name(state: int) -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "State" + str(state)
	return STATE_NAMES[state]
