shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
// Daylight compensation lowers the game's exposure; the key is scaled back by
// the same factor before the tonemap, so its on-screen colour stays the
// night-time value the detector was calibrated against.
global uniform float vtk_key_gain = 1.0;
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	vec3 colour = state_key * vtk_key_gain;
	float a = pow(edge, rim_power);
	// Rim 0 is a deliberate full-body fill, not the pow(x, 0) = 1 blowout that
	// read as white with speckles: a solid silhouette in the raw state colour,
	// which keeps its hue instead of clipping through the daylight gain.
	if (rim_power <= 0.01) {
		a = 0.85;
		colour = state_key;
	}
	ALBEDO = colour;
	ALPHA = a * (1.0 - cool);
}
