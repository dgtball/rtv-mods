shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
stencil_mode write, 1;

// XRAY body/tint pass of the direct contour overlay. Same shape as the LOS
// body pass, but depth testing is disabled so the silhouette shows through walls.

uniform vec3 outline_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float brightness : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.004;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	ALBEDO = outline_color * brightness;
	ALPHA = alpha * (1.0 - cool);
}
