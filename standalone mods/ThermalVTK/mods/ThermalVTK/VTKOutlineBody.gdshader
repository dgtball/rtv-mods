shader_type spatial;
render_mode unshaded, cull_back, depth_test_disabled, depth_draw_never;

// Body fill for the contour ESP. A DISPLAY shader: it paints the NPC's state
// colour (a flat tint set per NPC from VTKESP._opts_for) onto material_overlay.
// `cool` fades a corpse out -- albedo dims and alpha drops to zero as the body
// cools, so outline and fill disappear together. `bodyHeight` keeps the fade
// independent of the mesh's own vertical scale. The `depth_test_disabled`
// token is stripped at load to build the LOS variant (VTKShaders.gd).
uniform vec3 fillColor : source_color = vec3(1.0, 0.72, 0.28);
uniform float fill_alpha : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;

void fragment() {
	ALBEDO = fillColor * mix(1.0, 0.15, cool);
	ALPHA = fill_alpha * (1.0 - cool);
}
