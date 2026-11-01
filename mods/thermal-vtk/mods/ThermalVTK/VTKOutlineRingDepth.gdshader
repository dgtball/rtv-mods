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
	// Rim 0 is the full-body fill. It must emit the SAME key as the ring at
	// full alpha: the NVG detector only repaints pixels that match the key, and
	// a dimmed or blended colour falls through to the background palette (that
	// is what made the fill cream indoors and orange outside). pow(x, 0) is
	// undefined in GLSL, which also left speckles; the branch avoids it.
	float a = 1.0;
	if (rim_power > 0.01) {
		a = pow(edge, rim_power);
	}
	ALBEDO = state_key * vtk_key_gain;
	ALPHA = a * (1.0 - cool);
}
