shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode write, 1;

// Full-body pass of the ESP mask: paints the whole silhouette with the
// category colour and marks the pixels in the stencil, so the ring pass in
// next_pass draws strictly outside the body (the same two-pass trick the
// screen-space key path used).

uniform vec3 state_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.05, 0.001) = 0.004;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 0.2;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = state_color;
	ALPHA = alpha * (1.0 - cool);
}
