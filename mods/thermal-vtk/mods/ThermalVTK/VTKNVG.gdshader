shader_type canvas_item;

// NVG / thermal overlay. Replaces the vanilla NVG ColorRect shader (see
// VTKNVG.gd for why the swap is safe). The thermal palette is applied to the
// background; contours and mines are rendered into a separate ESP buffer and
// composited here with their own display colours/alpha.

// filter_linear, not filter_linear_mipmap: the screen is sampled 1:1 through
// SCREEN_UV, so mip 0 is the only one ever read. Requesting mipmaps makes the
// renderer build a full-screen mip chain every frame for nothing.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
// ESP buffer pass (contours/mines) composited over the palettized background.
// ESP pixels keep their own display colour/alpha and are not recoloured by the
// world palette or nvgWhite/noise.
uniform sampler2D espTex : repeat_disable, filter_linear;
uniform bool espComposite = false;
uniform vec4 tint : source_color = vec4(0.47, 0.67, 0.51, 1.0);
uniform float noise : hint_range(0.0, 60.0, 1.0) = 4.0;
uniform float vignette : hint_range(0.0, 1.0, 0.1) = 0.1;
uniform float goggleSeparation : hint_range(0.0, 1.0, 0.1) = 0.4;
uniform float goggleSize : hint_range(0.0, 1.0, 0.1) = 0.8;
uniform float goggleAspect : hint_range(0.0, 2.0, 0.1) = 1.6;
uniform float goggleOutline : hint_range(0.0, 0.1, 0.01) = 0.05;

uniform bool thermalMode = false;
uniform float thermalDarken : hint_range(1.0, 4.0, 0.01) = 1.70;
// 0 at night, 1 at full daylight. Daylight compensation lowers the exposure
// (keeping snow/sky below the tonemap ceiling); this curve then lifts the now
// darker background into the palette so the image stays readable.
uniform float dayMix : hint_range(0.0, 1.0, 0.01) = 0.0;
// Highlight rolloff knee for daylight: background brighter than this (snow,
// sky, cloud decks) bends into a soft shoulder below white before the palette,
// so it keeps gradient instead of clipping into one flat colour. 1.0 = off.
// Night is unaffected either way: the shoulder only engages with daylight mix.
uniform float highlightKnee : hint_range(0.3, 1.0, 0.05) = 0.55;
uniform int worldPaletteMode = 0;
// Final image brightness while NVG is on. Applied to the composited overlay, so
// unlike the old Environment.tonemap_white poke it is actually visible.
uniform float nvgWhite : hint_range(0.05, 1.0, 0.05) = 1.0;
uniform float vrcetsStrength : hint_range(0.0, 1.0, 0.01) = 0.58;
uniform float vrcetsRedHold : hint_range(0.0, 1.0, 0.01) = 0.72;

float Goggles(vec2 uv)
{
	vec2 centerUV = (uv * 2.0 - 1.0);
	centerUV.x *= goggleAspect;
	float G1Distance = length(centerUV - vec2(-goggleSeparation * goggleAspect, 0.0));
	float G2Distance = length(centerUV - vec2(goggleSeparation * goggleAspect, 0.0));
	return min(G1Distance, G2Distance);
}

// 0 = Classic (else), 1 = Amber, 2 = Forest, 3 = Ice,
// 4 = VRCETS Auto, 5 = VRCETS Blue/Day, 6 = VRCETS Red.
vec3 vrcets_night_palette(float v) {
	vec3 cold = vec3(0.02, 0.08, 0.34);
	vec3 cool = vec3(0.04, 0.18, 0.62);
	vec3 mid = vec3(0.42, 0.05, 0.18);
	vec3 warm = vec3(0.92, 0.11, 0.03);
	vec3 hot = vec3(1.0, 0.48, 0.08);
	vec3 color = mix(cold, cool, smoothstep(0.05, 0.32, v));
	color = mix(color, mid, smoothstep(0.22, 0.55, v));
	color = mix(color, warm, smoothstep(0.42, 0.76, v));
	color = mix(color, hot, smoothstep(0.68, 1.0, v));
	return color;
}

vec3 vrcets_day_palette(float v) {
	vec3 cold = vec3(0.025, 0.075, 0.24);
	vec3 cool = vec3(0.045, 0.17, 0.46);
	vec3 neutral = vec3(0.10, 0.24, 0.38);
	vec3 warm = vec3(0.34, 0.16, 0.07);
	vec3 hot = vec3(0.92, 0.16, 0.035);
	vec3 color = mix(cold, cool, smoothstep(0.04, 0.35, v));
	color = mix(color, neutral, smoothstep(0.30, 0.76, v));
	color = mix(color, warm, smoothstep(0.84, 0.96, v));
	color = mix(color, hot, smoothstep(0.965, 1.0, v));
	return color;
}

vec3 vrcets_red_palette(float v) {
	vec3 cold = vec3(0.05, 0.015, 0.11);
	vec3 mid = vec3(0.34, 0.035, 0.10);
	vec3 warm = vec3(0.92, 0.10, 0.025);
	vec3 hot = vec3(1.0, 0.40, 0.06);
	vec3 color = mix(cold, mid, smoothstep(0.05, 0.42, v));
	color = mix(color, warm, smoothstep(0.28, 0.80, v));
	color = mix(color, hot, smoothstep(0.72, 1.0, v));
	return color;
}

float vrcets_red_heat(vec3 src) {
	float rh = smoothstep(0.10, 0.55, src.r) * (1.0 - smoothstep(src.r * 0.58, src.r * 0.94, max(src.g, src.b)));
	return clamp(rh, 0.0, 1.0);
}

vec3 vrcets_held_heat(float luma) {
	return mix(vec3(0.95, 0.08, 0.025), vec3(1.0, 0.32, 0.04), clamp(luma, 0.0, 1.0));
}

vec3 ThermalPalette(float t)
{
	t = clamp(t, 0.0, 1.0);
	if (worldPaletteMode == 4) {
		return mix(vrcets_night_palette(t), vrcets_day_palette(t), clamp(dayMix, 0.0, 1.0));
	} else if (worldPaletteMode == 5) {
		return vrcets_day_palette(t);
	} else if (worldPaletteMode == 6) {
		return vrcets_red_palette(t);
	}
	vec3 c0;
	vec3 c1;
	vec3 c2;
	vec3 c3;
	vec3 c4;
	if (worldPaletteMode == 1) {
		c0 = vec3(0.02, 0.01, 0.0);
		c1 = vec3(0.25, 0.12, 0.02);
		c2 = vec3(0.55, 0.30, 0.05);
		c3 = vec3(0.80, 0.58, 0.18);
		c4 = vec3(1.0, 0.92, 0.70);
	} else if (worldPaletteMode == 2) {
		c0 = vec3(0.0, 0.02, 0.02);
		c1 = vec3(0.05, 0.18, 0.12);
		c2 = vec3(0.10, 0.38, 0.22);
		c3 = vec3(0.35, 0.62, 0.30);
		c4 = vec3(0.80, 0.95, 0.65);
	} else if (worldPaletteMode == 3) {
		c0 = vec3(0.0, 0.01, 0.04);
		c1 = vec3(0.05, 0.12, 0.35);
		c2 = vec3(0.10, 0.30, 0.60);
		c3 = vec3(0.40, 0.65, 0.85);
		c4 = vec3(0.85, 0.95, 1.0);
	} else {
		c0 = vec3(0.0, 0.0, 0.03);
		// The Classic ladder must ascend in luminance (dot(rgb, 0.299/0.587/0.114)).
		// The old c1 (0.30,0.12,0.45) measured 0.211, outshining the old c2
		// (0.55,0,0.08) at 0.174: in fog, where the whole frame compresses onto
		// the 0.25-0.5 palette span, warmer spots read darker than cold ground.
		c1 = vec3(0.24, 0.10, 0.38);
		c2 = vec3(0.65, 0.0, 0.10);
		c3 = vec3(0.9, 0.65, 0.0);
		c4 = vec3(1.0, 1.0, 0.8);
	}
	vec3 color = mix(c0, c1, smoothstep(0.0, 0.25, t));
	color = mix(color, c2, smoothstep(0.25, 0.5, t));
	color = mix(color, c3, smoothstep(0.5, 0.75, t));
	color = mix(color, c4, smoothstep(0.75, 1.0, t));
	return color;
}

// C1 highlight shoulder for daylight: luminance above the knee bends down
// toward a bounded top, so the palette never receives a flat clipped value for
// the brightest part of the frame. Must run on the UNCLAMPED luminance: once
// clamped, snow and sky are both exactly 1.0 and the gradient between them is
// already lost. strength = dayMix: at night the knee sits above 1.0 and the
// curve is a no-op.
float hiShoulder(float x, float knee, float strength)
{
	float k = mix(1.0, knee, strength);
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

void fragment()
{
	vec4 pixelColor = texture(screen_texture, SCREEN_UV);
	float goggleMask = smoothstep(goggleSize + vignette, goggleSize, Goggles(UV));
	float goggleRim = abs(Goggles(UV) - goggleSize);
	float goggleOutlines = 1.0 - smoothstep(0.0, goggleOutline, goggleRim);
	float x = (SCREEN_UV.x + 1.0) * (SCREEN_UV.y + 1.0) * (TIME * 10.0);
	vec4 noiseEffect = vec4(mod((mod(x, 13.0)) * (mod(x, 123.0)), 0.01) - 0.005) * noise;

	vec4 color;
	bool composited = false;
	if (thermalMode) {
		float rawLuminance = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
		float luminance = clamp(hiShoulder(rawLuminance * thermalDarken, highlightKnee, dayMix), 0.0, 1.0);
		if (dayMix > 0.0) {
			float lifted = 1.0 - pow(1.0 - luminance, 1.6);
			luminance = mix(luminance, lifted, dayMix);
		}
		vec3 backgroundColor = ThermalPalette(luminance) * 0.7;
		if (worldPaletteMode >= 4) {
			float rh = vrcets_red_heat(pixelColor.rgb) * vrcetsRedHold;
			backgroundColor = mix(backgroundColor, vrcets_held_heat(clamp(rawLuminance, 0.0, 1.0)), clamp(rh, 0.0, 1.0));
			// Blend toward thermal palette like VRCETS world palette (background only).
			backgroundColor = mix(pixelColor.rgb, backgroundColor, clamp(vrcetsStrength, 0.0, 1.0));
		}
		color = vec4(backgroundColor, pixelColor.a);
	} else {
		color = pixelColor * tint;
		if (dayMix > 0.0) {
			float tintLum = max(dot(color.rgb, vec3(0.299, 0.587, 0.114)), 0.0001);
			tintLum = hiShoulder(tintLum, highlightKnee, dayMix);
			float liftedLum = 1.0 - pow(1.0 - min(tintLum, 1.0), 1.6);
			color.rgb *= mix(1.0, liftedLum / tintLum, dayMix);
		}
	}
	if (espComposite) {
		vec4 esp = texture(espTex, SCREEN_UV);
		if (esp.a > 0.001) {
			// ESP pixels keep their own display colour/alpha: composite over the
			// palettized/tinted background without passing them through palette,
			// nvgWhite or noise.
			color.rgb = mix(color.rgb, esp.rgb, clamp(esp.a, 0.0, 1.0));
			composited = true;
		}
	}
	if (!composited) {
		color.rgb *= nvgWhite;
		color += noiseEffect;
	}
	color.rgb *= (1.0 + goggleOutlines);
	COLOR = mix(vec4(0.0, 0.0, 0.0, 1.0), color, goggleMask);
}
