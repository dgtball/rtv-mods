shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Body/tint pass of the direct contour overlay. Renders the silhouette with
// the final display colour; no stencil mask is written for the ring. The
// fill is weighted by a fresnel rim: the centre keeps its detail, the edges
// glow. rim_power = 0 disables the falloff (flat fill mode).

uniform vec3 outline_color : source_color = vec3(1.0, 0.0, 0.0);
uniform float brightness : hint_range(0.0, 4.0, 0.01) = 1.0;
uniform float alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.004;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 2.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	float rim = 1.0;
	if (rim_power > 0.01) {
		rim = pow(edge, rim_power);
	}
	ALBEDO = outline_color * brightness;
	ALPHA = (0.3 + 0.7 * rim) * alpha * (1.0 - cool);
}
