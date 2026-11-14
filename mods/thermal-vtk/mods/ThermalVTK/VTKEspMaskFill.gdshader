shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode write, 1;

// Full-body pass of the contour overlay: paints the silhouette with the
// category key and marks the pixels in the stencil. The key must reach the
// screen unblended so the NVG detector can match it; in full-body mode the NVG
// shader replaces detected pixels with a flat, semi-transparent state colour.

uniform vec3 state_color : source_color = vec3(1.0, 0.0, 0.0);
global uniform float vtk_key_gain = 1.0;
uniform float grow : hint_range(0.0, 0.05, 0.001) = 0.004;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float alpha : hint_range(0.05, 1.0, 0.01) = 0.4;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = state_color * vtk_key_gain;
	ALPHA = 1.0;
}
