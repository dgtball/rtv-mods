shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// Scoped body/tint pass for an optic WITHOUT PIP. Hardware depth testing is off
// so the contour crosses the vanilla Mask barrier in the lens. Instead of
// showing through every wall, the fragment compares its own linear depth with
// the opaque depth buffer: only fragments in front of the world survive.
// Transparent geometry (including Mask) never enters hint_depth_texture.

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
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
	float scene_d = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 scene_p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_d, 1.0);
	vec4 here_p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, FRAGCOORD.z, 1.0);
	if (abs(here_p.z / here_p.w) > abs(scene_p.z / scene_p.w) + 0.03) discard;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	float rim = 1.0;
	if (rim_power > 0.01) {
		rim = pow(edge, rim_power);
	}
	ALBEDO = outline_color * brightness;
	ALPHA = (0.3 + 0.7 * rim) * alpha * (1.0 - cool);
}
