extends SceneTree

const OPTIC = preload("res://mods/ThermalVTK/VTKOPTIC.gd")

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
	t_pip_roundtrip()
	t_forward_matches_vanilla_pip()
	t_inverse_clamps()
	t_full_intensity_clamps_to_lens_maximum()
	t_affine_blend()
	print("")
	if fails == 0:
		print("Optic tests passed")
		quit(0)
	else:
		print("Optic tests failed: ", fails)
		quit(1)

# A wrong inverse would leave every configured state colour dimmed or shifted
# once the vanilla PIP shader runs over the lens texture. Colours stay inside
# the lens ceiling: T(1.0) = 0.797, so full-intensity channels are covered by
# the clamp test below instead.
func t_pip_roundtrip() -> void:
	for c in [Color(0.7, 0.6, 0.1), Color(0.6, 0.15, 0.12),
			Color(0.0, 0.15, 0.7), Color(0.55, 0.0, 0.7)]:
		var back := OPTIC.forward(OPTIC.inverse(c))
		ck(absf(back.r - c.r) < 0.01 and absf(back.g - c.g) < 0.01 and absf(back.b - c.b) < 0.01,
			"forward(inverse(c)) restores the configured colour")

# Hand-derived from the vanilla shader: x*0.8, then (x-0.5)*0.99+0.5.
# These literals pin the numbers if the game's PIP pass ever changes.
func t_forward_matches_vanilla_pip() -> void:
	var got := OPTIC.forward(Color(0.5, 0.25, 1.0))
	ck(absf(got.r - 0.401) < 0.001, "vanilla gain and contrast on red")
	ck(absf(got.g - 0.203) < 0.001, "vanilla gain and contrast on green")
	ck(absf(got.b - 0.797) < 0.001, "vanilla gain and contrast on full blue")

func t_inverse_clamps() -> void:
	var hi := OPTIC.inverse(Color(2.0, 2.0, 2.0))
	var lo := OPTIC.inverse(Color(-1.0, -1.0, -1.0))
	ck(hi.r <= 1.0 and hi.g <= 1.0 and hi.b <= 1.0, "inverse clamps at the top")
	ck(lo.r >= 0.0 and lo.g >= 0.0 and lo.b >= 0.0, "inverse clamps at the bottom")

# The PIP transform is affine, so compensating the contour colour must survive
# alpha blending over the lens background at any opacity.
# The lens cannot return a channel above T(1.0); the inverse must stay finite
# and land exactly on that ceiling instead of overshooting into a different hue.
func t_full_intensity_clamps_to_lens_maximum() -> void:
	var got := OPTIC.forward(OPTIC.inverse(Color(1.0, 1.0, 1.0)))
	ck(absf(got.r - 0.797) < 0.001 and absf(got.g - 0.797) < 0.001 and absf(got.b - 0.797) < 0.001,
		"a full-intensity channel lands on the PIP lens ceiling")

func t_affine_blend() -> void:
	var bg := Color(0.1, 0.2, 0.3)
	var want := Color(0.6, 0.15, 0.12)
	var a := 0.2
	var src := OPTIC.inverse(want)
	var mixed := OPTIC.forward(bg * (1.0 - a) + src * a)
	var expected := OPTIC.forward(bg) * (1.0 - a) + want * a
	ck(absf(mixed.r - expected.r) < 0.01 and absf(mixed.g - expected.g) < 0.01
		and absf(mixed.b - expected.b) < 0.01, "compensated colour survives alpha blending")
