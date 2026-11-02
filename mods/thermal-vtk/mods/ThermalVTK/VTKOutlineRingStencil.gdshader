shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

// Ring pass for the full-body style: the body pass wrote stencil 1, so this
// shader only paints where the body is not — a clean rim around the fill.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
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
	ALBEDO = state_key * vtk_key_gain;
	ALPHA = pow(edge, rim_power) * (1.0 - cool);
}
