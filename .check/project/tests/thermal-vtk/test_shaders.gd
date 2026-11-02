extends SceneTree

const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const S = preload("res://mods/ThermalVTK/VTKStates.gd")
const NVG_SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const MASK_RING_RES := "res://mods/ThermalVTK/VTKEspMaskRing.gdshader"
const MASK_FILL_RES := "res://mods/ThermalVTK/VTKEspMaskFill.gdshader"
const MASK_XRAY_RES := "res://mods/ThermalVTK/VTKEspMaskXray.gdshader"

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
	t_mask_shaders_compile()
	t_mask_ring_contract()
	t_mask_fill_contract()
	t_mask_xray_contract()
	t_nvg_mask_branch()
	t_nvg_contour_reads_mines()
	t_palette_four_modes()
	t_nvg_shader_compiles()
	t_no_key_path_left()
	t_states_mask_keys()
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

func t_mask_shaders_compile() -> void:
	var pairs := [
		["ring", Sh.mask_ring(), MASK_RING_RES],
		["fill", Sh.mask_fill(), MASK_FILL_RES],
		["x-ray", Sh.mask_xray(), MASK_XRAY_RES],
	]
	for pair in pairs:
		var sh: Shader = pair[1]
		ck(sh != null and FileAccess.file_exists(pair[2]), "mask %s shader resolves" % pair[0])
		var names := _uniform_names(sh)
		ck(names.has("state_color"), "mask %s shader exposes state_color" % pair[0])
		ck(names.has("grow"), "mask %s shader exposes grow" % pair[0])
		ck(names.has("cool"), "mask %s shader exposes cool" % pair[0])

# The idle ring keeps the depth test: the mask viewport renders the world, so
# walls and the sight glass clip it there. The stencil read is a no-op when no
# body pass wrote 1, which is what lets one shader serve both ring styles.
func t_mask_ring_contract() -> void:
	var src := FileAccess.get_file_as_string(MASK_RING_RES)
	ck(src.contains("stencil_mode read, compare_not_equal, 1"), "ring reads the body stencil")
	ck(not src.contains("depth_test_disabled"), "ring keeps the depth test")
	ck(src.contains("depth_draw_never"), "ring never writes depth")
	ck(src.contains("discard"), "ring drops the tail the overlay cannot read")
	ck(src.contains("uniform float rim_power"), "ring declares rim_power")
	ck(not src.contains("state_key"), "ring has no detector key")
	ck(not src.contains("vtk_key_gain"), "ring has no daylight gain")

func t_mask_fill_contract() -> void:
	var src := FileAccess.get_file_as_string(MASK_FILL_RES)
	ck(src.contains("stencil_mode write, 1"), "fill writes the body stencil")
	ck(src.contains("uniform vec3 state_color"), "fill declares the category colour")
	ck(src.contains("depth_draw_never"), "fill never writes depth")

# A live trigger window punches through walls: the only mask shader without a
# depth test.
func t_mask_xray_contract() -> void:
	var src := FileAccess.get_file_as_string(MASK_XRAY_RES)
	ck(src.contains("depth_test_disabled"), "x-ray mask ring drops the depth test")
	ck(src.contains("depth_draw_never"), "x-ray mask ring never writes depth")
	ck(src.contains("uniform float rim_power"), "x-ray mask ring keeps the rim feel")
	ck(not src.contains("stencil_mode"), "x-ray mask ring ignores the body stencil")

# The overlay reads the category from the mask, not from the frame: the state
# keys are gone and the substitution sits after the palette and the mine key.
func t_nvg_mask_branch() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("uniform sampler2D esp_mask"), "overlay declares the mask sampler")
	ck(code.contains("uniform bool espOn"), "overlay declares the mask switch")
	ck(code.contains("texture(esp_mask, uv)"), "overlay samples the mask")
	ck(code.contains("EspColor(SCREEN_UV)"), "overlay substitutes by screen UV")
	ck(code.contains("float ESP_GATE"), "overlay declares the mask gate")
	for u in ["stNormalColor", "stCombatColor", "stDefendColor"]:
		ck(code.contains(u), "overlay keeps %s" % u)
	for u in ["stNormalKey", "stCombatKey", "stDefendKey"]:
		ck(not code.contains(u), "overlay dropped %s" % u)
	ck(not code.contains("washSpread"), "overlay dropped the key wash guard")
	# PIP-off orbit detection is still needed for the mine key.
	ck(code.contains("scopeRotate"), "overlay declares scopeRotate")
	ck(code.contains("orbitDist"), "overlay declares orbitDist")

func t_nvg_contour_reads_mines() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("vec4(mineColor, pixelColor.a)"), "contour branch substitutes mineColor")

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
	for u in ["mineColor", "scopeRotate", "dayMix", "esp_mask", "espOn", "stNormalColor"]:
		ck(names.has(u), "compiled shader exposes %s" % u)
	for u in ["stNormalKey", "stCombatKey", "stDefendKey"]:
		ck(not names.has(u), "compiled shader dropped %s" % u)
	for u in ["fillNormKey", "fillDefKey", "fillOpacity"]:
		ck(not names.has(u), "compiled shader dropped %s" % u)

# The key path is gone end to end: no detector constants in the owner, no key
# emitters left in the shader store, and the mask module is shipped.
func t_no_key_path_left() -> void:
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(not owner.contains("DET_ST_"), "VTKNVG dropped the state detector constants")
	ck(owner.contains("set_esp_mask"), "VTKNVG owns the mask switch")
	ck(owner.contains("_push_mask"), "VTKNVG binds the mask texture")
	var store := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKShaders.gd")
	ck(store.contains("func mask_ring"), "the store exposes the mask ring")
	ck(store.contains("func mask_fill"), "the store exposes the mask fill")
	ck(store.contains("func mask_xray"), "the store exposes the mask x-ray")
	ck(not store.contains("RING_DEPTH_SRC"), "the store no longer ships the key ring")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKEspMask.gd"), "the mask module exists")

# Pure primaries: the overlay compares the dominant channel against the other
# two, so the three mask keys must never share channels.
func t_states_mask_keys() -> void:
	var keys := [S.mask_key(S.NORMAL), S.mask_key(S.COMBAT), S.mask_key(S.DEFEND)]
	ck(keys[0] == S.MASK_NORMAL and keys[1] == S.MASK_COMBAT and keys[2] == S.MASK_DEFEND, "mask_key maps the categories")
	ck(S.mask_key(99) == S.MASK_NORMAL, "unknown category falls back to normal")
	for k in keys:
		var spread: int = 0
		if k.r > 0.5:
			spread += 1
		if k.g > 0.5:
			spread += 1
		if k.b > 0.5:
			spread += 1
		ck(spread == 1, "mask key %s is a pure primary" % str(k))
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			ck(keys[i] != keys[j], "mask keys %d and %d differ" % [i, j])

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
