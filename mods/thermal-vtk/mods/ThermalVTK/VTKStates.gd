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
# from here, and direct display contours/overlays use them when a profile carries
# none.
const DEFAULT_NORMAL := Color8(255, 233, 0)
const DEFAULT_COMBAT := Color8(242, 46, 38)
const DEFAULT_DEFEND := Color8(0, 46, 255)
# Default display colour of mine ESP buffer shells. Not a state category.
const DEFAULT_MINE := Color8(205, 0, 255)
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

# Debug-only instrument: F10 walks the three display categories in one fixed
# order. It is deliberately a pure mapping with no scene state or persistence.
static func next_debug_state(cat: int) -> int:
	match cat:
		COMBAT:
			return DEFEND
		DEFEND:
			return NORMAL
		_:
			return COMBAT

const STATE_NAMES: Array[String] = [
	"Idle", "Wander", "Loot", "Guard", "Patrol", "Cover", "Hide", "Ambush",
	"Combat", "Hunt", "Defend", "Attack", "Vantage", "Grenade", "Lurk",
	"Switch", "Group",
]

static func state_name(state: int) -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "State" + str(state)
	return STATE_NAMES[state]
