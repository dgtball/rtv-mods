extends Node

const ClipFilter := preload("res://mods/StopSpitting/ClipFilter.gd")

# Stop Spitting: stops the nomads from spitting.
#
# Every nomad variant (res://AI/Nomad/AI_Nomad_A/B/C.tres, an AIData resource)
# points at the same four AudioEvent sets under res://Audio/NPC/Nomad/, and the
# idle set is played by AI.gd's Voices() and by NomadAnim.gd on a 10-60 s cycle
# while the player stands nearby. AudioInstance3D.PlayInstance() picks a random
# clip out of the event's audioClips array, so a clip that is not in the array is
# never played. Two of the 41 idle clips are spits: Nomad_Random_11.wav and
# Nomad_Random_17.wav.
#
# This autoload watches the scene tree for nodes carrying an AIData resource
# (`variant` on NomadAnim, `variants` on AI; the second one is what is readable
# when the node is added, because AI assigns `variant` later in SelectVariant())
# and takes those two clips out of each voice set it meets, in place. The
# AudioEvent instances are shared by every nomad using them, so one change
# covers them all. Nothing is hooked or replaced, no game resource is written to
# disk, and the clips are put back if the mod is removed from the tree.

const PREFIX := "[StopSpitting] "
# Clip file names (without folder and extension) to remove, in any nomad's set.
const REMOVED_CLIPS := ["Nomad_Random_11", "Nomad_Random_17"]
# AIData property -> set id, for the log line.
const SET_PROPS := {
	"idleVoices": "idle",
	"combatVoices": "combat",
	"damageVoices": "damage",
	"deathVoices": "death",
}

# AudioEvent instance id -> {"event", "set", "removed": Array}
var _events: Dictionary = {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _exit_tree() -> void:
	for id in _events:
		var entry: Dictionary = _events[id]
		var ev = entry["event"]
		if not is_instance_valid(ev):
			continue
		var clips = ev.get("audioClips")
		if not (clips is Array):
			continue
		for clip in entry["removed"]:
			if not clips.has(clip):
				clips.append(clip)
	_events.clear()


func _scan(node: Node) -> void:
	for data in _datas_of(node):
		_register(data)
	for child in node.get_children():
		_scan(child)


func _on_node_added(node: Node) -> void:
	for data in _datas_of(node):
		_register(data)


# AIData resources this node carries, through either property. NomadAnim exports
# `variant`; AI exports `variants` and fills `variant` only in SelectVariant().
func _datas_of(node: Node) -> Array:
	var out: Array = []
	var single = node.get("variant")
	if single != null:
		out.append(single)
	var many = node.get("variants")
	if many is Array:
		for v in many:
			if v != null:
				out.append(v)
	return out


func _register(data) -> void:
	if data == null or not (data is Resource):
		return
	for prop in SET_PROPS:
		var ev = data.get(prop)
		if ev == null or not (ev is Resource) or not ("audioClips" in ev):
			continue
		var id: int = ev.get_instance_id()
		if _events.has(id):
			continue
		var clips = ev.get("audioClips")
		var removed: Array = ClipFilter.remove_matching(clips, REMOVED_CLIPS)
		_events[id] = {"event": ev, "set": str(SET_PROPS[prop]), "removed": removed}
		if not removed.is_empty():
			print(PREFIX + str(data.get("name")) + " " + str(SET_PROPS[prop]) + ": clips "
				+ str(clips.size()) + "/" + str(clips.size() + removed.size()) + " kept, removed "
				+ str(ClipFilter.clip_names(removed)))
