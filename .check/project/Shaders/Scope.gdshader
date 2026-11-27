shader_type spatial;
render_mode depth_draw_always, specular_disabled, unshaded;

varying vec3 worldNormal;

void vertex() {
	worldNormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	ALBEDO = vec3(1.0);
	ALPHA = 1.0;
}
