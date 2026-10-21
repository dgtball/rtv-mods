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

const DEFAULT_NORMAL := Color(1.0, 0.72, 0.28)
const DEFAULT_COMBAT := Color(0.95, 0.18, 0.15)
const DEFAULT_DEFEND := Color(0.62, 0.30, 0.95)

# Detector keys the ring emits; the overlay detector matches them and swaps in
# the category colour. The body-fill keys and the nomad key follow the same
# rule. The overlay matches the CLOSEST key within 0.22, so every key -- the
# outline, fill and nomad ones alike -- must stay more than 0.22 apart.
const KEY_NORMAL := Color(1.0, 0.0, 0.0)
const KEY_COMBAT := Color(0.0, 1.0, 1.0)
const KEY_DEFEND := Color(1.0, 0.0, 1.0)

const CATEGORY_KEY_COLORS: Array[Color] = [KEY_NORMAL, KEY_COMBAT, KEY_DEFEND]

# Body-fill keys. Separate from the outline keys so the overlay can give the
# fill its own density; one per category so the fill carries the state colour.
# Chosen far from every other key and from the display colours: the overlay
# detects by raw distance, so overlap would mis-classify.
const KEY_FILL_NORMAL := Color(0.0, 0.35, 1.0)
const KEY_FILL_COMBAT := Color(0.0, 1.0, 0.35)
const KEY_FILL_DEFEND := Color(1.0, 0.55, 0.0)

const FILL_KEY_COLORS: Array[Color] = [KEY_FILL_NORMAL, KEY_FILL_COMBAT, KEY_FILL_DEFEND]

# Friendly-nomad marker key (green display colour proposed by the overlay).
const KEY_NOMAD := Color(0.35, 0.0, 1.0)

static func fill_key(cat: int) -> Color:
	if cat < 0 or cat >= FILL_KEY_COLORS.size():
		return KEY_FILL_NORMAL
	return FILL_KEY_COLORS[cat]

static func state_key(cat: int) -> Color:
	if cat < 0 or cat >= CATEGORY_KEY_COLORS.size():
		return KEY_NORMAL
	return CATEGORY_KEY_COLORS[cat]

const CATEGORY_KEYS: Array[String] = ["state_normal", "state_combat", "state_defend"]

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

static func category_key(cat: int) -> String:
	if cat < 0 or cat >= CATEGORY_KEYS.size():
		return CATEGORY_KEYS[NORMAL]
	return CATEGORY_KEYS[cat]

static func default_color(cat: int) -> Color:
	match cat:
		COMBAT:
			return DEFAULT_COMBAT
		DEFEND:
			return DEFAULT_DEFEND
		_:
			return DEFAULT_NORMAL

static func color_for(state: int) -> Color:
	return default_color(category_of(state))

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
