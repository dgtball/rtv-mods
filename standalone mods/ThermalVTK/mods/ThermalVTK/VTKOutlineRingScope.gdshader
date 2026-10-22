shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled;

// Scope variant of the silhouette ring. The scope lens sits a few centimetres
// from the eye and writes depth (depth_draw_always), so a depth-tested ring on
// any target behind it fails the z test and vanishes in the scope view. This
// variant ignores the depth buffer while the scope view is active and swaps
// back the moment it ends. The uniform set is identical to VTKOutlineRing so
// the swap never loses state (state_key, grow, rim_power, cool).
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	ALBEDO = state_key;
	ALPHA = pow(edge, rim_power) * (1.0 - cool);
}
