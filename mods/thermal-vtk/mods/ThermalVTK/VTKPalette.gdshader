shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;

// Fullscreen palette pass in the main 3D view. Godot copies the screen after
// the opaque pass and before transparent geometry. This quad is the FIRST
// transparent pass (render_priority -128): it palettizes the world, then
// vanilla optics, reticles and our exact-colour ESP/mine overlays draw on top.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// One number holds world brightness, the day/snow trims and the daylight
// factor. The knee is the night-disabled version of the old daylight shoulder.
uniform float inputGain : hint_range(0.05, 8.0, 0.01) = 1.7;
uniform float inputKnee : hint_range(0.3, 1.0, 0.01) = 1.0;
// The five stops of the active 2.4.6 palette and its output factor. Pushed
// from VTKPalettes; 0 = darkest, 4 = cream.
uniform vec3 paletteStop0 : source_color = vec3(0.00, 0.00, 0.03);
uniform vec3 paletteStop1 : source_color = vec3(0.24, 0.10, 0.38);
uniform vec3 paletteStop2 : source_color = vec3(0.65, 0.00, 0.10);
uniform vec3 paletteStop3 : source_color = vec3(0.90, 0.65, 0.00);
uniform vec3 paletteStop4 : source_color = vec3(1.00, 1.00, 0.80);
uniform float paletteOut : hint_range(0.1, 1.0, 0.01) = 0.7;

// C1 highlight shoulder: luminance above the knee bends down toward a bounded
// top, so the palette never receives a flat clipped value for the brightest
// part of the frame. Must run on the UNCLAMPED luminance. Knee 1.0 is a
// pass-through, which is the night case.
float shoulder(float x, float knee)
{
	float k = knee;
	if (k >= 0.999 || x <= k) {
		return x;
	}
	float slope = 0.75;
	float top = k + slope * (1.0 - k);
	float cap = min(0.98, top + 0.18);
	if (x <= 1.0) {
		return k + (x - k) * slope;
	}
	return top + (cap - top) * (1.0 - exp(-(x - 1.0) * slope / (cap - top)));
}

// Fixed 2.4.6 ladder. The edges are constants, not data: only the colours
// move with the selected palette.
vec3 ramp(float t)
{
	vec3 c = mix(paletteStop0, paletteStop1, smoothstep(0.0, 0.25, t));
	c = mix(c, paletteStop2, smoothstep(0.25, 0.5, t));
	c = mix(c, paletteStop3, smoothstep(0.5, 0.75, t));
	c = mix(c, paletteStop4, smoothstep(0.75, 1.0, t));
	return c;
}

void vertex() {
	// POSITION bypasses the camera transform: a (2,2) QuadMesh covers the
	// viewport in clip space. On Godot 4.3+ the depth is 1.0 (reversed-z).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 pixelColor = texture(screen_texture, SCREEN_UV);
	float v = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
	v = clamp(shoulder(v * inputGain, inputKnee), 0.0, 1.0);
	// The quad samples the linear pre-tonemap frame. Apply display gamma before
	// the ramp, otherwise the dark end of the old canvas pipeline stays black.
	v = pow(v, 1.0 / 2.2);
	vec3 pal = ramp(v) * paletteOut;
	ALBEDO = pal;
	// The palette is total. Because this pass runs before every transparent
	// overlay, optics and reticles are never half-washed and ESP/mines drawn at
	// 20/21 keep their exact colours. The screen copy above only supplies the
	// world luminance for the ramp.
	ALPHA = 1.0;
}
