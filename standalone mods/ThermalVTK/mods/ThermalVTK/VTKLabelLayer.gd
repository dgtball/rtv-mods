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
	# Items: name/distance followed by state/reloading/vs; health bar under.
	for it in _items:
		var anchor: Vector3 = it["anchor"]
		if cam.is_position_behind(anchor):
			continue
		var screen := cam.unproject_position(anchor)
		var color: Color = it["color"]
		var header: String = str(it["header"])
		var status_txt: String = str(it["status"]) + str(it["suffix"])
		var frac: float = clampf(float(it["health"]), 0.0, 1.0)
		var alpha: float = 1.0
		var dist_m: float = float(it["dist"]) if it.has("dist") else 0.0
		var dist_cap: float = float(it["dist_cap"]) if it.has("dist_cap") else 1.0
		if dist_cap > 0.0:
			alpha = clampf(1.0 - (dist_m / dist_cap) * 0.3, 0.7, 1.0)
		var c: Color = Color(color.r, color.g, color.b, color.a * alpha)
		# header line
		var origin_h := Vector2(screen.x - font.get_string_size(header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, screen.y)
		draw_string_outline(font, origin_h, header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, origin_h, header, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c)
		# status line
		var origin_s := Vector2(screen.x - font.get_string_size(status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x / 2.0, screen.y + FONT_SIZE + 2)
		draw_string_outline(font, origin_s, status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, 4, Color(0.0, 0.0, 0.0, 0.85))
		draw_string(font, origin_s, status_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, c, 0)
		# health bar
		var bar_y := screen.y + (FONT_SIZE + 2) * 2 + 2
		var bar := Rect2(screen.x - HEALTH_WIDTH / 2.0, bar_y, HEALTH_WIDTH, 3.0)
		draw_rect(bar.grow(0.5), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), Color(Color.RED.lerp(Color.GREEN, frac), alpha))
	# Diamonds (friendly nomads).
	var diamond_color := Color(0.30, 1.0, 0.35)
	for d in _diamonds:
		var vis: bool = bool(d["visible"])
		if not vis:
			continue
		var anchor: Vector3 = d["anchor"]
		if cam.is_position_behind(anchor):
			continue
		var p := cam.unproject_position(anchor)
		var r := 13.0
		if p.x != p.x or p.y != p.y:
			continue
		var poly := PackedVector2Array([p + Vector2(0.0, -r), p + Vector2(r, 0.0), p + Vector2(0.0, r), p + Vector2(-r, 0.0)])
		if poly[0] == poly[1] or poly[1] == poly[2] or poly[2] == poly[3] or poly[3] == poly[0]:
			continue
		draw_colored_polygon(poly, diamond_color)
		var outline_pts := PackedVector2Array([p + Vector2(0.0, -r), p + Vector2(r, 0.0), p + Vector2(0.0, r), p + Vector2(-r, 0.0), p + Vector2(0.0, -r)])
		draw_polyline(outline_pts, Color(0.0, 0.0, 0.0, 0.85), 1.2)
