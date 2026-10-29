shader_type canvas_item;

// NVG / thermal overlay. Replaces the vanilla NVG ColorRect shader (see
// VTKNVG.gd for why the swap is safe). The whole frame is read back through
// the false-colour thermal palette; the mine and the three contour state keys
// are pulled out by comparing the screen against the
// *Key uniforms. Those keys are NOT the raw colours the world-space shaders
// emit -- the vanilla NVG world processing washes bright keys toward white
// before this shader ever sees them -- but the measured post-NVG values
// (VTKNVG.gd DET_*). Keep the key lists in lockstep with VTKNVG.gd. The *Color
// uniforms are the freely chosen substitution colours.

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
uniform bool scopeRotate = false;
uniform float thermalDarken : hint_range(1.0, 4.0, 0.01) = 1.70;
// 0 at night, 1 at full daylight. Daylight compensation lowers the exposure
// (keeping snow/sky below the tonemap ceiling); this curve then lifts the now
// darker background into the palette so the image stays readable. Applied to
// the background only: detector keys are substituted before the palette.
uniform float dayMix : hint_range(0.0, 1.0, 0.01) = 0.0;
// Highlight rolloff knee for daylight: background brighter than this (snow,
// sky, cloud decks) bends into a soft shoulder below white before the palette,
// so it keeps gradient instead of clipping into one flat colour. 1.0 = off.
// Night is unaffected either way: the shoulder only engages with daylight mix.
uniform float highlightKnee : hint_range(0.3, 1.0, 0.05) = 0.6;
uniform int worldPaletteMode = 0;
// Final image brightness while NVG is on. Applied to the composited overlay, so
// unlike the old Environment.tonemap_white poke it is actually visible.
uniform float nvgWhite : hint_range(0.05, 1.0, 0.05) = 1.0;

uniform vec3 mineKey : source_color = vec3(0.0, 0.0, 1.0);

// Contour ESP state keys. The ring emits these fixed colours; the frame is
// NVG-processed before this shader sees it, so the *Key uniforms hold the
// measured post-NVG (washed) values (see VTKNVG.gd DET_ST_*). The *Color
// uniforms are the per-state display colours, substituted AFTER the palette.
uniform vec3 stNormalKey : source_color = vec3(1.0, 0.21, 0.16);
uniform vec3 stCombatKey : source_color = vec3(0.82, 1.0, 1.0);
uniform vec3 stDefendKey : source_color = vec3(1.0, 0.34, 1.0);
uniform vec3 stNormalColor : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 stCombatColor : source_color = vec3(0.95, 0.18, 0.15);
uniform vec3 stDefendColor : source_color = vec3(0.62, 0.30, 0.95);
uniform float stateBright : hint_range(0.1, 3.0, 0.05) = 0.6;

// Body-fill and friendly-nomad detector removed in 2.2.0: both now draw as a 2D overlay
// outside this screen-space key substitution, so the overlay no longer needs them.

uniform vec3 mineColor : source_color = vec3(0.7, 0.1, 0.07);

float Goggles(vec2 uv)
{
	vec2 centerUV = (uv * 2.0 - 1.0);
	centerUV.x *= goggleAspect;
	float G1Distance = length(centerUV - vec2(-goggleSeparation * goggleAspect, 0.0));
	float G2Distance = length(centerUV - vec2(goggleSeparation * goggleAspect, 0.0));
	return min(G1Distance, G2Distance);
}

// 0 = Classic (else), 1 = Amber, 2 = Forest, 3 = Ice.
vec3 ThermalPalette(float t)
{
	t = clamp(t, 0.0, 1.0);
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
// Shape: a milder uniform rescale above the knee (distance fog keeps its
// gradient), then an exponential tail caps the truly hot pixels just below
// white. Slope at the knee is not C1, but NVG noise hides a crease of this
// size; the distance contrast is worth it.
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

// PIP off + magnifying scope: the lens path rotates colour channels on screen,
// so a key shows up as its three cyclic rotations. Match the orbit when that can
// happen, plain distance otherwise (zero change off-scope / PIP on).
float orbitDist(vec3 c, vec3 k)
{
	if (!scopeRotate) {
		return distance(c, k);
	}
	float d = distance(c, k);
	d = min(d, distance(c, k.brg));
	d = min(d, distance(c, k.gbr));
	return d;
}

// Detector radius. The mine, state and nomad keys are matched tightly: those
// branches replace the pixel outright, so a loose radius would paint the
// wrong colour over unrelated pixels.
const float DET_TOL_CORE = 0.22;

void fragment()
{
	vec4 pixelColor = texture(screen_texture, SCREEN_UV);
	float goggleMask = smoothstep(goggleSize + vignette, goggleSize, Goggles(UV));
	float goggleRim = abs(Goggles(UV) - goggleSize);
	float goggleOutlines = 1.0 - smoothstep(0.0, goggleOutline, goggleRim);
	float x = (SCREEN_UV.x + 1.0) * (SCREEN_UV.y + 1.0) * (TIME * 10.0);
	vec4 noiseEffect = vec4(mod((mod(x, 13.0)) * (mod(x, 123.0)), 0.01) - 0.005) * noise;

	vec4 color;
	if (thermalMode) {
		// Pick whichever key is CLOSEST: an if/elif chain would let an
		// earlier check steal matches that belong to a later key.
		float dMine = orbitDist(pixelColor.rgb, mineKey);
		float dStN = orbitDist(pixelColor.rgb, stNormalKey);
		float dStC = orbitDist(pixelColor.rgb, stCombatKey);
		float dStD = orbitDist(pixelColor.rgb, stDefendKey);
		// Wash guard for the combat key. Combat is the only two-channel-
		// saturated key, so a fully washed pixel (daylight sky, snow, cloud
		// decks) converges onto its measured orbit and painted the whole sky
		// combat-red plus red speckles on bright snow. The ring pixel keeps
		// one channel behind by ~0.18 (see DET_ST_COMBAT in VTKNVG.gd); a
		// white wash has all channels together. Spread below the margin
		// cannot be the ring, whatever the scope rotation did to its orbit.
		float washSpread = max(pixelColor.r, max(pixelColor.g, pixelColor.b))
			- min(pixelColor.r, min(pixelColor.g, pixelColor.b));
		if (washSpread < 0.10) {
			dStC = 99.0;
		}
		float dCore = min(dMine, min(dStN, min(dStC, dStD)));

		float rawLuminance = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
		// Shoulder BEFORE the clamp: the top of the range bends down while the
		// gradient still exists; the clamp afterwards sees values that stop at
		// the shoulder top, so snow, sky and truly hot pixels stay distinct.
		float luminance = clamp(hiShoulder(rawLuminance * thermalDarken, highlightKnee, dayMix), 0.0, 1.0);
		// Soft lift: full strength maps 0.1 -> 0.15, 0.5 -> 0.67, 1.0 -> 1.0.
		if (dayMix > 0.0) {
			float lifted = 1.0 - pow(1.0 - luminance, 1.6);
			luminance = mix(luminance, lifted, dayMix);
		}
		vec3 backgroundColor = ThermalPalette(luminance) * 0.7;
		if (dCore < DET_TOL_CORE) {
			// Closest wins. Order (exact ties only): mine, states.
			if (dCore == dMine) {
				color = vec4(mineColor, pixelColor.a);
			} else if (dCore == dStN) {
				color = vec4(stNormalColor * stateBright, pixelColor.a);
			} else if (dCore == dStC) {
				color = vec4(stCombatColor * stateBright, pixelColor.a);
			} else if (dCore == dStD) {
				color = vec4(stDefendColor * stateBright, pixelColor.a);
			} else {
				color = vec4(backgroundColor, pixelColor.a);
			}
		} else {
			color = vec4(backgroundColor, pixelColor.a);
		}
	} else {
		color = pixelColor * tint;
		// The plain NVG branch runs without the thermal palette, so the same
		// daylight trim needs its own soft lift to keep daylight readable.
		if (dayMix > 0.0) {
			float tintLum = max(dot(color.rgb, vec3(0.299, 0.587, 0.114)), 0.0001);
			// Same order as the thermal branch: bend the highlights into the
			// shoulder first, then lift the middle back up.
			tintLum = hiShoulder(tintLum, highlightKnee, dayMix);
			float liftedLum = 1.0 - pow(1.0 - min(tintLum, 1.0), 1.6);
			color.rgb *= mix(1.0, liftedLum / tintLum, dayMix);
		}
		// Contour mode: no world palette, but mine keys are still painted onto
		// mines so they stay readable here instead of reading as a plain
		// tinted shell.
		if (orbitDist(pixelColor.rgb, mineKey) < 0.15) {
			color = vec4(mineColor, pixelColor.a);
		}
	}
	color.rgb *= nvgWhite;
	color += noiseEffect;
	color.rgb *= (1.0 + goggleOutlines);
	COLOR = mix(vec4(0.0, 0.0, 0.0, 1.0), color, goggleMask);
}
