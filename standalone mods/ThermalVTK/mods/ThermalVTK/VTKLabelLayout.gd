extends RefCounted
# Pure screen-space layout for the 2D nametag overlay: no scene, no camera, no
# load(). Points in, rectangles out, so the vertical rhythm (diamond above the
# head, the stack under it, the lines below the feet) is testable headless.

# Height of one text line: the font plus the gap to the next line.
const LINE_H := 17.0
const DIAMOND_HALF := 18.0
# Health bar: how tall it is and the gap to the text above it.
const BAR_H := 3.0
const BAR_GAP := 2.0
# Gap between the diamond tip and the text stack.
const GAP_DIAMOND := 6.0
# The block sits this far above the projected head point, so its bottom edge
# lands just above the bot instead of covering the face.
const GAP_HEAD := 10.0
# Gap between the projected feet and the lines drawn under them.
const GAP_FEET := 6.0
# Free space kept at the top and bottom of the screen.
const SCREEN_MARGIN := 8.0

# Height of the text lines alone (name, plus the state line when it shows).
static func text_height(has_status: bool) -> float:
	return LINE_H * (2.0 if has_status else 1.0)

# Top of the text stack. `head` is the projected head point. With a diamond
# the stack starts under the diamond (it never covers the diamond, never
# crosses onto the bot). Without a diamond it hangs the GAP_HEAD above the
# head.
static func block_top(head: Vector2, has_status: bool, diamond: bool) -> Vector2:
	var base := head.y - GAP_HEAD - BAR_GAP - BAR_H - text_height(has_status)
	if diamond:
		var under_diamond := head.y - DIAMOND_HALF + GAP_DIAMOND
		if under_diamond > base:
			base = under_diamond
	var clamped := base
	if clamped < SCREEN_MARGIN:
		clamped = SCREEN_MARGIN
	return Vector2(head.x, clamped)

# Vertical offset of the health bar from the top of the text stack.
static func bar_top_offset(has_status: bool) -> float:
	return text_height(has_status) + BAR_GAP

# Top-left corner of the health bar.
static func bar_rect(top: Vector2, width: float, has_status: bool) -> Rect2:
	return Rect2(Vector2(top.x - width * 0.5, top.y + bar_top_offset(has_status)), Vector2(width, BAR_H))
