extends SceneTree

const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
const S = preload("res://mods/ThermalVTK/VTKStates.gd")
const NVG = preload("res://mods/ThermalVTK/VTKNVG.gd")
const NVG_SHADER_RES := "res://mods/ThermalVTK/VTKNVG.gdshader"
const BODY_LOS_RES := "res://mods/ThermalVTK/VTKEspBody.gdshader"
const BODY_XRAY_RES := "res://mods/ThermalVTK/VTKEspBodyXray.gdshader"
const RING_LOS_RES := "res://mods/ThermalVTK/VTKEspRing.gdshader"
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
	t_esp_shaders_compile()
	t_body_contracts()
	t_ring_contracts()
	t_band_contract()
	t_nvg_esp_detection_branch()
	t_palette_modes()
	t_nvg_shader_compiles()
	t_key_path_present()
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

func t_esp_shaders_compile() -> void:
	var pairs := [
		["body_los", Sh.body_los(), BODY_LOS_RES],
		["body_xray", Sh.body_xray(), BODY_XRAY_RES],
		["ring_los", Sh.ring_los(), RING_LOS_RES],
		["ring_xray", Sh.ring_xray(), RING_XRAY_RES],
	]
	for pair in pairs:
		var sh: Shader = pair[1]
		ck(sh != null and FileAccess.file_exists(pair[2]), "esp %s shader resolves" % pair[0])
		var names := _uniform_names(sh)
		ck(names.has("key_color"), "esp %s shader exposes key_color" % pair[0])
		ck(names.has("grow"), "esp %s shader exposes grow" % pair[0])
		ck(not names.has("density"), "esp %s shader has no dither density" % pair[0])
	for body in [Sh.body_los(), Sh.body_xray()]:
		ck(_uniform_names(body).has("alpha"), "body shader keeps the mask/fill alpha switch")
		ck(not _uniform_names(body).has("cool"), "the corpse fade belongs to the ring")
	for ring in [Sh.ring_los(), Sh.ring_xray()]:
		ck(_uniform_names(ring).has("cool"), "ring shader carries the corpse fade")
		ck(not _uniform_names(ring).has("alpha"), "ring shader has no alpha to blend the key with")
		ck(not _uniform_names(ring).has("rim_power"), "ring shader has no rim falloff")

func t_body_contracts() -> void:
	var los := FileAccess.get_file_as_string(BODY_LOS_RES)
	var xray := FileAccess.get_file_as_string(BODY_XRAY_RES)
	for src in [los, xray]:
		ck(src.contains("stencil_mode write, 1"), "body shader writes stencil")
		ck(src.contains("depth_draw_never"), "body shader never writes depth")
		ck(src.contains("global uniform float vtk_key_gain"), "body shader scales detection key")
		ck(src.contains("key_color * vtk_key_gain"), "body shader emits detection key")
		ck(not src.contains("screen_dither"), "the fill is solid, not dithered")
		ck(not src.contains("discard"), "the fill never drops pixels")
		ck(src.contains("ALPHA = 1.0"), "body key reaches the framebuffer opaque")
		ck(not src.contains("ALPHA = alpha"), "body never blends the key by alpha")
		ck(not src.contains("ALPHA = rim"), "body never blends the key by a falloff")
	ck(not los.contains("depth_test_disabled"), "los body keeps depth test")
	ck(xray.contains("depth_test_disabled"), "xray body disables depth test")

func t_ring_contracts() -> void:
	var los := FileAccess.get_file_as_string(RING_LOS_RES)
	var xray := FileAccess.get_file_as_string(RING_XRAY_RES)
	for src in [los, xray]:
		ck(src.contains("stencil_mode read, compare_not_equal, 1"), "ring shader reads stencil")
		ck(src.contains("depth_draw_never"), "ring shader never writes depth")
		ck(not src.contains("uniform float rim_power"), "ring shader dropped the rim falloff")
		ck(not src.contains("RING_FLOOR"), "the band no longer needs a dithered floor")
		ck(not src.contains("uniform float density"), "the band is solid, not a dither density")
		ck(src.contains("global uniform float vtk_key_gain"), "ring shader scales detection key")
		ck(src.contains("key_color * vtk_key_gain"), "ring shader emits detection key")
		ck(src.contains("screen_dither"), "only the corpse fade dithers")
		ck(src.contains("ALPHA = 1.0"), "ring key reaches the framebuffer opaque")
		ck(not src.contains("ALPHA = rim"), "rim falloff never becomes alpha")
	ck(not los.contains("depth_test_disabled"), "los ring keeps depth test")
	ck(xray.contains("depth_test_disabled"), "xray ring disables depth test")

# The band is only real if the ring inflates further than the mask. The mask
# clears the depth buffer by at least a screen-sized step (a coincident mask
# loses the depth test at range and the ring floods the body), and the ring adds
# the band on top of that offset.
func t_band_contract() -> void:
	var esp := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKESP.gd")
	ck(esp.contains("OUTLINE_BAND_PX"), "VTKESP sizes the band in screen pixels")
	ck(esp.contains("func _band_for"), "VTKESP converts distance into a world band width")
	ck(esp.contains("opts[\"band\"]"), "the contour opts carry the band")
	var outline := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKOutline.gd")
	ck(outline.contains("body_grow + band"), "the ring inflates by the mask offset plus band")
	ck(outline.contains("maxf(grow, band)"), "the mask clears the depth step by at least the band")
	ck(outline.contains("set_shader_parameter(\"grow\", body_grow)"), "the mask carries that offset")
	ck(not outline.contains("set_shader_parameter(\"grow\", 0.0)"), "the mask is never coincident with the mesh")
	ck(not outline.contains("set_shader_parameter(\"density\""), "fill strength is no longer a dither density")
	ck(not outline.contains("set_shader_parameter(\"rim_power\""), "the ring no longer takes a rim falloff")

func t_nvg_esp_detection_branch() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("uniform sampler2D screen_texture"), "overlay declares the screen sampler")
	ck(code.contains("texture(screen_texture, SCREEN_UV)"), "overlay samples the frame itself")
	ck(code.contains("uniform sampler2D espTex"), "overlay declares ESP buffer sampler")
	ck(code.contains("uniform bool espComposite"), "overlay declares ESP composite flag")
	ck(code.contains("texture(espTex, SCREEN_UV)"), "overlay samples ESP buffer")
	ck(code.contains("espComposite"), "overlay composites ESP buffer when enabled")
	ck(code.contains("uniform bool espOn"), "overlay declares espOn")
	# Fill opacity is a 3D dither now: substituted pixels must be the flat chosen
	# colour, never a mix with a reconstructed thermal background. That mix is
	# what turned the fill muddy.
	ck(not code.contains("uniform bool espFill"), "the overlay has no espFill blend switch")
	ck(not code.contains("uniform float fillAlpha"), "the overlay has no fill alpha to dilute the hue")
	ck(not code.contains("mix(backgroundColor, flatCol"), "substituted pixels keep the flat chosen colour")
	for u in ["stNormalKey", "stCombatKey", "stDefendKey", "stNormalColor", "stCombatColor", "stDefendColor", "mineKey", "mineColor", "stateBright", "scopeRotate"]:
		ck(code.contains("uniform") and code.contains(u), "overlay declares %s" % u)
	ck(code.contains("orbitDist"), "overlay declares orbitDist")
	ck(code.contains("DET_TOL_CORE"), "overlay uses detection tolerance")
	ck(code.contains("dCore"), "overlay computes nearest key distance")
	ck(code.contains("dMine"), "overlay detects mine key")

func t_palette_modes() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	var n := 0
	for i in [1, 2, 3, 4, 5]:
		if code.contains("worldPaletteMode == %d" % i):
			n += 1
	ck(n == 3, "only modes 1..3 remain (got %d)" % n)

func t_nvg_shader_compiles() -> void:
	var sh = load(NVG_SHADER_RES)
	if sh == null:
		ck(false, "NVG shader loads for compile check")
		return
	var names := _uniform_names(sh)
	ck(names.size() > 0, "NVG shader compiled (uniform list not empty)")
	for u in ["mineColor", "scopeRotate", "dayMix", "espOn", "espTex", "espComposite", "stNormalColor", "stNormalKey", "stCombatKey", "stDefendKey", "mineKey", "stateBright"]:
		ck(names.has(u), "compiled shader exposes %s" % u)

func t_key_path_present() -> void:
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("MINE_KEY"), "VTKNVG still emits the raw mine key")
	ck(owner.contains("DET_ST_NORMAL"), "VTKNVG carries measured state keys")
	ck(owner.contains("set_esp_layer"), "VTKNVG owns contour layer switch")
	ck(owner.contains("set_esp_demand"), "VTKNVG owns ESP demand gate")
	ck(owner.contains("func set_esp_fill"), "VTKNVG owns ESP fill plumbing (preserved)")
	ck(owner.contains("func esp_buffer_layer"), "VTKNVG exposes ESP buffer layer")
	ck(owner.contains("func esp_composite_active"), "VTKNVG exposes ESP composite state")
	ck(owner.contains("set_state_colors"), "VTKNVG owns state-colour plumbing")
	ck(owner.contains("func set_mine_color"), "VTKNVG owns mine display colour")
	var store := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKShaders.gd")
	ck(store.contains("func body_los"), "shader store exposes body_los")
	ck(store.contains("func body_xray"), "shader store exposes body_xray")
	ck(store.contains("func ring_los"), "shader store exposes ring_los")
	ck(store.contains("func ring_xray"), "shader store exposes ring_xray")

func t_states_state_keys() -> void:
	var keys := [S.state_key(S.NORMAL), S.state_key(S.COMBAT), S.state_key(S.DEFEND)]
	ck(keys[0] == S.KEY_NORMAL and keys[1] == S.KEY_COMBAT and keys[2] == S.KEY_DEFEND, "state_key maps the categories")
	ck(S.state_key(99) == S.KEY_NORMAL, "unknown category falls back to normal")
	for k in keys:
		ck(k.r + k.g + k.b > 0.5, "key %s is bright enough to reach the screen" % str(k))
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			ck(keys[i] != keys[j], "state keys %d and %d differ" % [i, j])

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

func t_daylight_contract() -> void:
	var nvg := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(nvg.contains("uniform float dayMix"), "overlay declares the day curve strength")
	ck(nvg.contains("mix(luminance, lifted, dayMix)"), "overlay blends the day curve into the background")
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("_daylight_tick"), "VTKNVG applies the daylight model per frame")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKDaylight.gd"), "daylight model exists")
