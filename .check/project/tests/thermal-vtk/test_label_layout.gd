extends SceneTree

const L = preload("res://mods/ThermalVTK/VTKLabelLayout.gd")

# The overlay stacks every line of a nametag; these tests pin the vertical
# rhythm so a diamond can never cover the text and the block can never slide
# down onto the bot.

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_text_height()
	t_head_gap()
	t_diamond_clearance()
	t_bar_below_text()
	t_screen_margin()
	print("")
	if fails == 0:
		print("tests passed")
		quit(0)
	else:
		print("Labels layout tests failed: ", fails)
		quit(1)

func t_text_height() -> void:
	ck(near(L.text_height(true), L.LINE_H * 2.0), "name and state are two lines")
	ck(near(L.text_height(false), L.LINE_H), "a nameless state collapses to one line")

# The bar plus the head gap close the block; nothing of it reaches the bot.
func t_head_gap() -> void:
	var head := Vector2(960.0, 470.0)
	for has_status in [true, false]:
		var top := L.block_top(head, has_status, false)
		var bar := L.bar_rect(top, 48.0, has_status)
		ck(near(head.y - bar.end.y, L.GAP_HEAD), "the bar ends the GAP_HEAD above the head")
		ck(top.y < head.y, "the stack stays above the head point")

# A nomad has a diamond: the stack hangs under the diamond tip instead of
# running into it.
func t_diamond_clearance() -> void:
	var head := Vector2(960.0, 470.0)
	var plain := L.block_top(head, true, false)
	var diamond := L.block_top(head, true, true)
	ck(diamond.y >= plain.y, "a diamond pushes the stack down by its half plus a gap")
	ck(diamond.y >= head.y - L.DIAMOND_HALF, "the stack stays under the diamond centre")

func t_bar_below_text() -> void:
	var head := Vector2(400.0, 300.0)
	var top := L.block_top(head, true, false)
	var bar := L.bar_rect(top, 48.0, true)
	ck(bar.position.y >= top.y + L.LINE_H * 2.0, "the health bar sits below the name and state")
	ck(near(bar.get_center().x, head.x), "the bar is centred on the marker")
	ck(near(L.bar_top_offset(true), L.LINE_H * 2.0 + L.BAR_GAP), "the bar offset follows the state line")

func t_screen_margin() -> void:
	var top := L.block_top(Vector2(100.0, 20.0), true, true)
	ck(top.y >= L.SCREEN_MARGIN, "a bot at the top of the screen keeps its stack on screen")
