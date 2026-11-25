shader_type canvas_item;

// NVG / thermal overlay. Replaces the vanilla NVG ColorRect shader (see
// VTKNVG.gd for why the swap is safe). The thermal palette is applied to the
// background sampled from the screen.
//
// THE PIPELINE: inputGain -> shoulder(inputKnee) -> ramp -> paletteOut. The
// stops arrive as uniforms from VTKPalettes; there is no palette mode branch
// and no mirrored curve here. Everything the mod draws in the main 3D pass
// (outlines, mines, nomad marker) is outside this image.

// filter_linear, not filter_linear_mipmap: the screen is sampled 1:1 through
// SCREEN_UV, so mip 0 is the only one ever read. Requesting mipmaps makes the
// renderer build a full-screen mip chain every frame for nothing.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.47, 0.67, 0.51, 1.0);
uniform float noise : hint_range(0.0, 60.0, 1.0) = 4.0;
uniform float vignette : hint_range(0.0, 1.0, 0.1) = 0.1;
uniform float goggleSeparation : hint_range(0.0, 1.0, 0.1) = 0.4;
uniform float goggleSize : hint_range(0.0, 1.0, 0.1) = 0.8;
uniform float goggleAspect : hint_range(0.0, 2.0, 0.1) = 1.6;
uniform float goggleOutline : hint_range(0.0, 0.1, 0.01) = 0.05;

uniform bool thermalMode = false;
// One number holds world brightness, the day/snow trims and the daylight
// factor. The knee is the night-disabled version of the old daylight shoulder.
uniform float inputGain : hint_range(0.05, 8.0, 0.01) = 1.7;
uniform float inputKnee : hint_range(0.3, 1.0, 0.01) = 1.0;
// Final image brightness while NVG is on. Applied to the composited overlay.
uniform float nvgWhite : hint_range(0.05, 1.0, 0.05) = 1.0;
// The five stops of the active 2.4.6 palette and its output factor. Pushed
// from VTKPalettes; 0 = darkest, 4 = cream.
uniform vec3 paletteStop0 : source_color = vec3(0.00, 0.00, 0.03);
uniform vec3 paletteStop1 : source_color = vec3(0.24, 0.10, 0.38);
uniform vec3 paletteStop2 : source_color = vec3(0.65, 0.00, 0.10);
uniform vec3 paletteStop3 : source_color = vec3(0.90, 0.65, 0.00);
uniform vec3 paletteStop4 : source_color = vec3(1.00, 1.00, 0.80);
uniform float paletteOut : hint_range(0.1, 1.0, 0.01) = 0.7;
// TRANSITIONAL: removed in 2.11.0, when the palette becomes total.
uniform float paletteStrength : hint_range(0.0, 1.0, 0.01) = 0.58;
// Mine highlights are 3D shells in the main pass; bypass thermal remapping so
// the configured mine colour stays readable and does not react to palettes.
// TRANSITIONAL: removed in 2.11.0.
uniform bool minePassthroughOn = false;
uniform vec3 minePassthroughColor : source_color = vec3(0.035, 0.18, 0.965);

float Goggles(vec2 uv)
{
	vec2 centerUV = (uv * 2.0 - 1.0);
	centerUV.x *= goggleAspect;
	float G1Distance = length(centerUV - vec2(-goggleSeparation * goggleAspect, 0.0));
	float G2Distance = length(centerUV - vec2(goggleSeparation * goggleAspect, 0.0));
	return min(G1Distance, G2Distance);
}

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

void fragment()
{
	vec4 pixelColor = texture(screen_texture, SCREEN_UV);
	float goggleMask = smoothstep(goggleSize + vignette, goggleSize, Goggles(UV));
	float goggleRim = abs(Goggles(UV) - goggleSize);
	float goggleOutlines = 1.0 - smoothstep(0.0, goggleOutline, goggleRim);
	float x = (SCREEN_UV.x + 1.0) * (SCREEN_UV.y + 1.0) * (TIME * 10.0);
	vec4 noiseEffect = vec4(mod((mod(x, 13.0)) * (mod(x, 123.0)), 0.01) - 0.005) * noise;
	bool isMine = false;
	if (minePassthroughOn) {
		isMine = distance(pixelColor.rgb, minePassthroughColor) < 0.045;
		if (!isMine) {
			float l = max(dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114)), 1e-4);
			float lm = max(dot(minePassthroughColor, vec3(0.299, 0.587, 0.114)), 1e-4);
			vec3 n0 = pixelColor.rgb / l;
			vec3 n1 = minePassthroughColor / lm;
			isMine = distance(n0, n1) < 0.14 && l > 0.008;
		}
	}

	vec4 color;
	if (thermalMode) {
		if (isMine) {
			color = vec4(minePassthroughColor, pixelColor.a);
		} else {
			float v = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
			v = clamp(shoulder(v * inputGain, inputKnee), 0.0, 1.0);
			vec3 pal = ramp(v) * paletteOut;
			// TRANSITIONAL: removed in 2.11.0.
			color = vec4(mix(pixelColor.rgb, pal, clamp(paletteStrength, 0.0, 1.0)), pixelColor.a);
		}
	} else {
		color = pixelColor * tint;
	}
	color.rgb *= nvgWhite;
	if (!isMine) {
		color += noiseEffect;
	}
	color.rgb *= (1.0 + goggleOutlines);
	COLOR = mix(vec4(0.0, 0.0, 0.0, 1.0), color, goggleMask);
}
