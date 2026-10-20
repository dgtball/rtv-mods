shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Body fill for the contour ESP. A DISPLAY shader: it paints the NPC's state
// colour (flat, fill_style 0) or a vertical thermal ramp (fill_style 1) onto
// material_overlay. `cool` fades a corpse out -- albedo dims and alpha drops to
// zero as the body cools, so outline and fill disappear together. The
// `depth_test_disabled` token is stripped at load to build the LOS variant
// (VTKShaders.gd).
uniform vec3 fillColor : source_color = vec3(1.0, 0.72, 0.28);
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform int fill_style = 0;
uniform vec3 warmColor : source_color = vec3(1.0, 0.95, 0.7);
uniform vec3 coldColor : source_color = vec3(0.05, 0.05, 0.12);
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;

void fragment() {
	if (fill_style == 1) {
		// Vertical thermal ramp: warm at the feet, cold at the head. The state
		// colour is mixed over it by fill_alpha.
		float h = clamp((VERTEX.y - footY) / max(bodyHeight, 0.001), 0.0, 1.0);
		vec3 thermal = mix(warmColor, coldColor, h);
		ALBEDO = mix(thermal, fillColor, fill_alpha) * mix(1.0, 0.15, cool);
	} else {
		ALBEDO = fillColor * mix(1.0, 0.15, cool);
	}
	ALPHA = fill_alpha * (1.0 - cool);
}
