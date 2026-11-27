shader_type spatial;
render_mode depth_draw_always, specular_disabled, unshaded;

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = 1.0;
}
