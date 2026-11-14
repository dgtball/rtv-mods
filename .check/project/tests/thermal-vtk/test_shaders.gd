extends SceneTree

const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const S = preload("res://mods/ThermalVTK/VTKStates.gd")
const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
const NVG_SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const BODY_RES := "res://mods/ThermalVTK/VTKEspBody.gdshader"
const BODY_XRAY_RES := "res://mods/ThermalVTK/VTKEspBodyXray.gdshader"
const RING_RES := "res://mods/ThermalVTK/VTKEspRing.gdshader"
const RING_XRAY_RES := "res://mods/ThermalVTK/VTKEspRingXray.gdshader"

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
	t_direct_shaders_compile()
	t_direct_stencil_and_depth_contract()
	t_nvg_esp_branch()
	t_nvg_contour_reads_mines()
	t_palette_four_modes()
	t_nvg_shader_compiles()
	t_no_key_path_left()
	t_states_state_keys()
	t_detector_keys_are_spaced()
	t_daylight_contract()
	print("")
	if fails == 0:
		print("Shaders tests passed")
		quit(0)
	else:
		print("Shaders tests failed: ", fails)
		quit(1)

func _uniform_names(sh: Shader) -> Array:
	var names: Array = []
	if sh == null:
		return names
	for p in sh.get_shader_uniform_list():
		names.append(p.get("name", ""))
	return names

func t_direct_shaders_compile() -> void:
	var pairs := [["body", Sh.body_los(), BODY_RES], ["body_xray", Sh.body_xray(), BODY_XRAY_RES], ["ring", Sh.ring_los(), RING_RES], ["ring_xray", Sh.ring_xray(), RING_XRAY_RES]]
	for pair in pairs:
		ck(pair[1] != null and FileAccess.file_exists(pair[2]), "direct %s shader resolves" % pair[0])
		var names := _uniform_names(pair[1])
		for u in ["outline_color", "brightness", "alpha", "grow", "cool"]:
			ck(names.has(u), "direct %s shader exposes %s" % [pair[0], u])

func t_direct_stencil_and_depth_contract() -> void:
	var body := FileAccess.get_file_as_string(BODY_RES)
	var ring := FileAccess.get_file_as_string(RING_RES)
	var bx := FileAccess.get_file_as_string(BODY_XRAY_RES)
	var rx := FileAccess.get_file_as_string(RING_XRAY_RES)
	ck(body.contains("stencil_mode write, 1"), "body writes stencil")
	ck(ring.contains("stencil_mode read, compare_not_equal, 1"), "ring reads stencil")
	ck(not body.contains("depth_test_disabled") and not ring.contains("depth_test_disabled"), "LOS shaders keep depth test")
	ck(bx.contains("depth_test_disabled") and rx.contains("depth_test_disabled"), "XRAY shaders disable depth test")
	ck(ring.contains("uniform float rim_power") and rx.contains("uniform float rim_power"), "ring shaders expose rim_power")
	ck(not body.contains("state_color") and not ring.contains("state_color"), "direct shaders do not use key state_color")
	ck(not body.contains("vtk_key_gain") and not ring.contains("vtk_key_gain"), "direct shaders do not depend on vtk_key_gain")

# The overlay reads the category from the frame the shell wrote into: the shell
# emits a key into the main 3D pass and the overlay matches the WASHED pixel
# against the measured key values, then replaces the pixel with the display
# colour. The old channel-gap classifier and its edge dials are gone.
func t_nvg_esp_branch() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("uniform sampler2D screen_texture"), "overlay declares the screen sampler")
	ck(code.contains("uniform bool espOn"), "overlay declares the contour switch")
	ck(code.contains("texture(screen_texture, SCREEN_UV)"), "overlay samples the frame itself")
	ck(not code.contains("EspColor"), "the gap classifier is gone")
	ck(not code.contains("EspGap"), "the gap classifier is gone")
	ck(not code.contains("uniform float espGate"), "the gap gate dial is gone")
	ck(not code.contains("uniform float espFull"), "the opaque-gap dial is gone")
	ck(not code.contains("esp_mask"), "the mask sampler is gone")
	for u in ["stNormalColor", "stCombatColor", "stDefendColor"]:
		ck(code.contains("uniform vec3 %s" % u), "overlay keeps %s" % u)
	for u in ["stNormalKey", "stCombatKey", "stDefendKey"]:
		ck(code.contains("uniform vec3 %s" % u), "overlay matches the washed %s" % u)
	ck(code.contains("washSpread"), "overlay keeps the combat wash guard")
	# PIP-off orbit detection is still needed for the mine key.
	ck(code.contains("scopeRotate"), "overlay declares scopeRotate")
	ck(code.contains("orbitDist"), "overlay declares orbitDist")

func t_nvg_contour_reads_mines() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("vec4(mineColor, pixelColor.a)"), "contour branch substitutes mineColor")
	ck(code.contains("dCore == dMine"), "the mine key takes part in the nearest-key match")
	# The state keys are only on screen while a contour is armed; the mine key
	# is not gated by that (a mine is a mine between shells).
	ck(code.contains("if (!espOn) {"), "the contour switch gates the state keys")

func t_palette_four_modes() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	var n := 0
	for i in [1, 2, 3, 4, 5]:
		if code.contains("worldPaletteMode == %d" % i):
			n += 1
	ck(n == 3, "only modes 1..3 remain (got %d)" % n)
	ck(not code.contains("Black Hot"), "no Black Hot branch")

# A shader with a compile error still loads as a resource; the compiled uniform
# list is the proof that set_shader_parameter() is not a silent no-op.
func t_nvg_shader_compiles() -> void:
	var sh = load(NVG_SHADER_RES)
	if sh == null:
		ck(false, "NVG shader loads for compile check")
		return
	var names := _uniform_names(sh)
	ck(names.size() > 0, "NVG shader compiled (uniform list not empty)")
	# `screen_texture` is a built-in hinted sampler and never appears in the
	# uniform list; t_nvg_esp_branch checks it in the source instead.
	for u in ["mineColor", "scopeRotate", "dayMix", "espOn", "stNormalColor", "stNormalKey", "stCombatKey", "stDefendKey"]:
		ck(names.has(u), "compiled shader exposes %s" % u)
	for u in ["espGate", "espFull", "EspGap", "EspColor"]:
		ck(not names.has(u), "compiled shader dropped %s" % u)
	for u in ["fillNormKey", "fillDefKey", "fillOpacity"]:
		ck(not names.has(u), "compiled shader dropped %s" % u)

# The key path is back end to end: the ring/fill shell emits the raw category
# key, VTKNVG owns the measured washed targets, and the second-pass module stays
# deleted.
func t_no_key_path_left() -> void:
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("DET_ST_NORMAL"), "VTKNVG carries the measured state keys")
	ck(owner.contains("MINE_KEY"), "VTKNVG still emits the raw mine key")
	ck(owner.contains("set_esp_layer"), "VTKNVG owns the contour layer switch")
	ck(owner.contains("_push_esp_on"), "VTKNVG pushes the contour uniform")
	ck(owner.contains("func set_mine_color"), "VTKNVG owns the mine display colour")
	var store := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKShaders.gd")
	ck(store.contains("func body_los"), "the store exposes the body LOS shader")
	ck(store.contains("func body_xray"), "the store exposes the body XRAY shader")
	ck(store.contains("func ring_los"), "the store exposes the ring LOS shader")
	ck(store.contains("func ring_xray"), "the store exposes the ring XRAY shader")
	ck(not store.contains("RING_DEPTH_SRC"), "the store no longer ships the key ring")
	ck(not FileAccess.file_exists("res://mods/ThermalVTK/VTKEspMask.gd"), "the second-pass module is deleted")

# The detector matches the closest washed key, so every pair of targets has to
# be farther apart than the detector radius: otherwise one key's shell would be
# painted in another key's colour.
func t_detector_keys_are_spaced() -> void:
	var keys := {
		"mine": NVG.DET_MINE,
		"normal": NVG.DET_ST_NORMAL,
		"combat": NVG.DET_ST_COMBAT,
		"defend": NVG.DET_ST_DEFEND,
	}
	var names: Array = keys.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Color = keys[names[i]]
			var b: Color = keys[names[j]]
			var d: float = Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			ck(d > 0.34, "washed %s and %s keys are farther than the detector radius (%.2f)" % [names[i], names[j], d])

# The raw keys are what the shell emits; they only have to be distinct and
# bright. Two-channel keys are fine -- the wash turns them into the measured
# DET_ST_* targets above.
func t_states_state_keys() -> void:
	var keys := [S.state_key(S.NORMAL), S.state_key(S.COMBAT), S.state_key(S.DEFEND)]
	ck(keys[0] == S.KEY_NORMAL and keys[1] == S.KEY_COMBAT and keys[2] == S.KEY_DEFEND, "state_key maps the categories")
	ck(S.state_key(99) == S.KEY_NORMAL, "unknown category falls back to normal")
	for k in keys:
		ck(k.r + k.g + k.b > 0.5, "key %s is bright enough to reach the screen" % str(k))
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			ck(keys[i] != keys[j], "state keys %d and %d differ" % [i, j])

func t_daylight_contract() -> void:
	var nvg := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(nvg.contains("uniform float dayMix"), "overlay declares the day curve strength")
	ck(nvg.contains("mix(luminance, lifted, dayMix)"), "overlay blends the day curve into the background")
	ck(nvg.contains("liftedLum"), "overlay lifts the plain NVG branch too")
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("_daylight_tick"), "VTKNVG applies the daylight model per frame")
	ck(owner.contains("_vanilla_exposure"), "VTKNVG keeps the vanilla exposure baseline")
	ck(owner.contains("_last_exposure"), "VTKNVG detects vanilla exposure rewrites")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKDaylight.gd"), "daylight model exists")
