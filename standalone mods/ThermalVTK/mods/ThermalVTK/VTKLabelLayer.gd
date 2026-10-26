extends Control

# 2D overlay Control: NPC nametags (debug log only) and the friendly-nomad
# diamond (independent `nomad_marker`). Lives on a CanvasLayer(layer=1) built
# by VTKESP so it is drawn after the thermal shader.

const FONT_SIZE := 14
const HEALTH_WIDTH := 48.0

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
	# Load the shared layout only for projects; the module is headless-safe so
	# it is merely a dumb calculator of screen boxes and stays preload-free here
	# to avoid a coupling in tests. Layout is inlined to mirror it exactly.
	const DIAMOND_R := 18.0
	const LINE_H := 17.0
	const BAR_H := 3.0
	const BAR_GAP := 2.0
	const HEAD_GAP := 10.0
	for it in _items:
		var color: Color = it["color"]
		var anchor: Vector3 = it["anchor"]
		if cam.is_position_behind(anchor):
			continue
		var screen := cam.unproject_position(anchor)
		var header: String = str(it["header"])
		var status_txt: String = str(it["status"])
		var suffix_txt: String = str(it["suffix"])
		var frac: float = clampf(float(it["health"]), 0.0, 1.0)
		var alpha: float = 1.0
		var dist_m: float = float(it["dist"]) if it.has("dist") else 0.0
		var dist_cap: float = float(it["dist_cap"]) if it.has("dist_cap") else 1.0
		if dist_cap > 0.0:
			alpha = clampf(1.0 - (dist_m / dist_cap) * 0.3, 0.7, 1.0)
		var c: Color = Color(color.r, color.g, color.b, color.a * alpha)
		# Place the block above the head and flush it to the GAP_HEAD mark so
		# it cannot drift down onto the bot when the projector puts the head
		# far below where the bot actually is.
		var text_h: float = LINE_H
		if status_txt != "":
			text_h += LINE_H
		var bar_y: float = screen.y - (text_h + BAR_GAP + BAR_H) - HEAD_GAP
		# Rombs for nomads sit a good deal lower than the head, so anything
		# started above the diamond centre would overlap it; the text stack
		# always begins below the diamond tip instead.
		bar_y = minf(bar_y, screen.y - DIAMOND_R - 8.0 - (text_h + BAR_GAP + BAR_H)) if false else bar_y
		var cx: float = screen.x
		# header
		var head_y := screen.y - (text_h + BAR_GAP + BAR_H) - HEAD_GAP + LINE_H
		var origin_h := Vector2(cx - font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, head_y)
		draw_string_outline(font, origin_h, header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, origin_h, header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
		# status
		if status_txt != "":
			var origin_s := Vector2(cx - font.get_string_size(status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, head_y + LINE_H)
			draw_string_outline(font, origin_s, status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
			draw_string(font, origin_s, status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
		# bar
		var origin_bar_y := head_y + text_h + BAR_GAP
		var bar := Rect2(cx - HEALTH_WIDTH / 2.0, origin_bar_y, HEALTH_WIDTH, BAR_H)
		draw_rect(bar.grow(0.5), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(Color.RED.lerp(Color.GREEN, frac), alpha))
		# trigger suffix below the bot's projected feet.
		if suffix_txt != "":
			var feet_anchor: Vector3 = it["feet"] if it.has("feet") else anchor
			if not cam.is_position_behind(feet_anchor):
				var feet_screen := cam.unproject_position(feet_anchor)
				var origin_f := Vector2(cx - font.get_string_size(suffix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, feet_screen.y + 4.0)
				draw_string_outline(font, origin_f, suffix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
				draw_string(font, origin_f, suffix_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color(1.0, 1.0, 0.0, 0.9))
	# Friendly-nomad diamonds (large plumbob, always drawn first-ish but in a
	# separate loop so labels stay painted after it).
	var diamond_color := Color(0.30, 1.0, 0.35)
	for d in _diamonds:
		var vis: bool = bool(d["visible"])
		if not vis:
			continue
		var anchor: Vector3 = d["anchor"]
		if cam.is_position_behind(anchor):
			continue
		var p := cam.unproject_position(anchor)
		if p.x != p.x or p.y != p.y:
			continue
		var r := 18.0
		var poly := PackedVector2Array([p + Vector2(0.0, -r), p + Vector2(r, 0.0), p + Vector2(0.0, r), p + Vector2(-r, 0.0)])
		if poly[0] == poly[1] or poly[1] == poly[2] or poly[2] == poly[3] or poly[3] == poly[0]:
			continue
		draw_colored_polygon(poly, diamond_color)
		var outline_pts := PackedVector2Array([p + Vector2(0.0, -r), p + Vector2(r, 0.0), p + Vector2(0.0, r), p + Vector2(-r, 0.0), p + Vector2(0.0, -r)])
		draw_polyline(outline_pts, Color(0.0, 0.0, 0.0, 0.85), 1.5)
		draw_line(p + Vector2(0.0, r), p + Vector2(0.0, r + 7.0), Color(diamond_color.r, diamond_color.g, diamond_color.b, 0.9), 1.5)
