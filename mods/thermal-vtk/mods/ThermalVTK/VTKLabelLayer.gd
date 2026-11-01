extends Control

# 2D overlay Control: NPC nametags (debug log only) and the friendly-nomad
# diamond (independent `nomad_marker`). Lives on a CanvasLayer(layer=1) built
# by VTKESP so it is drawn after the thermal shader.

const FONT_SIZE := 14

var _items: Array = []
var _diamonds: Array = []
var _visible_has_content: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_IGNORE
	name = "VTKLabelLayer"

func set_frame(items: Array, diamonds: Array) -> void:
	_items = items
	_diamonds = diamonds
	_visible_has_content = (not _items.is_empty()) or (not _diamonds.is_empty())
	visible = _visible_has_content
	queue_redraw()

func clear() -> void:
	_items = []
	_diamonds = []
	_visible_has_content = false
	visible = false
	queue_redraw()

func _draw() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var font := get_theme_default_font()
	if font == null:
		return
	const MARKER_R := 12.0
	const LINE_H := 17.0
	const HEAD_GAP := 10.0
	var vs := get_viewport_rect().size

	# Diamonds first (behind text).
	var diamond_color := Color(0.30, 1.0, 0.35)
	for d in _diamonds:
		var vis: bool = bool(d["visible"])
		if not vis:
			continue
		var anchor: Vector3 = d["anchor"]
		if cam.is_position_behind(anchor):
			continue
		var p := cam.unproject_position(anchor)
		# A marker projected onto the camera plane comes back as inf, and a
		# polygon with non-finite or wildly off-screen points fails Godot's
		# triangulation (canvas_item_add_polygon -> Invalid polygon data).
		if not is_finite(p.x) or not is_finite(p.y):
			continue
		if p.x < -64.0 or p.y < -64.0 or p.x > vs.x + 64.0 or p.y > vs.y + 64.0:
			continue
		var r := MARKER_R
		# Inverted triangle: the tip points at the head, so the marker reads as
		# "this NPC" and cannot be mistaken for a mine.
		var poly := PackedVector2Array([p + Vector2(0.0, r), p + Vector2(-r * 0.9, -r * 0.7), p + Vector2(r * 0.9, -r * 0.7)])
		draw_colored_polygon(poly, diamond_color)
		var outline_pts := PackedVector2Array([poly[0], poly[1], poly[2], poly[0]])
		draw_polyline(outline_pts, Color(0.0, 0.0, 0.0, 0.85), 1.5)

	# Items over the diamond.
	for it in _items:
		var color: Color = it["color"]
		var anchor: Vector3 = it["anchor"]
		if cam.is_position_behind(anchor):
			continue
		var screen := cam.unproject_position(anchor)
		if not is_finite(screen.x) or not is_finite(screen.y):
			continue
		if screen.x < -64.0 or screen.y < -64.0 or screen.x > vs.x + 64.0 or screen.y > vs.y + 64.0:
			continue
		var header: String = str(it["header"])
		var status_txt: String = str(it["status"])
		var suffix_txt: String = str(it["suffix"])
		var alpha: float = 1.0
		var dist_m: float = float(it["dist"]) if it.has("dist") else 0.0
		var dist_cap: float = float(it["dist_cap"]) if it.has("dist_cap") else 1.0
		if dist_cap > 0.0:
			alpha = clampf(1.0 - (dist_m / dist_cap) * 0.3, 0.7, 1.0)
		var c: Color = Color(color.r, color.g, color.b, color.a * alpha)
		var text_h: float = LINE_H
		if status_txt != "":
			text_h += LINE_H
		var head_y := screen.y - text_h - HEAD_GAP + LINE_H
		var origin_h := Vector2(screen.x - font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, head_y)
		draw_string_outline(font, origin_h, header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, origin_h, header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
		if status_txt != "":
			var origin_s := Vector2(screen.x - font.get_string_size(status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, head_y + LINE_H)
			draw_string_outline(font, origin_s, status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
			draw_string(font, origin_s, status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
		# One line under the feet: the trigger timer, when one is live, followed by
		# the health readout -- "[walk 1.0s 5m] [HP: 64]".
		var hp_txt: String = str(it["hp"]) if it.has("hp") else ""
		var foot_txt: String = suffix_txt
		if hp_txt != "":
			foot_txt = (foot_txt + " " + hp_txt).strip_edges()
		if foot_txt != "":
			var feet_anchor: Vector3 = it["feet"] if it.has("feet") else anchor
			var feet_y := screen.y
			if not cam.is_position_behind(feet_anchor):
				feet_y = cam.unproject_position(feet_anchor).y
			var origin_f := Vector2(screen.x - font.get_string_size(foot_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, feet_y + 4.0)
			draw_string_outline(font, origin_f, foot_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
			draw_string(font, origin_f, foot_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
