extends SceneTree

const OPTIC = preload("res://mods/ThermalVTK/VTKOPTIC.gd")
const States = preload("res://mods/ThermalVTK/VTKStates.gd")

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
	t_linear_roundtrip()
	t_forward_matches_vanilla_pip()
	t_default_hues_survive_compensation()
	t_inverse_scales_instead_of_clamping()
	t_affine_blend_linear()
	print("")
	if fails == 0:
		print("Optic tests passed")
		quit(0)
	else:
		print("Optic tests failed: ", fails)
		quit(1)

# The PIP pass works in linear space: an inverse built on authored sRGB values
# would leave every configured state colour dimmed or shifted in the lens.
func t_linear_roundtrip() -> void:
	for c in [Color(0.7, 0.6, 0.1), Color(0.6, 0.15, 0.12),
			Color(0.0, 0.15, 0.7), Color(0.55, 0.0, 0.7)]:
		var back := OPTIC.forward(OPTIC.inverse(c))
		ck(absf(back.r - c.r) < 0.01 and absf(back.g - c.g) < 0.01
			and absf(back.b - c.b) < 0.01, "linear forward(inverse(c)) restores c")

# Hand-derived from the vanilla shader: x*0.8, then (x-0.5)*0.99+0.5.
# These literals pin the numbers if the game's PIP pass ever changes.
func t_forward_matches_vanilla_pip() -> void:
	var got := OPTIC.forward(Color(0.5, 0.25, 1.0))
	ck(absf(got.r - 0.401) < 0.001, "vanilla gain and contrast on red")
	ck(absf(got.g - 0.203) < 0.001, "vanilla gain and contrast on green")
	ck(absf(got.b - 0.797) < 0.001, "vanilla gain and contrast on full blue")

func t_default_hues_survive_compensation() -> void:
	for src in [States.DEFAULT_NORMAL, States.DEFAULT_COMBAT, States.DEFAULT_DEFEND]:
		var target: Color = src.srgb_to_linear()
		var got: Color = OPTIC.forward(OPTIC.compensate(src).srgb_to_linear())
		var want_hi: float = maxf(target.r, maxf(target.g, target.b))
		var got_hi: float = maxf(got.r, maxf(got.g, got.b))
		ck(absf(got.r / got_hi - target.r / want_hi) < 0.02
			and absf(got.g / got_hi - target.g / want_hi) < 0.02
			and absf(got.b / got_hi - target.b / want_hi) < 0.02,
			"compensated default keeps channel ratios")
	ck(OPTIC.compensate(States.DEFAULT_NORMAL).r > OPTIC.compensate(States.DEFAULT_NORMAL).g,
		"amber normal does not collapse to pure yellow")

func t_inverse_scales_instead_of_clamping() -> void:
	var got := OPTIC.inverse(Color(1.0, 0.814, 0.0))
	ck(got.r <= 1.0 and got.g <= 1.0, "inverse fits channels into range")
	ck(absf(got.r - 1.0) < 0.001 and got.g < 1.0 and got.g > 0.7,
		"the second channel keeps its share instead of clamping to 1")

# The PIP transform is affine, so compensating the contour colour must survive
# alpha blending over the lens background at any opacity.
func t_affine_blend_linear() -> void:
	var bg := Color(0.1, 0.2, 0.3)
	var want := Color(0.6, 0.15, 0.12)
	var a := 0.2
	var src := OPTIC.inverse(want)
	var mixed := OPTIC.forward(bg * (1.0 - a) + src * a)
	var expected := OPTIC.forward(bg) * (1.0 - a) + want * a
	ck(absf(mixed.r - expected.r) < 0.01 and absf(mixed.g - expected.g) < 0.01
		and absf(mixed.b - expected.b) < 0.01, "compensation survives alpha blending")
