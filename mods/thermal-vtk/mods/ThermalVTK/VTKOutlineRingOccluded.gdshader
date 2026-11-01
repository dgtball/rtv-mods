shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, depth_test_disabled;

// X-ray overlay. It sits on top of the depth-tested ring and is enabled only
// while a trigger window is live. Where the world hides the bot it fills the
// silhouette; where the bot is in plain sight it stays off, because the ring
// underneath already draws that pixel. `force` covers the other case: a reveal
// past the ESP Distance has no ring of its own, so there the whole contour is
// drawn. `pulse` makes the reveal breathe for as long as the window is open.

uniform vec3 state_key : source_color = vec3(1.0, 0.0, 0.0);
// Daylight compensation lowers the game's exposure; the key is scaled back by
// the same factor before the tonemap, so its on-screen colour stays the
// night-time value the detector was calibrated against.
global uniform float vtk_key_gain = 1.0;
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 1.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool force = false;
uniform float pulse : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

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
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	// Rim 0 fills the body with the same key as the ring, so the detector
	// repaints it in the reference state colour; see the depth shader.
	float a = 1.0;
	if (rim_power > 0.01) {
		a = pow(edge, rim_power);
	}
	ALBEDO = state_key * vtk_key_gain;
	ALPHA = a * (1.0 - cool);

	float scene_m = depth_metres(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX);
	float frag_m = depth_metres(FRAGCOORD.z, SCREEN_UV, INV_PROJECTION_MATRIX);
	// The shell is grown along the normals, so the band over the model's own
	// surface sits slightly behind the model front: the bias absorbs that.
	float bias = max(grow * 4.0, 0.02);

	// The carried scope glass and anything else mounted at the eye still hides
	// the reveal, even through walls.
	float mask = 1.0;
	if (scene_m < 0.60) {
		mask = 0.0;
	} else if (!force && scene_m > frag_m - bias) {
		// Nothing in front of the fragment: the depth-tested ring already
		// covers that pixel, so the overlay stays off and the two never
		// double up.
		mask = 0.0;
	}
	ALPHA *= mask * mix(0.45, 1.0, pulse);
}
