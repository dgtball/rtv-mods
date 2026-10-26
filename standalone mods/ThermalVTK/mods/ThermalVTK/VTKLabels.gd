extends RefCounted
# Pure label-text helpers: no scene, no load(), no game paths. Headless-safe
# (test_labels.gd). Strings and pure math only.

const States = preload("res://mods/ThermalVTK/VTKStates.gd")

static func name_of(variant_name: String, nickname: String) -> String:
	var n: String = nickname.strip_edges()
	if n != "":
		return n
	return variant_name

static func header(name: String, dist: float) -> String:
	return "%s  %d m" % [name, int(round(dist))]

static func status(state: int, reloading: bool, vs: String) -> String:
	var txt: String = States.state_name(state)
	if reloading:
		txt += ", reloading"
	if vs != "":
		txt += " " + vs
	return txt

static func trigger_suffix(win: Dictionary, now: float) -> String:
	if win.is_empty():
		return ""
	var expires: float = float(win.get("expires", 0.0))
	if expires <= now:
		return ""
	var source: String = str(win.get("source", ""))
	var dist: float = float(win.get("dist", 0.0))
	var left: float = max(0.0, expires - now)
	return "  [%s %.1fs %.0fm]" % [source, left, dist]

static func health_frac(health: float, max_health: float) -> float:
	if max_health <= 0.0:
		return 1.0
	return clampf(health / max_health, 0.0, 1.0)
