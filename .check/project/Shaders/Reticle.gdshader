shader_type spatial;
render_mode shadows_disabled;
uniform sampler2D reticle : repeat_disable;

void fragment() {
	ALBEDO = texture(reticle, UV).rgb;
	ALPHA = 1.0;
}
