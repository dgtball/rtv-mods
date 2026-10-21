shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

// Body fill for the contour ESP. A KEY shader: it paints the category's fill
// key colour, which the NVG overlay detects and swaps for the state display
// colour. `cool` fades a corpse out -- only the alpha drops to zero, so the
// body dissolves in place. The albedo stays the PURE key: the overlay
// detects the key, so a dimmed key would be missed and the corpse would fall
// back to the false-colour palette mid-fade. The fill is opaque here; its
// on-screen density is applied by the overlay's fillOpacity, keeping the
// pixel detectable. The fill is depth-tested against the world like any
// other surface: it only shows where the NPC is actually in view.
uniform vec3 fill_key : source_color = vec3(0.0, 0.35, 1.0);
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;

void fragment() {
	ALBEDO = fill_key;
	ALPHA = 1.0 - cool;
}
