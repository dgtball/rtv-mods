shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

// Silhouette ring. The mesh is grown along its normals; back faces are culled
// so only the near shell survives, and the rim keeps a power curve on the edge
// measure (|dot(NORMAL, VIEW)| small at the silhouette). rim_power is the edge
// sharpness: 1.0 is a linear falloff, higher values tighten the band toward the
// silhouette.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	// Silhouette edge is where the surface turns away from the view, i.e.
	// |dot| small; the absolute dot makes the band symmetric.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	ALBEDO = state_key;
	ALPHA = pow(edge, rim_power) * (1.0 - cool);
}
