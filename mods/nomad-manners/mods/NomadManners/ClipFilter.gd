extends RefCounted

# Pure helpers for Nomad Manners: which clips are the spits, and taking them out
# of a voice set's array. No nodes, no files, so this is headless-testable.

# Clip file name without folder and without the ".wav" extension.
static func clip_name(clip) -> String:
	if clip == null or not (clip is Object):
		return ""
	var path := str(clip.get("resource_path"))
	if path.is_empty():
		return ""
	return path.get_file().get_basename()

# Removes every clip whose name is in `names` and returns them, in their original
# order. The array is edited in place because the game hands the same AudioEvent
# instance to every nomad that uses that set.
static func remove_matching(clips, names) -> Array:
	var removed: Array = []
	if not (clips is Array) or not (names is Array) or names.is_empty():
		return removed
	for i in range(clips.size() - 1, -1, -1):
		if names.has(clip_name(clips[i])):
			removed.push_front(clips[i])
			clips.remove_at(i)
	return removed

# Names of the clips in `clips`, in order, for the log line.
static func clip_names(clips: Array) -> Array:
	var out: Array = []
	for clip in clips:
		out.append(clip_name(clip) + ".wav")
	return out
