shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled;
// Scoped mine highlight for an optic WITHOUT PIP. Hardware depth testing is off
// so the highlight crosses the vanilla Mask barrier in the lens; the fragment
// compares its linear depth against opaque depth so walls and trees still hide it.
// Transparent geometry (including Mask) never enters hint_depth_texture.

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 mine_color : source_color = vec3(0.8039215686, 0.0, 1.0);

void fragment() {
	float scene_d = textureLod(depth_texture, SCREEN_UV, 0.0).r;
	vec4 scene_p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_d, 1.0);
	vec4 here_p = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, FRAGCOORD.z, 1.0);
	if (abs(here_p.z / here_p.w) > abs(scene_p.z / scene_p.w) + 0.03) discard;
	ALBEDO = mine_color;
	ALPHA = 1.0;
}
