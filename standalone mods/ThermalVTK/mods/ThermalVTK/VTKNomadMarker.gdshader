shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

// Friendly-nomad marker. A KEY shader: it paints the nomad key colour, which
// the NVG overlay detects and swaps for the green display colour. The mesh is a
// billboarded diamond quad (VTKESP._marker_make). The marker is depth-tested
// against the world like any other surface: it does not read through walls.
uniform vec3 nomad_key : source_color = vec3(0.6, 1.0, 0.6);

void vertex() {
	// Camera-facing billboard. MeshInstance3D has no billboard property in
	// Godot 4 (billboarding is a material feature, and this is a shader
	// material), so the quad is turned to face the camera here: its local axes
	// follow the camera's and it keeps the node's world position.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(INV_VIEW_MATRIX[0].xyz, 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz, 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz, 0.0),
		vec4(MODEL_MATRIX[3].xyz, 1.0));
}

void fragment() {
	// Cut the quad into a diamond so it reads as a small marker, not a square.
	vec2 p = UV * 2.0 - 1.0;
	if (abs(p.x) + abs(p.y) > 1.0) {
		discard;
	}
	ALBEDO = nomad_key;
	ALPHA = 1.0;
}
