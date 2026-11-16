extends SceneTree

const Filter = preload("res://mods/NomadManners/ClipFilter.gd")
const Mod = preload("res://mods/NomadManners/NomadManners.gd")

const SPIT_A := "Nomad_Random_11"
const SPIT_B := "Nomad_Random_17"
const BASE := "res://Audio/NPC/Nomad/Files/"

var fails := 0


class FakeClip extends RefCounted:
	var resource_path: String

	func _init(path: String) -> void:
		resource_path = path


func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)


func clip(name: String):
	return FakeClip.new(BASE + name + ".wav")


func names_of(clips: Array) -> Array:
	var out: Array = []
	for c in clips:
		out.append(Filter.clip_name(c))
	return out


func _init() -> void:
	t_clip_name()
	t_remove_matching()
	t_remove_none()
	t_remove_both()
	t_in_place()
	t_bad_input()
	t_clip_names()
	t_mod_contract()
	print("")
	if fails == 0:
		print("NomadManners tests passed")
		quit(0)
	else:
		print("NomadManners tests failed: ", fails)
		quit(1)


func t_clip_name() -> void:
	ck(Filter.clip_name(clip(SPIT_A)) == SPIT_A, "clip name from resource_path")
	ck(Filter.clip_name(null) == "", "null clip has no name")
	ck(Filter.clip_name(FakeClip.new("")) == "", "empty path has no name")
	ck(Filter.clip_name("Nomad_Random_11") == "", "plain string is not a clip")


func t_remove_matching() -> void:
	var clips: Array = [clip("Nomad_Idle_01"), clip(SPIT_A), clip("Nomad_Idle_02")]
	var removed: Array = Filter.remove_matching(clips, [SPIT_A])
	ck(removed.size() == 1, "one spit removed")
	ck(Filter.clip_name(removed[0]) == SPIT_A, "removed clip is the spit")
	ck(names_of(clips) == ["Nomad_Idle_01", "Nomad_Idle_02"], "other clips kept in order")


func t_remove_none() -> void:
	var clips: Array = [clip("Nomad_Idle_01"), clip("Nomad_Idle_02")]
	var removed: Array = Filter.remove_matching(clips, [SPIT_A, SPIT_B])
	ck(removed.is_empty(), "nothing removed from a clean set")
	ck(clips.size() == 2, "clean set untouched")


func t_remove_both() -> void:
	var clips: Array = [
		clip("Nomad_Idle_01"), clip(SPIT_A), clip("Nomad_Idle_03"),
		clip(SPIT_B), clip("Nomad_Random_01"),
	]
	var removed: Array = Filter.remove_matching(clips, [SPIT_A, SPIT_B])
	ck(removed.size() == 2, "both spits removed")
	ck(names_of(removed) == [SPIT_A, SPIT_B], "removed clips keep their order")
	ck(names_of(clips) == ["Nomad_Idle_01", "Nomad_Idle_03", "Nomad_Random_01"], "the rest stays")


func t_in_place() -> void:
	var clips: Array = [clip(SPIT_A), clip("Nomad_Idle_01")]
	var shared := clips
	Filter.remove_matching(clips, [SPIT_A])
	ck(shared.size() == 1, "the caller's array is edited, not replaced")
	ck(Filter.clip_name(shared[0]) == "Nomad_Idle_01", "shared array holds the survivor")


func t_bad_input() -> void:
	ck(Filter.remove_matching(null, [SPIT_A]).is_empty(), "null clip list")
	ck(Filter.remove_matching("nope", [SPIT_A]).is_empty(), "non-array clip list")
	ck(Filter.remove_matching([clip(SPIT_A)], null).is_empty(), "null name list")
	ck(Filter.remove_matching([clip(SPIT_A)], []).is_empty(), "empty name list")
	var clips: Array = [null, clip(""), clip(SPIT_A)]
	var removed: Array = Filter.remove_matching(clips, [SPIT_A])
	ck(removed.size() == 1, "null and nameless entries are skipped")
	ck(clips.size() == 2, "null and nameless entries are kept")


func t_clip_names() -> void:
	var out: Array = Filter.clip_names([clip(SPIT_A), clip(SPIT_B)])
	ck(out == [SPIT_A + ".wav", SPIT_B + ".wav"], "clip names for the log line")


func t_mod_contract() -> void:
	ck(Mod.REMOVED_CLIPS.size() == 2, "two clips are removed")
	ck(Mod.REMOVED_CLIPS.has(SPIT_A), "the first spit is on the list")
	ck(Mod.REMOVED_CLIPS.has(SPIT_B), "the second spit is on the list")
	ck(Mod.SET_PROPS.has("idleVoices"), "the idle voice set is covered")
	ck(Mod.SET_PROPS.size() == 4, "all four nomad voice sets are covered")
