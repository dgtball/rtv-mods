shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled;

// Depth-comparing variant of the silhouette ring. One shader serves both
// modes; the mode lives in uniforms:
// - near_only = false (idle ring): the wall compare honours every occluder.
// - near_only = true (x-ray ring): walls punch through, and only
//   camera-attached geometry closer than the carve hides the ring — that is
//   how the carried scope glass stops leaking x-ray from the outside while
//   the ring survives in the magnified scope view.
// carve is the metres-in-front-of-the-camera zone that never occludes. The
// ESP drives both: scoped runs widen it (0.60, the aiming eye sits inside the
// optic), free runs keep it at 0.10 so the idle ring hides behind the settled
// scope glass. Uniform parity with the old ring pair: the runtime flip keeps
// all state without re-reading opts.
uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool near_only = false;
uniform float carve : hint_range(0.05, 1.0, 0.01) = 0.25;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// The scope picture window: the ring draws only inside it while aiming.
// Measured once per scope engage from the optic's Mask disc: the projected
// vertex cloud of the mask surface gives the window boundary in 2*SCREEN_UV-1
// units (clipCenter, clipR). clipR = 0.0 keeps this clip off (not aiming).
uniform vec2 clipCenter = vec2(0.0, 0.0);
uniform float clipR = 0.0;

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
	// Screen-space clip to the scope picture window; off when clipR = 0.
	if (clipR > 0.001) {
		vec2 scr = SCREEN_UV * 2.0 - vec2(1.0);
		if (length(scr - clipCenter) > clipR) {
			discard;
		}
	}
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
	if (near_only) {
		// X-ray ring: walls stay punched through; anything the game mounts
		// in front of the eye (the carried scope glass) still hides it.
		if (scene_m < carve) {
			ALPHA = 0.0;
		}
	} else if ((scene_m < frag_m - bias) && (scene_m > carve)) {
		ALPHA = 0.0;
	}
}