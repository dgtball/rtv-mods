extends RefCounted
# Pure logic: AI.State ints -> awareness category -> colour. No scene access,
# no load(), no paths into the game, so it runs headless (test_states.gd).
# State ints from AI.gd: Idle=0..Group=16. Anything unknown reads as NORMAL.

const NORMAL := 0
const ALERTED := 1
const HUNTING := 2
const COMBAT := 3

const NORMAL_STATES: Array[int] = [0, 1, 2, 3, 4, 15, 16]
const ALERTED_STATES: Array[int] = [5, 10, 12]
const HUNTING_STATES: Array[int] = [9, 6, 7, 14]
const COMBAT_STATES: Array[int] = [8, 11, 13]

const DEFAULT_NORMAL := Color(1.0, 0.72, 0.28)
const DEFAULT_ALERTED := Color(1.0, 0.9, 0.25)
const DEFAULT_HUNTING := Color(1.0, 0.5, 0.1)
const DEFAULT_COMBAT := Color(0.95, 0.18, 0.15)
const DEFAULT_NOMAD := Color(0.30, 1.0, 0.35)

# Detector keys the ring emits. Fixed (never preset-driven) so the overlay
# detector can match them; only the substitution colours vary. Chosen far apart
# and away from MINE_KEY (blue) / MARKER_KEY (green, reserved).
const KEY_NORMAL := Color(1.0, 0.0, 0.0)
const KEY_ALERTED := Color(1.0, 1.0, 0.0)
const KEY_HUNTING := Color(1.0, 0.0, 1.0)
const KEY_COMBAT := Color(0.0, 1.0, 1.0)
const KEY_NOMAD := Color(0.0, 1.0, 0.0)

const CATEGORY_KEY_COLORS: Array[Color] = [KEY_NORMAL, KEY_ALERTED, KEY_HUNTING, KEY_COMBAT]

static func state_key(cat: int) -> Color:
	if cat < 0 or cat >= CATEGORY_KEY_COLORS.size():
		return KEY_NORMAL
	return CATEGORY_KEY_COLORS[cat]

# MCM colour keys, one per category, plus the nomad override.
const CATEGORY_KEYS: Array[String] = ["state_normal", "state_alerted", "state_hunting", "state_combat"]

static var _map: Dictionary = {}

static func _build() -> void:
	if not _map.is_empty():
		return
	for s in NORMAL_STATES:
		_map[s] = NORMAL
	for s in ALERTED_STATES:
		_map[s] = ALERTED
	for s in HUNTING_STATES:
		_map[s] = HUNTING
	for s in COMBAT_STATES:
		_map[s] = COMBAT

static func category_of(state: int) -> int:
	_build()
	return int(_map.get(state, NORMAL))

static func category_key(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_KEYS.size():
		return CATEGORY_KEYS[NORMAL]
	return CATEGORY_KEYS[cat]

static func default_color(cat: int) -> Color:
	match cat:
		ALERTED:
			return DEFAULT_ALERTED
		HUNTING:
			return DEFAULT_HUNTING
		COMBAT:
			return DEFAULT_COMBAT
		_:
			return DEFAULT_NORMAL

static func color_for(state: int) -> Color:
	return default_color(category_of(state))

static func default_nomad() -> Color:
	return DEFAULT_NOMAD

# Raw AI.State names, index == int, order from AI.gd:95 (Idle=0..Group=16).
const STATE_NAMES: Array[String] = [
	"Idle", "Wander", "Loot", "Guard", "Patrol", "Cover", "Hide", "Ambush",
	"Combat", "Hunt", "Defend", "Attack", "Vantage", "Grenade", "Lurk",
	"Switch", "Group",
]

const CATEGORY_NAMES: Array[String] = ["NORMAL", "ALERTED", "HUNTING", "COMBAT"]

static func state_name(state: int) -> String:
	if state < 0 or state >= STATE_NAMES.size():
		return "State" + str(state)
	return STATE_NAMES[state]

static func category_name(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_NAMES.size():
		return CATEGORY_NAMES[NORMAL]
	return CATEGORY_NAMES[cat]

# Two-line debug label: raw state on top, the category the mod assigned below
# (nomad overrides the category, matching the outline colour).
static func label_text(state: int, nomad: bool) -> String:
	return "%s\n%s" % [state_name(state), "NOMAD" if nomad else category_name(category_of(state))]
