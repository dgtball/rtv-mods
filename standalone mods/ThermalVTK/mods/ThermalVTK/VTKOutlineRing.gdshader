shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Silhouette ring: a grown shell (VERTEX += NORMAL * grow) whose alpha is
// trimmed to the grazing edge by the rim term, so only a band hugging the
// silhouette survives — the ImmersiveThreatHighlight look without mesh
// duplicates. The shader draws NO state colour: it emits a detector key
// (state_key) that the NVG overlay substitutes after the world palette.
// `depth_test_disabled` is stripped at load to build the LOS variant.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float rim01 = 1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = state_key;
	ALPHA = pow(rim01, rim_power);
}
