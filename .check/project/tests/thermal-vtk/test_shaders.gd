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
	t_palette_ramp()
	t_palette_quad_contract()
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

# Overlay-only baseline: direct display materials are applied as source overlays.
# Outline keeps the stencil/ring chain and display uniforms.
func t_band_contract() -> void:
	var outline := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKOutline.gd")
	ck(outline.contains("material_overlay"), "VTKOutline keeps overlay path")
	ck(outline.contains("outline_color"), "VTKOutline drives direct display color")
	ck(outline.contains("brightness"), "VTKOutline drives direct display brightness")
	ck(outline.contains("fill_alpha"), "VTKOutline drives direct display alpha")
	ck(not outline.contains("func set_buffer_mode"), "VTKOutline has no buffer mode control")
	ck(not outline.contains("SHELL_META"), "VTKOutline has no shell geometry markers")
	ck(not outline.contains("fill_mode"), "VTKOutline has no fill mode flag")
	ck(not outline.contains("\"fill\""), "VTKOutline has no fill opts key")

# NVG overlay palettizes/tints the background (no ESP compositor/buffer path in
# 2.10.x baseline). No screen-space key detection/substitution remains.
func t_nvg_compositor_contract() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(code.contains("uniform sampler2D screen_texture"), "overlay declares the screen sampler")
	ck(code.contains("texture(screen_texture, SCREEN_UV)"), "overlay samples the frame itself")
	ck(not code.contains("uniform sampler2D espTex"), "overlay has no ESP buffer sampler")
	ck(not code.contains("uniform bool espComposite"), "overlay has no ESP composite flag")
	ck(not code.contains("espComposite"), "overlay has no ESP compositing path")
	for bad in ["uniform bool espOn", "stNormalKey", "stCombatKey", "stDefendKey", "mineKey", "stNormalColor", "stCombatColor", "stDefendColor", "mineColor", "stateBright", "scopeRotate", "espFillAlpha", "espBodyFill", "orbitDist", "DET_TOL_CORE", "dCore", "dMine"]:
		ck(not code.contains(bad), "overlay has no substitution token %s" % bad)

func t_palette_ramp() -> void:
	var code := FileAccess.get_file_as_string(NVG_SHADER_RES)
	ck(not code.contains("worldPaletteMode"), "overlay has no palette mode branch")
	for bad in ["red_heat", "held_heat", "redHold", "dayMix", "thermalDarken"]:
		ck(not code.contains(bad), "overlay has no %s" % bad)
	for bad in ["paletteStop0", "paletteOut", "inputGain", "inputKnee", "paletteStrength", "minePassthroughOn"]:
		ck(not code.contains(bad), "canvas shader no longer declares %s" % bad)

func t_palette_quad_contract() -> void:
	var res := "res://mods/ThermalVTK/VTKPalette.gdshader"
	ck(FileAccess.file_exists(res), "palette quad shader exists")
	var src := FileAccess.get_file_as_string(res)
	ck(src.contains("shader_type spatial"), "palette quad is a spatial shader")
	var shader: Shader = load(res)
	ck(shader != null and not shader.get_shader_uniform_list().is_empty(), "palette quad shader compiles")
	ck(src.contains("uniform sampler2D screen_texture : hint_screen_texture"), "quad samples the screen copy")
	ck(src.contains("POSITION = vec4(VERTEX.xy, 1.0, 1.0)"), "quad uses clip-space fullscreen position")
	ck(src.contains("texture(screen_texture, SCREEN_UV)"), "quad samples with SCREEN_UV")
	ck(src.contains("depth_test_disabled") and src.contains("depth_draw_never"), "quad never reads or writes depth")
	for u in ["inputGain", "inputKnee", "paletteOut", "paletteAlpha", "paletteStop0", "paletteStop4"]:
		ck(src.contains(u), "quad declares %s" % u)
	ck(not src.contains("paletteStrength"), "palette mix is fixed, not a live uniform")
	ck(not src.contains("minePassthrough"), "quad has no colour passthrough")
	ck(src.contains("pow(v, 1.0 / 2.2)"), "quad applies display gamma before the ramp")
	ck(src.contains("ALPHA = paletteAlpha"), "each palette pass sets its own alpha")

func t_nvg_shader_compiles() -> void:
	var sh = load(NVG_SHADER_RES)
	if sh == null:
		ck(false, "NVG shader loads for compile check")
		return
	var names := _uniform_names(sh)
	ck(names.size() > 0, "NVG shader compiled (uniform list not empty)")
	for u in ["thermalMode", "nvgWhite", "noise", "tint"]:
		ck(names.has(u), "compiled shader exposes %s" % u)
	for bad in ["espTex", "espComposite", "espOn", "stNormalKey", "stCombatKey", "stDefendKey", "mineKey", "stNormalColor", "stCombatColor", "stDefendColor", "mineColor", "stateBright", "scopeRotate", "espFillAlpha", "espBodyFill"]:
		ck(not names.has(bad), "compiled shader does not expose substitution uniform %s" % bad)

func t_runtime_contract() -> void:
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("func set_mine_color"), "VTKNVG owns mine display colour")
	ck(owner.contains("func mine_color"), "VTKNVG exposes mine display colour")
	for bad in ["set_esp_layer", "set_esp_demand", "func esp_buffer_layer", "func esp_composite_active", "func esp_buffer_viewport", "espTex", "espComposite", "MINE_KEY", "DET_ST_NORMAL", "DET_ST_COMBAT", "DET_ST_DEFEND", "DET_MINE", "set_esp_fill", "set_state_colors", "set_esp_brightness", "set_esp_on", "vtk_key_gain"]:
		ck(not owner.contains(bad), "VTKNVG has no compositor/substitution token %s" % bad)
	var store := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKShaders.gd")
	ck(store.contains("func body_los"), "shader store exposes body_los")
	ck(store.contains("func body_xray"), "shader store exposes body_xray")
	ck(store.contains("func ring_los"), "shader store exposes ring_los")
	ck(store.contains("func ring_xray"), "shader store exposes ring_xray")
	for bad in ["body_los_key", "body_xray_key", "ring_los_key", "ring_xray_key", "Key.gdshader", "_key_cache"]:
		ck(not store.contains(bad), "shader store has no key-variant token %s" % bad)

func t_daylight_contract() -> void:
	var quad := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKPalette.gdshader")
	ck(quad.contains("uniform float inputGain"), "palette quad declares the input gain")
	ck(not quad.contains("dayMix"), "quad has no day curve uniform")
	var owner := FileAccess.get_file_as_string("res://mods/ThermalVTK/VTKNVG.gd")
	ck(owner.contains("_daylight_tick"), "VTKNVG applies the daylight model per frame")
	ck(FileAccess.file_exists("res://mods/ThermalVTK/VTKDaylight.gd"), "daylight model exists")
