extends SceneTree

const Sh = preload("res://mods/ThermalVTK/VTKShaders.gd")
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
	t_nvg_compositor_contract()
	t_palette_modes()
	t_nvg_shader_compiles()
	t_runtime_contract()
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
		ck(names.has("outline_color"), "esp %s shader exposes outline_color" % pair[0])
		ck(names.has("brightness"), "esp %s shader exposes brightness" % pair[0])
		ck(names.has("alpha"), "esp %s shader exposes alpha" % pair[0])
		ck(names.has("grow"), "esp %s shader exposes grow" % pair[0])
		ck(names.has("cool"), "esp %s shader exposes cool" % pair[0])
	for body in [Sh.body_los(), Sh.body_xray()]:
		ck(_uniform_names(body).has("rim_power"), "body shader exposes rim falloff")
	for ring in [Sh.ring_los(), Sh.ring_xray()]:
		ck(_uniform_names(ring).has("rim_power"), "ring shader exposes rim_power")

func t_body_contracts() -> void:
	var los := FileAccess.get_file_as_string(BODY_LOS_RES)
	var xray := FileAccess.get_file_as_string(BODY_XRAY_RES)
	for src in [los, xray]:
		ck(not src.contains("stencil_mode"), "body shader leaves the stencil buffer untouched")
		ck(src.contains("depth_draw_never"), "body shader never writes depth")
		ck(src.contains("outline_color * brightness"), "body shader emits display color")
		ck(src.contains("pow(edge, rim_power)"), "body shader supports rim falloff")
		ck(src.contains("ALPHA = (0.3 + 0.7 * rim) * alpha * (1.0 - cool)"), "body shader applies a floored rim fill")
	ck(not los.contains("depth_test_disabled"), "los body keeps depth test")
	ck(xray.contains("depth_test_disabled"), "xray body disables depth test")

func t_ring_contracts() -> void:
	var los := FileAccess.get_file_as_string(RING_LOS_RES)
	var xray := FileAccess.get_file_as_string(RING_XRAY_RES)
	for src in [los, xray]:
		ck(not src.contains("stencil_mode"), "ring shader leaves the stencil buffer untouched")
		ck(src.contains("depth_draw_never"), "ring shader never writes depth")
		ck(src.contains("outline_color * brightness"), "ring shader emits display color")
		ck(src.contains("rim_power"), "ring shader supports rim falloff")
		ck(src.contains("ALPHA = rim * alpha * (1.0 - cool)"), "ring shader applies rim, alpha and cool")
	ck(not los.contains("depth_test_disabled"), "los ring keeps depth test")
	ck(xray.contains("depth_test_disabled"), "xray ring disables depth test")

# Direct overlay stays the default, but the contour chain can also be routed
# through ESP-buffer shells without changing its shaders or display uniforms.
func t_band_contract() -> void:
	var outline := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKOutline.gd")
	ck(outline.contains("material_overlay"), "VTKOutline keeps overlay path")
	ck(outline.contains("outline_color"), "VTKOutline drives direct display color")
	ck(outline.contains("brightness"), "VTKOutline drives direct display brightness")
	ck(outline.contains("fill_alpha"), "VTKOutline drives direct display alpha")
	ck(outline.contains("func set_buffer_mode"), "VTKOutline exposes buffer mode control")
	ck(outline.contains("func buffer_mode"), "VTKOutline reports buffer mode state")
	ck(outline.contains("VTKESPBuffer"), "VTKOutline routes contours through the ESP buffer")

# NVG overlay palettizes/tints the background, then composites the ESP buffer
# over it with its own display colours. No screen-space key substitution remains.
func t_nvg_compositor_contract() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("uniform sampler2D screen_texture"), "overlay declares the screen sampler")
	ck(code.contains("texture(screen_texture, SCREEN_UV)"), "overlay samples the frame itself")
	ck(code.contains("uniform sampler2D espTex"), "overlay declares ESP buffer sampler")
	ck(code.contains("uniform bool espComposite"), "overlay declares ESP composite flag")
	ck(code.contains("texture(espTex, SCREEN_UV)"), "overlay samples ESP buffer")
	var palette_at := code.find("mix(pixelColor.rgb, backgroundColor, clamp(paletteStrength")
	var esp_at := code.find("if (espComposite)")
	var mask_at := code.find("COLOR = mix(vec4(0.0, 0.0, 0.0, 1.0), color, goggleMask)")
	ck(palette_at >= 0 and esp_at > palette_at and mask_at > esp_at, "ESP composite runs after palette and before the goggle mask")
	for bad in ["uniform bool espOn", "stNormalKey", "stCombatKey", "stDefendKey", "mineKey", "stNormalColor", "stCombatColor", "stDefendColor", "mineColor", "stateBright", "scopeRotate", "espFillAlpha", "espBodyFill", "orbitDist", "DET_TOL_CORE", "dCore", "dMine"]:
		ck(not code.contains(bad), "overlay has no substitution token %s" % bad)

func t_palette_modes() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	var n := 0
	for i in [1, 2, 3]:
		if code.contains("worldPaletteMode == %d" % i):
			n += 1
	ck(n == 3, "palette modes 1..3 are present (got %d)" % n)
	for i in [4, 5, 6]:
		ck(not code.contains("worldPaletteMode == %d" % i), "palette mode %d removed" % i)
	ck(code.contains("amber_palette"), "amber palette function present")
	ck(code.contains("forest_palette"), "forest palette function present")
	ck(code.contains("red_palette"), "red/classic palette function present")
	ck(code.contains("day_palette"), "blue/ice palette function present")
	ck(not code.contains("vrcets_night_palette"), "unused night/auto palette removed")
	ck(not code.contains("vrcets"), "shader has no vrcets identifiers")
	ck(not code.contains("worldPaletteMode >= 4"), "palette path no longer gated to modes >= 4")

func t_nvg_shader_compiles() -> void:
	var sh = load(NVG_SHADER_RES)
	if sh == null:
		ck(false, "NVG shader loads for compile check")
		return
	var names := _uniform_names(sh)
	ck(names.size() > 0, "NVG shader compiled (uniform list not empty)")
	for u in ["dayMix", "thermalMode", "thermalDarken", "worldPaletteMode", "highlightKnee", "nvgWhite", "paletteStrength", "redHold", "noise", "tint", "espTex", "espComposite"]:
		ck(names.has(u), "compiled shader exposes %s" % u)
	for bad in ["espOn", "stNormalKey", "stCombatKey", "stDefendKey", "mineKey", "stNormalColor", "stCombatColor", "stDefendColor", "mineColor", "stateBright", "scopeRotate", "espFillAlpha", "espBodyFill"]:
		ck(not names.has(bad), "compiled shader does not expose substitution uniform %s" % bad)

func t_runtime_contract() -> void:
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("func set_mine_color"), "VTKNVG owns mine display colour")
	ck(owner.contains("func mine_color"), "VTKNVG exposes mine display colour")
	for api in ["set_esp_demand", "esp_composite_active", "esp_buffer_viewport", "painted_mine_count", "LAYER_BIT"]:
		ck(owner.contains(api), "VTKNVG exposes %s" % api)
	for bad in ["set_esp_layer", "func esp_buffer_layer", "MINE_KEY", "DET_ST_NORMAL", "DET_ST_COMBAT", "DET_ST_DEFEND", "DET_MINE", "set_esp_fill", "set_state_colors", "set_esp_brightness", "set_esp_on", "vtk_key_gain"]:
		ck(not owner.contains(bad), "VTKNVG has no substitution token %s" % bad)
	var coordinator := FileAccess.get_file_as_string("res://mods/ThermalVTK/ThermalVTK.gd")
	var sync_at := coordinator.find("func _sync_nvg_esp")
	var demand_at := coordinator.find("_nvg.set_esp_demand(", sync_at)
	ck(sync_at >= 0 and demand_at > sync_at, "coordinator pushes contour demand from _sync_nvg_esp")
	var store := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKShaders.gd")
	ck(store.contains("func body_los"), "shader store exposes body_los")
	ck(store.contains("func body_xray"), "shader store exposes body_xray")
	ck(store.contains("func ring_los"), "shader store exposes ring_los")
	ck(store.contains("func ring_xray"), "shader store exposes ring_xray")
	for bad in ["body_los_key", "body_xray_key", "ring_los_key", "ring_xray_key", "Key.gdshader", "_key_cache"]:
		ck(not store.contains(bad), "shader store has no key-variant token %s" % bad)

func t_daylight_contract() -> void:
	var nvg := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(nvg.contains("uniform float dayMix"), "overlay declares the day curve strength")
	ck(nvg.contains("mix(luminance, lifted, dayMix)"), "overlay blends the day curve into the background")
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("_daylight_tick"), "VTKNVG applies the daylight model per frame")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKDaylight.gd"), "daylight model exists")
