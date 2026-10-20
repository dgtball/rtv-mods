shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Silhouette ring. Front-faces mode (outline_style 0) uses the ImmersiveThreat
// Highlight trick: VTKShaders swaps render_mode to cull_front (the front faces
// are culled, leaving a grazing rim) and this branch keeps a smoothstep band,
// discarding the shell interior so no inflated blob shows. Back-faces mode
// (outline_style 1) keeps the older grown-shell pow() rim. `depth_test_disabled`
// is stripped at load to build the LOS variant; the cull token is swapped the
// same way because render_mode is compile-time in Godot.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float rim_start : hint_range(0.0, 1.0, 0.01) = 0.42;
uniform float rim_end : hint_range(0.0, 1.0, 0.01) = 0.82;
uniform int outline_style = 0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float rim01 = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = state_key;
	float line;
	if (outline_style == 0) {
		line = smoothstep(rim_start, rim_end, rim01);
		if (line < 0.03) {
			discard;
		}
	} else {
		line = pow(rim01, rim_power);
	}
	ALPHA = line * (1.0 - cool);
}
