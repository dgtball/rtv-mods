extends RefCounted
# Frame statistics for the daylight calibration instrument: percentiles and
# coverage shares of the sampled frame luminance. Pure math over an Image that
# arrives as an argument — no load(), no paths into the game, so it runs
# headless (test_stats.gd).
#
# The luminance weights mirror VTKNVG.gdshader (the rawLuminance dot product
# in the thermal branch): 0.299 r + 0.587 g + 0.114 b. The shader is the source
# of truth for what the player sees, so the instrument must measure the same
# quantity it paints.

# Linear interpolation between neighbours: pos = q * (n - 1). The input is
# duplicated before sorting, so the caller's order survives. Empty input
# yields an empty dictionary; q outside [0, 1] saturates at the ends.
static func percentiles(values: Array[float], qs: Array[float]) -> Dictionary:
	var out := {}
	if values.is_empty():
		return out
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	for q in qs:
		var pos := float(q) * float(n - 1)
		var lo := clampi(floori(pos), 0, n - 1)
		var hi := mini(lo + 1, n - 1)
		var frac := clampf(pos - float(lo), 0.0, 1.0)
		var a := float(sorted[lo])
		var b := float(sorted[hi])
		out[q] = a * (1.0 - frac) + b * frac
	return out

# Samples the image on a square grid whose stride keeps the sample count at
# or below max_samples, then reports p05/p25/p50/p75/p95, mean and the share
# of crushed shadows (L <= 0.03) and clipped highlights (L >= 0.97) under
# the shader's luminance weights. A null or empty image yields {}.
static func from_image(img: Image, max_samples := 4096) -> Dictionary:
	var out := {}
	if img == null or img.get_width() <= 0 or img.get_height() <= 0:
		return out
	var w := img.get_width()
	var h := img.get_height()
	var stride := maxi(1, ceili(sqrt(w * h / float(max_samples))))
	var qs: Array[float] = [0.05, 0.25, 0.5, 0.75, 0.95]
	var vals: Array[float] = []
	var total := 0.0
	var black := 0
	var cream := 0
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var c := img.get_pixel(x, y)
			var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			vals.push_back(lum)
			total += lum
			if lum <= 0.03:
				black += 1
			elif lum >= 0.97:
				cream += 1
			x += stride
		y += stride
	var count := vals.size()
	var p := percentiles(vals, qs)
	out["p05"] = p[0.05]
	out["p25"] = p[0.25]
	out["p50"] = p[0.5]
	out["p75"] = p[0.75]
	out["p95"] = p[0.95]
	out["mean"] = total / float(count)
	out["black_share"] = float(black) / float(count)
	out["cream_share"] = float(cream) / float(count)
	out["count"] = count
	return out
