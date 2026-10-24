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
# the category colour. The overlay matches the CLOSEST key within its radius
# (DET_TOL_CORE in VTKNVG.gdshader), so every key -- the three outline keys, the
# mine key and the nomad key -- must stay more than that radius apart, or one
# key's detector can claim another key's pixel. The current minimum is well
# above the radius.
const KEY_NORMAL := Color(1.0, 0.0, 0.0)
# Bright by design (measured 2026-10-24 against three dimming candidates,
# calibration cand08/09/10). The KEY_NOMAD lesson holds: a key survives the
# wash with a dominant channel and two near-zero channels. Reducing this
# key's dominant pair collapses the post-NVG pixel into neutral gray
# (cand08 (0,0.60,0.72) -> (0.22,0.25,0.25), spread 0.03), which palette
# midtones then claim; dropping the dominant light entirely (cand09
# (0,0.10,0.70) -> (0.05,0.07,0.11)) keeps hue stable but lands inside the
# palette dark bands -- a 2D claim surface no guard can separate. A variant
# with the dominant channel kept bright and only the secondary dimmed
# (cand10 (0,0.55,1.00)) measured two clean anchor orbits (day
# (0.20,0.32,0.50) / night (0.13,0.60,0.93)) and is parked for a later pass:
# it needs a day/night-lerped detector constant first, plus an Ice-palette
# day claim check, and a day/night fix is scheduled before that. Until then
# the wash guard in VTKNVG.gdshader is the mechanism, not a patch.
const KEY_COMBAT := Color(0.0, 1.0, 1.0)
const KEY_DEFEND := Color(1.0, 0.0, 1.0)

const CATEGORY_KEY_COLORS: Array[Color] = [KEY_NORMAL, KEY_COMBAT, KEY_DEFEND]

# Friendly-nomad marker key (green display colour proposed by the overlay).
# The rule above applies: it must stay clear of the mine key, or a washed
# nomad marker reads as a mine. Calibrated: a green whose red and blue stay
# near zero survives the NVG wash as green, where a bright green
# (0.6, 1.0, 0.6) washed out to pure white and lost the marker.
const KEY_NOMAD := Color(0.02, 0.60, 0.24)

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
