shader_type canvas_item;

// NVG / thermal overlay. Replaces the vanilla NVG ColorRect shader (see
// VTKNVG.gd for why the swap is safe). The whole frame is read back through
// the false-colour thermal palette; the mine, the three contour state keys,
// the three body-fill keys and the nomad marker key are pulled out by
// comparing the screen against the *Key uniforms. Those keys are NOT the raw
// colours the world-space shaders emit -- the vanilla NVG world processing
// washes bright keys toward white before this shader ever sees them -- but the
// measured post-NVG values (VTKNVG.gd DET_*). Keep the key lists in lockstep
// with VTKNVG.gd. The *Color uniforms are the freely chosen substitution
// colours; fillOpacity (applied here, not on the mesh) is the fill density.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
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

// Body-fill keys + nomad marker key. Same contract as the state keys: the
// world-space shader emits the key, this overlay substitutes the display
// colour. The *Key uniforms hold the measured post-NVG values (see VTKNVG.gd
// DET_FILL_* / DET_NOMAD). fillOpacity is applied HERE, not on the mesh, so
// the fill reads translucent while its pixel stays opaque enough to detect.
uniform vec3 fillNormKey : source_color = vec3(0.961, 0.753, 0.184);
uniform vec3 fillCombKey : source_color = vec3(0.000, 0.149, 0.969);
uniform vec3 fillDefKey : source_color = vec3(1.000, 0.192, 0.624);
uniform vec3 fillNormColor : source_color = vec3(1.0, 0.72, 0.28);
uniform vec3 fillCombColor : source_color = vec3(0.95, 0.18, 0.15);
uniform vec3 fillDefColor : source_color = vec3(0.62, 0.30, 0.95);
uniform float fillOpacity : hint_range(0.0, 1.0, 0.01) = 0.05;
uniform vec3 nomadKey : source_color = vec3(0.580, 0.973, 0.584);
uniform vec3 nomadColor : source_color = vec3(0.30, 1.0, 0.35);

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
		c1 = vec3(0.30, 0.12, 0.45);
		c2 = vec3(0.55, 0.0, 0.08);
		c3 = vec3(0.9, 0.65, 0.0);
		c4 = vec3(1.0, 1.0, 0.8);
	}
	vec3 color = mix(c0, c1, smoothstep(0.0, 0.25, t));
	color = mix(color, c2, smoothstep(0.25, 0.5, t));
	color = mix(color, c3, smoothstep(0.5, 0.75, t));
	color = mix(color, c4, smoothstep(0.75, 1.0, t));
	return color;
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

// Detector radii. The mine, state and nomad keys are matched tightly: those
// branches replace the pixel outright, so a loose radius would paint the
// wrong colour over unrelated pixels. The body fill gets a wider radius: a
// cooling corpse's fill fades by alpha, which drags the pixel away from the
// pure key, so a tight radius would lose the fill while the body dissolves.
const float DET_TOL_CORE = 0.22;
const float DET_TOL_FILL = 0.40;

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
		// Pick whichever key is CLOSEST: with a wide tolerance two keys'
		// ranges can overlap on a single pixel, and an if/elif chain would
		// let an earlier check steal matches that belong to a later key.
		// The fill has its own (wider) radius, so the keys are reduced in two
		// groups: a pixel inside the fill radius but outside the tight one is
		// still a fill.
		float dMine = orbitDist(pixelColor.rgb, mineKey);
		float dStN = orbitDist(pixelColor.rgb, stNormalKey);
		float dStC = orbitDist(pixelColor.rgb, stCombatKey);
		float dStD = orbitDist(pixelColor.rgb, stDefendKey);
		float dFiN = orbitDist(pixelColor.rgb, fillNormKey);
		float dFiC = orbitDist(pixelColor.rgb, fillCombKey);
		float dFiD = orbitDist(pixelColor.rgb, fillDefKey);
		float dNom = orbitDist(pixelColor.rgb, nomadKey);
		float dCore = min(dMine, min(dStN, min(dStC, min(dStD, dNom))));
		float dFill = min(dFiN, min(dFiC, dFiD));
		bool coreHit = dCore < DET_TOL_CORE;
		bool fillHit = dFill < DET_TOL_FILL;

		{
			float rawLuminance = dot(pixelColor.rgb, vec3(0.299, 0.587, 0.114));
			float luminance = clamp(rawLuminance * thermalDarken, 0.0, 1.0);
			vec3 backgroundColor = ThermalPalette(luminance) * 0.7;
			if (coreHit || fillHit) {
				// Closest wins. Inside the core group the order is mine,
				// state, nomad (exact ties only). The fill is separate: it is
				// translucent -- it mixes the display colour over the palette
				// instead of replacing it.
				if (coreHit && dCore <= dFill) {
					if (dCore == dMine) {
						color = vec4(mineColor, pixelColor.a);
					} else if (dCore == dStN) {
						color = vec4(stNormalColor * stateBright, pixelColor.a);
					} else if (dCore == dStC) {
						color = vec4(stCombatColor * stateBright, pixelColor.a);
					} else if (dCore == dStD) {
						color = vec4(stDefendColor * stateBright, pixelColor.a);
					} else {
						color = vec4(nomadColor, pixelColor.a);
					}
				} else {
					vec3 fillColor;
					if (dFill == dFiN) {
						fillColor = fillNormColor;
					} else if (dFill == dFiC) {
						fillColor = fillCombColor;
					} else {
						fillColor = fillDefColor;
					}
					color = vec4(mix(backgroundColor, fillColor, fillOpacity), pixelColor.a);
				}
			} else {
				color = vec4(backgroundColor, pixelColor.a);
			}
		}
	} else {
		color = pixelColor * tint;
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
