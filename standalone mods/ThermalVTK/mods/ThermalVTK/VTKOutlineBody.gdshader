shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;

// Body fill for the contour ESP. A KEY shader: it paints the category's fill
// key colour, which the NVG overlay detects and swaps for the state display
// colour. `cool` fades a corpse out -- only the alpha drops to zero, so the
// body dissolves in place. The albedo stays the PURE key: the overlay
// detects the key, so a dimmed key would be missed and the corpse would fall
// back to the false-colour palette mid-fade. The fill is opaque here; its
// on-screen density is applied by the overlay's fillOpacity, keeping the
// pixel detectable. `fill_on` switches the body off: the alpha drops to zero,
// so the body paints no key pixel at all and the NPC keeps its native thermal
// look -- only the ring (this material's next_pass) still draws. Faking it
// with fillOpacity = 0 would not do it: the overlay would still read the fill
// pixel and replace it with a palette colour derived from that pixel's own
// luminance, leaving an opaque blob over the NPC. The fill is depth-tested
// against the world like any other surface: it only shows where the NPC is
// actually in view.
uniform vec3 fill_key : source_color = vec3(0.0, 0.35, 1.0);
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform bool fill_on = true;
uniform float footY = 0.0;
uniform float bodyHeight = 1.8;

void fragment() {
	ALBEDO = fill_key;
	ALPHA = fill_on ? (1.0 - cool) : 0.0;
}
