shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
stencil_mode read, compare_not_equal, 1;

// Ring pass of the contour overlay (VTKOutline). The shell writes the category
// key colour into the main 3D pass, so the pixel in the screen itself carries
// the category; the NVG overlay matches that washed key and replaces the pixel
// with the display colour (VTKNVG.gdshader, DET_ST_* in VTKNVG.gd). The stencil
// read is a no-op when no body pass ran (the buffer is 0, and 0 != 1 passes),
// so this single shader serves both the plain ring and the outside-the-fill
// band.

uniform vec3 state_color : source_color = vec3(1.0, 0.0, 0.0);
// Daylight compensation lowers the game's exposure; the key is scaled back by
// the same factor before the tonemap, so its on-screen colour stays the
// night-time value the detector was calibrated against.
global uniform float vtk_key_gain = 1.0;
uniform float grow : hint_range(0.0, 0.15, 0.001) = 0.006;
uniform float rim_power : hint_range(0.0, 6.0, 0.1) = 2.0;
uniform float cool : hint_range(0.0, 1.0, 0.01) = 0.0;

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - facing;
	float a = 1.0;
	if (rim_power > 0.01) {
		a = pow(edge, rim_power);
	}
	ALBEDO = state_color * vtk_key_gain;
	ALPHA = a * (1.0 - cool);
}
