shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// X-ray ring of the ESP mask: the same band as VTKEspMaskRing, but with the
// depth test dropped, so a live trigger window writes the category straight
// through walls. The mask carries it to the screen; nothing else changes.

uniform vec3 state_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 2.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
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
