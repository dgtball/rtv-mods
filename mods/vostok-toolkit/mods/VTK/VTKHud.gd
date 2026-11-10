extends RefCounted
## Общие части HUD-виджетов счётчика убийств и ленты: подложка-плашка,
## чтение убежища из gameData и каденция тика 0.5 с. Обе копии расходились
## молча (порядок _reseed в §4.4 аудита), поэтому правила живут здесь.

const PLATE_ALPHA := 0.45
const PLATE_PAD_X := 6.0
const TICK_SEC := 0.5

static func plaque_style(top: float = 0.0, bottom: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, PLATE_ALPHA)
	sb.content_margin_left = PLATE_PAD_X
	sb.content_margin_right = PLATE_PAD_X
	sb.content_margin_top = top
	sb.content_margin_bottom = bottom
	return sb

static func in_shelter(iface) -> bool:
	if iface == null:
		return false
	var gd = iface.get("gameData")
	if gd == null:
		return false
	return bool(gd.get("shelter"))

class Ticker extends RefCounted:
	var accum: float = 0.0
	var interval: float = TICK_SEC

	func _init(step_sec: float = TICK_SEC) -> void:
		interval = step_sec

	func step(delta: float) -> bool:
		accum += delta
		if accum < interval:
			return false
		accum = 0.0
		return true

const GROW_END := Control.GROW_DIRECTION_END
const GROW_BEGIN := Control.GROW_DIRECTION_BEGIN
const GROW_BOTH := Control.GROW_DIRECTION_BOTH

const ANCHOR_KEYS := ["top_left", "top_center", "top_right", "bottom_left", "bottom_center", "bottom_right"]

static func anchor_layout(preset: String) -> Dictionary:
	var ax := 0.0
	var ay := 0.0
	var grow_h := GROW_END
	var grow_v := GROW_END
	var sx := 1
	var sy := 1
	match preset:
		"top_left":
			pass
		"top_center":
			ax = 0.5
			grow_h = GROW_BOTH
		"top_right":
			ax = 1.0
			grow_h = GROW_BEGIN
			sx = -1
		"center_left":
			ay = 0.5
			grow_v = GROW_BOTH
		"center":
			ax = 0.5
			ay = 0.5
			grow_h = GROW_BOTH
			grow_v = GROW_BOTH
		"center_right":
			ax = 1.0
			ay = 0.5
			grow_h = GROW_BEGIN
			grow_v = GROW_BOTH
			sx = -1
		"bottom_left":
			ay = 1.0
			grow_v = GROW_BEGIN
			sy = -1
		"bottom_center":
			ax = 0.5
			ay = 1.0
			grow_h = GROW_BOTH
			grow_v = GROW_BEGIN
			sy = -1
		"bottom_right":
			ax = 1.0
			ay = 1.0
			grow_h = GROW_BEGIN
			grow_v = GROW_BEGIN
			sx = -1
			sy = -1
		_:
			pass
	return {
		"anchor": Vector2(ax, ay),
		"grow_h": grow_h,
		"grow_v": grow_v,
		"sx": sx,
		"sy": sy,
	}

static func place_block(rect: Control, preset: String, offset_x: float, offset_y: float) -> void:
	if rect == null:
		return
	var l := anchor_layout(preset)
	var a: Vector2 = l["anchor"]
	rect.anchor_left = a.x
	rect.anchor_right = a.x
	rect.anchor_top = a.y
	rect.anchor_bottom = a.y
	rect.offset_left = float(int(l["sx"]) * int(offset_x))
	rect.offset_right = float(int(l["sx"]) * int(offset_x))
	rect.offset_top = float(int(l["sy"]) * int(offset_y))
	rect.offset_bottom = float(int(l["sy"]) * int(offset_y))
	rect.grow_horizontal = int(l["grow_h"])
	rect.grow_vertical = int(l["grow_v"])
static func place_feed(root: Control, preset: String, offset_x: float, offset_y: float, font_size: float = 17.0) -> void:
	if root == null:
		return
	const line_width := 420.0
	const max_entries := 5
	var width := line_width
	var height := float(max_entries * (int(font_size) + 18))
	var left := 0.0
	var top := 0.0
	match preset:
		"top_left":
			root.anchor_left = 0.0
			root.anchor_right = 0.0
			root.anchor_top = 0.0
			root.anchor_bottom = 0.0
			left = offset_x
			top = offset_y
		"top_center":
			root.anchor_left = 0.5
			root.anchor_right = 0.5
			root.anchor_top = 0.0
			root.anchor_bottom = 0.0
			left = offset_x - (width * 0.5)
			top = offset_y
		"top_right":
			root.anchor_left = 1.0
			root.anchor_right = 1.0
			root.anchor_top = 0.0
			root.anchor_bottom = 0.0
			left = -offset_x - width
			top = offset_y
		"center_left":
			root.anchor_left = 0.0
			root.anchor_right = 0.0
			root.anchor_top = 0.5
			root.anchor_bottom = 0.5
			left = offset_x
			top = offset_y - (height * 0.5)
		"center":
			root.anchor_left = 0.5
			root.anchor_right = 0.5
			root.anchor_top = 0.5
			root.anchor_bottom = 0.5
			left = offset_x - (width * 0.5)
			top = offset_y - (height * 0.5)
		"center_right":
			root.anchor_left = 1.0
			root.anchor_right = 1.0
			root.anchor_top = 0.5
			root.anchor_bottom = 0.5
			left = -offset_x - width
			top = offset_y - (height * 0.5)
		"bottom_left":
			root.anchor_left = 0.0
			root.anchor_right = 0.0
			root.anchor_top = 1.0
			root.anchor_bottom = 1.0
			left = offset_x
			top = -offset_y - height
		"bottom_center":
			root.anchor_left = 0.5
			root.anchor_right = 0.5
			root.anchor_top = 1.0
			root.anchor_bottom = 1.0
			left = offset_x - (width * 0.5)
			top = -offset_y - height
		"bottom_right":
			root.anchor_left = 1.0
			root.anchor_right = 1.0
			root.anchor_top = 1.0
			root.anchor_bottom = 1.0
			left = -offset_x - width
			top = -offset_y - height
		_:
			root.anchor_left = 0.0
			root.anchor_right = 0.0
			root.anchor_top = 0.0
			root.anchor_bottom = 0.0
			left = offset_x
			top = offset_y
	root.offset_left = left
	root.offset_right = left + width
	root.offset_top = top
	root.offset_bottom = top + height
	root.custom_minimum_size = Vector2(width, 0.0)

static func row_height(font_size: float) -> float:
	return font_size + 6.0

static func icon_size(font_size: float) -> float:
	return font_size - 1.0

static func hs_fallback_size(font_size: int) -> int:
	return maxi(8, font_size - 6)