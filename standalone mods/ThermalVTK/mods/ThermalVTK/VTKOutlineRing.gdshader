shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

// Silhouette ring. Front-faces mode (outline_style 0) uses the ImmersiveThreat
// Highlight trick: the front faces are culled so only the far shell of the
// grown mesh survives, and this branch keeps a smoothstep band, discarding the
// shell interior so no inflated blob shows. Back-faces mode (outline_style 1)
// keeps the older grown-shell pow() rim. The cull token is swapped at load
// because render_mode is compile-time in Godot.
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
	// With front faces culled we see the back shell; the silhouette edge is
	// where the surface turns away from the view, i.e. |dot| small. Use the
	// absolute dot so the band is symmetric; rim_start/rim_end control its
	// width in the front style.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	ALBEDO = state_key;
	float line;
	if (outline_style == 0) {
		line = smoothstep(rim_start, rim_end, edge);
		if (line < 0.03) {
			discard;
		}
	} else {
		line = pow(edge, rim_power);
	}
	ALPHA = line * (1.0 - cool);
}
