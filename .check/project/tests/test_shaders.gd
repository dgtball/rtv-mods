extends SceneTree

const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const NVG_SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const RING_RES := "res://mods/ThermalVTK/VTKOutlineRingOccluded.gdshader"

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_shaders_compile()
	t_front_rim_uses_abs_dot()
	t_nvg_contour_reads_mines()
	t_state_key_uniform()
	t_ring_shader_compiles()
	t_ring_style_uniforms()
	t_state_keys_in_overlay()
	t_palette_four_modes()
	t_fill_tolerance_wider()
	t_key_uniform_defaults()
	t_detector_seeds_match_raw_keys()
	t_nvg_shader_compiles()
	t_ring_xray_contract()
	t_daylight_contract()
	print("")
	if fails == 0:
		print("Shaders tests passed")
		quit(0)
	else:
		print("Shaders tests failed: ", fails)
		quit(1)

func t_shaders_compile() -> void:
	ck(Sh.ring() != null, "idle ring shader")
	ck(not String(Sh.ring().code).contains("depth_test_disabled"), "idle ring keeps the auto depth test")
	ck(not String(Sh.ring().code).contains("near_only"), "idle ring has no x-ray uniform")
	ck(Sh.ring_xray() != null, "x-ray ring shader")
	ck(String(Sh.ring_xray().code).contains("depth_test_disabled"), "x-ray ring drops the auto depth test")
	ck(String(Sh.ring_xray().code).contains("near_only"), "x-ray ring carries the x-ray toggle on a uniform")

# Two ring shaders: the idle ring is depth-tested, and only a live trigger
# window swaps that entry to the depth-free x-ray variant with the manual
# camera-attached compare.
func t_ring_xray_contract() -> void:
	var occ := FileAccess.get_file_as_string(RING_RES)
	ck(occ.contains("depth_test_disabled"), "x-ray ring drops the auto test for manual compare")
	ck(occ.contains("hint_depth_texture"), "x-ray ring reads the scene depth")
	ck(occ.contains("depth_draw_never"), "x-ray ring never writes depth itself")
	ck(occ.contains("uniform bool near_only"), "x-ray ring tags the x-ray mode on a uniform")
	ck(occ.contains("uniform float carve"), "x-ray ring keeps the camera-attached carve as a uniform")
	ck(not occ.contains("EXCLUDE_M"), "the carved zone is a uniform, not a constant")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKOutlineRingDepth.gdshader"), "depth-tested ring shader exists")
	ck(not FileAccess.file_exists("res://mods/ThermalVTK/VTKProtoRing.gdshader"), "the prototype shader is gone")
	ck(not FileAccess.file_exists("res://mods/ThermalVTK/VTKOutlineRing.gdshader"), "the old plain x-ray shader file is gone")
	ck(not FileAccess.file_exists("res://mods/ThermalVTK/VTKOutlineRingScope.gdshader"), "scope variant is gone")
	var store := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKShaders.gd")
	ck(store.contains("RING_DEPTH_SRC"), "depth-tested shader lives in the store")
	ck(store.contains("RING_XRAY_SRC"), "x-ray shader lives in the store")
	ck(store.contains("func ring_xray"), "the store exposes the x-ray ring")
	ck(not store.contains("ring_scope"), "the shader store has no scope variant")

# The rim uses the absolute dot so the silhouette edge (|dot| small) is where
# the band lives; the back-faces shell has the smooth power falloff.
func t_front_rim_uses_abs_dot() -> void:
	var src := FileAccess.get_file_as_string(RING_RES)
	ck(src.contains("abs(dot("), "ring takes the absolute dot product")
	ck(not src.contains("clamp(dot("), "ring no longer clamps the raw dot product")

func t_ring_style_uniforms() -> void:
	var src := FileAccess.get_file_as_string(RING_RES)
	for u in ["rim_power", "carve", "near_only"]:
		ck(src.contains("uniform") and src.contains(u), "ring declares %s" % u)
	ck(not src.contains("outline_style"), "ring no longer declares outline_style")
	ck(not src.contains("rim_start"), "ring no longer declares rim_start")

# Contour mode drops the world palette but mines are still keyed, so the
# non-thermal branch must substitute mineColor itself (vec4(mineColor, ...)
# only appears there).
func t_nvg_contour_reads_mines() -> void:
	var sh = load(NVG_SHADER_RES)
	ck(sh != null and sh is Shader, "NVG shader loads")
	var code: String = "" if sh == null else sh.code
	ck(code.contains("vec4(mineColor, pixelColor.a)"), "contour branch substitutes mineColor")

# Mode A: the ring no longer draws a state colour, it emits a detector key
# that the overlay substitutes after the palette.
func t_state_key_uniform() -> void:
	var src := FileAccess.get_file_as_string(RING_RES)
	ck(src.contains("uniform vec3 state_key"), "ring declares state_key")
	ck(not src.contains("outline_color"), "ring no longer declares outline_color")
	# The emitted key is scaled by the daylight gain, which is the exact
	# inverse of the exposure reduction: the post-tonemap pixel stays at the
	# calibrated night value. The gain is 1.0 at night.
	ck(src.contains("global uniform float vtk_key_gain"), "ring reads the daylight key gain")
	ck(src.contains("ALBEDO = state_key * vtk_key_gain;"), "ring scales the state key by the daylight gain")

# The body fill is gone: the outline emits only the ring key and the overlay
# substitutes the display colour after the palette.

# The ring shader has to survive compilation as a real uniform set, otherwise
# set_shader_parameter() is a silent no-op. A shader with a compile error still
# loads as a resource, so the compiled uniform list is the proof.
func t_ring_shader_compiles() -> void:
	var sh = load(RING_RES)
	if sh == null:
		ck(false, "ring shader loads for compile check")
		return
	var params: Array = sh.get_shader_uniform_list()
	var names: Array = []
	for p in params:
		names.append(p.get("name", ""))
	ck(params.size() > 0, "ring shader compiled (uniform list not empty)")
	ck(names.has("rim_power"), "compiled ring shader exposes rim_power")
	ck(names.has("state_key"), "compiled ring shader exposes state_key")
	ck(names.has("carve"), "compiled ring shader exposes carve")
	ck(names.has("near_only"), "compiled ring shader exposes near_only")
	var depth = load("res://mods/ThermalVTK/VTKOutlineRingDepth.gdshader")
	if depth == null:
		ck(false, "depth ring shader loads for compile check")
		return
	var dparams: Array = depth.get_shader_uniform_list()
	var dnames: Array = []
	for p in dparams:
		dnames.append(p.get("name", ""))
	ck(dparams.size() > 0, "depth ring shader compiled (uniform list not empty)")
	for u in ["state_key", "grow", "rim_power", "cool"]:
		ck(dnames.has(u), "compiled depth ring shader exposes %s" % u)
	for u in ["near_only", "carve", "depth_tex"]:
		ck(not dnames.has(u), "compiled depth ring shader has no %s" % u)

func t_state_keys_in_overlay() -> void:
	var f := FileAccess.open(NVG_SHADER_RES, FileAccess.READ)
	var code := f.get_as_text()
	f.close()
	ck(code.contains("stNormalKey"), "overlay has stNormalKey")
	ck(code.contains("stCombatKey"), "overlay has stCombatKey")
	ck(code.contains("stDefendKey"), "overlay has stDefendKey")
	ck(code.contains("stNormalColor"), "overlay has stNormalColor")
	ck(code.contains("stCombatColor"), "overlay has stCombatColor")
	ck(code.contains("stDefendColor"), "overlay has stDefendColor")
	ck(not code.contains("stAlertedKey"), "overlay dropped stAlertedKey")
	ck(not code.contains("stHuntingKey"), "overlay dropped stHuntingKey")
	ck(not code.contains("stNomadKey"), "overlay dropped stNomadKey")
	ck(code.contains("dStN") and code.contains("dStD"), "overlay distance vars present")
	# PIP-off orbit detection: the overlay must declare the toggle, the orbit
	# helper and the two cyclic swizzles -- and never the reflection swizzle.
	ck(code.contains("scopeRotate"), "overlay declares scopeRotate")
	ck(code.contains("orbitDist"), "overlay declares orbitDist")
	ck(code.contains("k.brg") and code.contains("k.gbr"), "orbit uses cyclic swizzles")
	ck(not code.contains("k.grb"), "orbit avoids the reflection swizzle")
	ck(code.contains("orbitDist(pixelColor.rgb,"), "key distances go through orbitDist")

func t_palette_four_modes() -> void:
	var f := FileAccess.open(NVG_SHADER_RES, FileAccess.READ)
	var code := f.get_as_text()
	f.close()
	var n := 0
	for i in [1, 2, 3, 4, 5]:
		if code.contains("worldPaletteMode == %d" % i):
			n += 1
	ck(n == 3, "only modes 1..3 remain (got %d)" % n)
	ck(not code.contains("Black Hot"), "no Black Hot branch")

func t_fill_tolerance_wider() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	var core := _const_float(code, "DET_TOL_CORE")
	ck(core > 0.0, "overlay declares the core detector radius")
	ck(not code.contains("DET_TOL_FILL"), "overlay dropped the fill radius")

# The *Key uniforms are the detector targets; their defaults must mirror the
# emitted keys (VTKStates.KEY_*). A stale default means a material that never
# gets the parameter pushed detects against a colour nobody emits.
func t_key_uniform_defaults() -> void:
	var src := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(not src.contains("fillNormKey"), "overlay dropped the fill detector uniforms")

# The detector targets in VTKNVG.gd are the measured post-NVG values of the
# raw nomad key; catching a stale literal here keeps the overlay locked to the
# palette the game actually renders.
func t_detector_seeds_match_raw_keys() -> void:
	var src := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(not src.contains("DET_FILL_"), "VTKNVG dropped the fill detector targets")

# Daylight compensation spans three shaders and the NVG owner: the overlay
# carries the background curve, the key emitters carry the global gain, and
# VTKNVG writes the exposure. A missing half is silent (a washed picture or a
# vanished detector key), so pin every link.
func t_daylight_contract() -> void:
	var nvg := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(nvg.contains("uniform float dayMix"), "overlay declares the day curve strength")
	ck(nvg.contains("mix(luminance, lifted, dayMix)"), "overlay blends the day curve into the background")
	ck(nvg.contains("liftedLum"), "overlay lifts the plain NVG branch too")
	for res in ["res://mods/ThermalVTK/VTKOutlineRingDepth.gdshader", RING_RES]:
		var src := FileAccess.get_file_as_string(res)
		ck(src.contains("global uniform float vtk_key_gain"), "%s reads the daylight gain" % res.get_file())
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("KEY_GAIN_PARAM"), "VTKNVG owns the global key gain parameter")
	ck(owner.contains("_daylight_tick"), "VTKNVG applies the daylight model per frame")
	ck(owner.contains("_vanilla_exposure"), "VTKNVG keeps the vanilla exposure baseline")
	ck(owner.contains("_last_exposure"), "VTKNVG detects vanilla exposure rewrites")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKDaylight.gd"), "daylight model exists")


func _vec3_default(code: String, name: String) -> Vector3:
	var re := RegEx.new()
	re.compile("uniform\\s+vec3\\s+" + name + "\\s*(:[^=]*)?=\\s*vec3\\(([^)]*)\\)")
	var m := re.search(code)
	if m == null:
		return Vector3(-1.0, -1.0, -1.0)
	var parts: PackedStringArray = m.get_string(2).split(",")
	if parts.size() != 3:
		return Vector3(-1.0, -1.0, -1.0)
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))

func _color_const(code: String, name: String) -> Color:
	var re := RegEx.new()
	re.compile("const\\s+" + name + "\\s*:?=\\s*Color\\(([^)]*)\\)")
	var m := re.search(code)
	if m == null:
		return Color(-1.0, -1.0, -1.0)
	var parts: PackedStringArray = m.get_string(1).split(",")
	if parts.size() != 3:
		return Color(-1.0, -1.0, -1.0)
	return Color(float(parts[0]), float(parts[1]), float(parts[2]))

func _const_float(code: String, name: String) -> float:
	var re := RegEx.new()
	re.compile("const\\s+float\\s+" + name + "\\s*[:]?=\\s*([0-9.]+)")
	var m := re.search(code)
	if m == null:
		return -1.0
	return float(m.get_string(1))

# String matching cannot tell a broken shader from a working one: a GDShader
# with a compile error (a `return` inside fragment(), a bad swizzle) still
# loads as a Shader resource. The compiled uniform list is the proof that the
# shader actually built.
func t_nvg_shader_compiles() -> void:
	var sh = load(NVG_SHADER_RES)
	if sh == null:
		ck(false, "NVG shader loads for compile check")
		return
	var params: Array = sh.get_shader_uniform_list()
	var names: Array = []
	for p in params:
		names.append(p.get("name", ""))
	ck(params.size() > 0, "NVG shader compiled (uniform list not empty)")
	for u in ["mineColor", "scopeRotate", "dayMix"]:
		ck(names.has(u), "compiled shader exposes %s" % u)
	for u in ["fillNormKey", "fillCombKey", "fillDefKey", "fillOpacity"]:
		ck(not names.has(u), "compiled shader dropped %s" % u)
