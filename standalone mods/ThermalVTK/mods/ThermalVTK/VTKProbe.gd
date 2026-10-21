extends RefCounted
# Debug key probe. Reads the colour of the pixel under the crosshair, so the
# post-NVG colour of a key (body fill, nomad marker) can be measured in game
# and pasted into the detector constants. The helpers stay free of tree
# access, so they run headless (test_probe.gd); only read_center touches the
# viewport.

# The crosshair sits in the middle of the screen, so the probe reads the
# middle pixel of the frame.
static func center_pixel(size: Vector2i) -> Vector2i:
	return Vector2i(size.x / 2, size.y / 2)

static func format(rgb: Color, key_hint: String) -> String:
	return "probe %s rgb=(%.3f, %.3f, %.3f)" % [key_hint, rgb.r, rgb.g, rgb.b]

# Grabs the frame and returns the colour of its centre pixel. A drawn frame is
# required, so the readback waits for the next post-draw. Alpha 0 marks a
# frame that could not be read.
static func read_center(viewport: Viewport) -> Color:
	await RenderingServer.frame_post_draw
	if viewport == null or not is_instance_valid(viewport):
		return Color(0.0, 0.0, 0.0, 0.0)
	var tex := viewport.get_texture()
	if tex == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var img := tex.get_image()
	if img == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	return img.get_pixelv(center_pixel(img.get_size()))
