shader_type spatial;

// Depth-only occluder for the ESP buffer. It must render before the contour
// shells and write depth without leaving any colour behind: non-X-ray contours
// then pass the same wall/weapon depth test they had in the main 3D pass.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always;

void fragment() {
	ALBEDO = vec3(0.0);
	ALPHA = 0.0;
}
