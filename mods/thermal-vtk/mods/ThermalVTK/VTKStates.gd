extends RefCounted
# Pure logic: AI.State ints -> awareness category -> colour. No scene access,
# no load(), no paths into the game, so it runs headless (test_states.gd).
# State ints from AI.gd: Idle=0..Group=16. Anything unknown reads as NORMAL.

const NORMAL := 0
const COMBAT := 1
const DEFEND := 2

const NORMAL_STATES: Array[int] = [0, 1, 2, 3, 4, 16]
const COMBAT_STATES: Array[int] = [8, 9, 11, 13]
const DEFEND_STATES: Array[int] = [5, 6, 7, 10, 12, 14, 15]

# The ONLY place the three default outline colours exist. VTKSettings derives
# both the MCM defaults (DESCRIPTORS "def") and the typed Rec defaults from
# here, and VTKNVG uses them as the fallback when a profile carries no colour.
const DEFAULT_NORMAL := Color(0.98, 0.96, 0, 1)
const DEFAULT_COMBAT := Color(0.95, 0.18, 0.15)
const DEFAULT_DEFEND := Color(0.11, 0.6, 0.96, 1)
# Display colour of the mine ESP. Not a state: a mine is painted whole, so this
# one never has to share the screen with a category key. Magenta sits furthest
# from all three state colours (yellow, red, light blue).
const DEFAULT_MINE := Color(1.0, 0.2, 0.85, 1)
# Detector keys the contour shell overlay writes into the main 3D pass. The
# overlay matches the CLOSEST washed key within DET_TOL_CORE and swaps in the
# display colour, so the keys have to stay more than that radius apart AFTER
# the NVG wash (the measured pairs live in VTKNVG.gd DET_ST_*). Combat and
# defend are two-channel keys on purpose: measured 2026-10-24, pure green and
# pure blue do not survive the wash far enough from the world and from each
# other. Red / cyan / magenta is the set the shipped screen-key detector used.
const KEY_NORMAL := Color(1.0, 0.0, 0.0, 1)
const KEY_COMBAT := Color(0.0, 1.0, 1.0, 1)
const KEY_DEFEND := Color(1.0, 0.0, 1.0, 1)
const CATEGORY_KEY_COLORS: Array[Color] = [KEY_NORMAL, KEY_COMBAT, KEY_DEFEND]


static func state_key(cat: int) -> Color:
	if cat < 0 or cat >= CATEGORY_KEY_COLORS.size():
		return KEY_NORMAL
	return CATEGORY_KEY_COLORS[cat]

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

const CATEGORY_NAMES: Array[String] = ["NORMAL", "COMBAT", "DEFEND"]

static func state_name(state: int) -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "State" + str(state)
	return STATE_NAMES[state]

static func category_name(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_NAMES.size():
		return CATEGORY_NAMES[NORMAL]
	return CATEGORY_NAMES[cat]

# Two-line debug label: raw state on top, the category below.
static func label_text(state: int, _nomad: bool) -> String:
	return "%s\n%s" % [state_name(state), category_name(category_of(state))]
