shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

// Ring pass for the ESP mask (VTKEspMask.gd). The mask never reaches the
// screen: it is sampled by VTKNVG.gdshader, which substitutes the state
// colour from the dominant channel. Pure primaries on purpose -- the world
// behind the shell adds to the pixel, so only the channel gap is stable.
//
// The stencil read is a no-op when no body pass ran (the buffer is 0, and
// 0 != 1 passes), so this single shader serves both the plain ring and the
// outside-the-fill band.

uniform vec3 state_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 2.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
// Below this coverage the pixel is dropped instead of blended into the world:
// the overlay can only read the category from a pixel the shell actually
// dominates.
uniform float floor_alpha : hint_range(0.0, 1.0, 0.01) = 0.30;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	float a = 1.0;
	if (rim_power > 0.01) {
		a = pow(edge, rim_power);
	}
	a *= (1.0 - cool);
	if (a < floor_alpha) {
		discard;
	}
	ALBEDO = state_color;
	ALPHA = a;
}
