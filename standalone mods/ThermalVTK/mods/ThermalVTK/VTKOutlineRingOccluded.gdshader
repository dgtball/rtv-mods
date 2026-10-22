shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

// Depth-tested variant of the silhouette ring: identical uniforms and band
// maths to VTKOutlineRing.gdshader, but the depth buffer stays in play, so
// walls and the scope lens occlude the ring like any other object. Uniform
// parity matters: the runtime flip between the two keeps all state without
// re-reading opts.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	// Same edge measure as the x-ray ring: |dot| small at the silhouette,
	// abs() keeps the band symmetric.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	ALBEDO = state_key;
	ALPHA = pow(edge, rim_power) * (1.0 - cool);
}
