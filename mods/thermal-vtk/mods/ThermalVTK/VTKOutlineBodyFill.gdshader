shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode write, 1;

// Full-body pass: paints the whole silhouette and marks its pixels in the
// stencil, so the ring pass in next_pass can draw strictly outside the body.
// That is what removes the inner contours the depth-only mask used to leave.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
global uniform float vtk_key_gain = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	ALBEDO = state_key * vtk_key_gain;
	ALPHA = 0.85 * (1.0 - cool);
}
