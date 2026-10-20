shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Body fill for the contour ESP. Same cooling-ladder idea as VTKBot.gdshader,
// but this is a DISPLAY shader: it paints warm/mid/cold colours directly onto
// material_overlay (mode A hides the bot keys, so nothing detects them on the
// NVG screen). `cool` drives the cold front down the body as a corpse cools.
// `flash` mixes toward flash_color when the NPC's sensor sees the player.
// The `depth_test_disabled` token is stripped at load to build the LOS variant.
uniform vec3 warmColor : source_color = vec3(0.6, 0.48, 0.09);
uniform vec3 midColor : source_color = vec3(0.55, 0.45, 0.28);
uniform vec3 coldColor : source_color = vec3(0.28, 0.3, 0.4);
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;
uniform float band = 0.28;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flash : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	float worldY = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
	float h = clamp((worldY - footY) / bodyHeight, 0.0, 1.0);
	float coldFront = 1.35 - cool * 1.7;
	float midFront = coldFront - band;
	vec3 col = warmColor;
	if (h > coldFront) {
		col = coldColor;
	} else if (h > midFront) {
		col = midColor;
	}
	col = mix(col, flash_color, flash);
	ALBEDO = col;
	ALPHA = fill_alpha;
}
