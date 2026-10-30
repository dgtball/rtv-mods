extends SceneTree

const Look = preload("res://mods/VTK/VTKLook.gd")
const VTKSurface = preload("res://mods/VTK/VTKSurface.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	process_frame.connect(_run)

func _run() -> void:
	t_window_size()
	t_window_toast_gap()
	t_header_fits_min_window()
	t_window_degenerate()
	t_flow_columns()
	t_card_head()
	t_card()
	t_palette()
	t_tab_style()
	t_lock_icon()
	print("")
	if fails == 0:
		print("Look tests passed")
		quit(0)
	else:
		print("Look tests failed: ", fails)
		quit(1)

func t_window_size() -> void:
	ck(Look.window_size(Vector2(1280, 720)) == Vector2(960, 500), "1280x720 -> 960x500")
	ck(Look.window_size(Vector2(1600, 900)) == Vector2(1200, 680), "1600x900 -> 1200x680")
	ck(Look.window_size(Vector2(1920, 1080)) == Vector2(1200, 840), "1920x1080 -> 1200x840")
	ck(Look.window_size(Vector2(1440, 1080)) == Vector2(1120, 840), "1440x1080 -> 1120x840")
	# Инвариант высоты: внутри окна остаётся h - 73 (врезки 20 + рейл 40 +
	# разделитель 1 + два зазора 6), а странице «Готово» нужно 740.
	ck(Look.window_size(Vector2(1920, 1080)).y - 73.0 >= 740.0,
		"на 1080p «Готово» влезает без прокрутки")
	ck(Look.window_size(Vector2(800, 600)) == Vector2(720, 400), "800x600 -> 720x400")
	ck(Look.window_size(Vector2(640, 480)) == Vector2(624, 400), "640x480 -> 624x400 (зажим view-16)")

func t_window_toast_gap() -> void:
	# Полоса тостов растёт вверх от нижней кромки (~102px на две плашки). Окно
	# центрировано, поэтому нижний зазор = (view.y - h) / 2: он обязан быть
	# >= 110, кроме случая, когда h уже зажат полом H_MIN.
	var views := [Vector2(1280, 720), Vector2(1600, 900), Vector2(1920, 1080),
		Vector2(800, 600), Vector2(640, 480)]
	for v in views:
		var h: float = Look.window_size(v).y
		var gap: float = (v.y - h) * 0.5
		ck(gap >= 110.0 or h <= Look.H_MIN,
			"зазор под тосты %.0f при %.0fx%.0f" % [gap, v.x, v.y])

func t_header_fits_min_window() -> void:
	# Внутри окна остаётся W_MIN - 20 (врезки фрейма по 10): знак с заголовком
	# слева, вкладки по центру, версия с крестиком справа обязаны влезть.
	var need := 2.0 * Look.HEADER_SIDE + 2.0 * Look.TAB_W + 4.0 + 16.0
	ck(need <= Look.W_MIN - 20.0, "шапка влезает в минимальное окно 720")
	ck(Look.TAB_H == Look.RAIL_H, "вкладка и рейл одной высоты")

func t_window_degenerate() -> void:
	# Вырожденный вьюпорт не должен дать отрицательный размер окна.
	var w := Look.window_size(Vector2(10, 10))
	ck(w.x > 0.0 and w.y > 0.0, "10x10 -> положительные размеры")

func t_flow_columns() -> void:
	ck(Look.flow_columns(1174.0, 340.0) == 3, "1174 -> 3 колонки")
	ck(Look.flow_columns(932.0, 340.0) == 2, "932 -> 2 колонки")
	ck(Look.flow_columns(692.0, 340.0) == 2, "692 -> 2 колонки")
	ck(Look.flow_columns(600.0, 340.0) == 1, "600 -> 1 колонка")
	ck(Look.flow_columns(100.0, 340.0) == 1, "100 -> пол на единице")

func t_card_head() -> void:
	var h := Look.card_head("Equipment", "", true)
	ck(h.get_child_count() == 2, "пустая подпись -> тик и заголовок")
	var tick := h.get_child(0) as ColorRect
	ck(tick != null and tick.custom_minimum_size == Look.TICK, "тик 3x14")
	ck(tick != null and tick.color == VTKSurface.GOLD, "accent -> золотой тик")
	var ttl := h.get_child(1) as Label
	ck(ttl != null and ttl.text == "EQUIPMENT", "заголовок капсом")
	var h2 := Look.card_head("Maps", "3", false)
	ck(h2.get_child_count() == 3, "подпись -> третий ребёнок")
	var tick2 := h2.get_child(0) as ColorRect
	ck(tick2 != null and tick2.color == VTKSurface.MUTED, "accent=false красит тик в MUTED")
	var ttl2 := h2.get_child(1) as Label
	ck(ttl2 != null and ttl2.get_theme_color("font_color") == VTKSurface.SECTION_INK,
		"accent=false красит заголовок в SECTION_INK")

func t_card() -> void:
	var body := VBoxContainer.new()
	var c := Look.card("Inventory", "12", body)
	ck(c is PanelContainer, "карточка - PanelContainer")
	ck(c.get_child_count() == 1, "один ребёнок - VBox")
	var vb := c.get_child(0) as VBoxContainer
	ck(vb != null and vb.get_child_count() == 2, "VBox: заголовок и тело")
	ck(vb != null and vb.get_child(0) is HBoxContainer, "первый ребёнок - заголовок")
	ck(vb != null and vb.get_child(1) == body, "второй ребёнок - переданное тело")

func t_palette() -> void:
	ck(is_equal_approx(VTKSurface.SCRIM.a, 0.35), "затемнение 0.35")
	ck(VTKSurface.TEXT_SOFT != VTKSurface.TEXT_DIM, "вторичный текст отличается от приглушённого")
	ck(VTKSurface.TEXT_DIM != VTKSurface.TEXT_OFF, "приглушённый отличается от выключенного")
	var all := [VTKSurface.SCRIM, VTKSurface.BRAND_INK, VTKSurface.SEPARATOR,
		VTKSurface.INK_ON_GOLD, VTKSurface.FIELD_INK, VTKSurface.DOT_OFF,
		VTKSurface.STEP_OFF_BG, VTKSurface.CELL_BG, VTKSurface.CELL_ON_BG,
		VTKSurface.CELL_HOVER_BG, VTKSurface.CELL_ON_BORDER,
		VTKSurface.CELL_HOVER_BORDER, VTKSurface.CELL_BORDER, VTKSurface.DANGER,
		VTKSurface.INVEN_BG, VTKSurface.TRACK_ON, VTKSurface.TRACK_OFF,
		VTKSurface.KNOB_OFF, VTKSurface.SECTION_INK, VTKSurface.TEXT_SOFT,
		VTKSurface.TEXT_DIM, VTKSurface.TEXT_OFF, VTKSurface.BTN_INK,
		VTKSurface.RAIL_BG, VTKSurface.INK_OFF, VTKSurface.GOLD_OFF]
	var not_color := 0
	for v in all:
		if not (v is Color):
			not_color += 1
	ck(not_color == 0, "все новые константы - Color")

func t_tab_style() -> void:
	var off := VTKSurface.tab_style(false)
	ck(off is StyleBoxFlat, "вкладка - плоский стиль")
	ck(off.bg_color.a == 0.0, "неактивная вкладка без плашки")
	ck(off.border_width_bottom == 0, "у неактивной нет подчёркивания")
	var on := VTKSurface.tab_style(true)
	ck(on.border_width_bottom == 2, "активная вкладка подчёркнута на 2 px")
	ck(on.border_color == VTKSurface.GOLD, "подчёркивание золотое")
	ck(VTKSurface.tab_style(true) == on, "стиль вкладки кэшируется")

func t_lock_icon() -> void:
	var t := VTKSurface.lock_icon(16, VTKSurface.GOLD_OFF)
	ck(t != null, "замок рисуется из SVG-строки")
	ck(t.get_width() == 16 and t.get_height() == 16, "замок 16x16")
	ck(VTKSurface.lock_icon(16, VTKSurface.GOLD_OFF) == t, "иконка замка кэшируется")
