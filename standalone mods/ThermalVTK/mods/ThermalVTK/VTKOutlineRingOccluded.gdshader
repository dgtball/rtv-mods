shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled;

// Depth-comparing variant of the silhouette ring. The auto depth test cannot
// tell the scope lens from a wall: the lens sits centimetres from the eye and
// z-culls every ring behind it. So the shader drops the auto test and does
// its own comparison: an occluder closer than the fragment hides the ring,
// unless the occluder is nearer than EXCLUDE_M metres - the band where only
// camera-attached geometry (the scope lens, objects pressed against the
// camera) can live. Uniform parity with VTKOutlineRing.gdshader matters: the
// runtime flip keeps all state without re-reading opts.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// Occluders closer than this are camera-attached, not walls.
const float EXCLUDE_M = 0.25;

void vertex() {
	VERTEX += NORMAL * grow;
}

// NDC depth -> metres in front of the camera (reversed-Z, Forward+).
// Stage builtins resolve only inside the stage functions: the screen coords
// and the inverse projection matrix come in as arguments.
float depth_metres(float ndc, vec2 uv, mat4 inv_proj) {
	vec4 view = inv_proj * vec4(uv * 2.0 - 1.0, ndc, 1.0);
	return -view.z / view.w;
}

void fragment() {
	// Same edge measure as the x-ray ring: |dot| small at the silhouette,
	// abs() keeps the band symmetric.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	ALBEDO = state_key;
	ALPHA = pow(edge, rim_power) * (1.0 - cool);

	float scene_m = depth_metres(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX);
	float frag_m = depth_metres(FRAGCOORD.z, SCREEN_UV, INV_PROJECTION_MATRIX);
	// The shell is grown along the normals, so the band over the model's own
	// surface sits slightly behind the model front: the bias absorbs that.
	float bias = max(grow * 4.0, 0.02);
	if ((scene_m < frag_m - bias) && (scene_m > EXCLUDE_M)) {
		ALPHA = 0.0;
	}
}