shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode write, 1;

// Full-body pass of the contour overlay: paints the whole silhouette with the
// category key and marks the pixels in the stencil, so the ring pass in
// next_pass draws strictly outside the body. The key has to reach the screen at
// nearly full coverage: a dimmed fill blended with the world falls outside the
// detector's radius and reads as plain background.

uniform vec3 state_color : source_color = vec3(1.0, 0.0, 0.0);
global uniform float vtk_key_gain = 1.0;
uniform float grow : hint_range(0.0, 0.05, 0.001) = 0.004;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 0.85;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = state_color * vtk_key_gain;
	ALPHA = alpha * (1.0 - cool);
}
