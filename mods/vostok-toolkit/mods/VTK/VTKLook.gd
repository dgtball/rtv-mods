extends RefCounted
## Строители окна и карточек панели (приём smel-ucm): правило размера окна,
## перетекающие колонки, общий заголовок карточки и сама карточка.
##
## Статический RefCounted, как VTKSurface/VTKItemStore: ни состояния сцены, ни
## load() внутрь игры, поэтому покрыт headless-тестом test_look.gd. Палитра
## живёт в VTKSurface, здесь только геометрия и узлы.

const VTKSurface := preload("res://mods/VTK/VTKSurface.gd")

# Правило окна: viewport минус поля, с полами и максимумом. 220 по вертикали -
# полоса ванильных тостов (две плашки по 50 плюс зазоры): окно центрировано,
# поэтому нижний зазор = (view.y - h) / 2 и при h = view.y - 220 равен 110.
# 840 взято под 1080p: внутри окна остаётся h - 73 (врезки 20 + рейл 40 +
# разделитель 1 + два зазора 6) = 767, а «Готово» просит 740; превью сета
# просит 699. При 800 запас был бы 13, при 820 - 7, поэтому 840: прокрутки
# на 1080p нет ни у одной страницы, а зазор под тосты остаётся 110.
const W_MAX := 1200.0
const H_MAX := 840.0
const W_GUTTER := 320.0
const H_GUTTER := 220.0
const W_MIN := 720.0
const H_MIN := 400.0
const EDGE := 16.0

# Шапка: вкладки обязаны стоять по центру окна, поэтому левая и правая зоны
# получают одинаковый минимум - добавочная ширина делится поровну. 168 - это
# левая зона (знак 30 + зазор 8 + заголовок 118) с запасом, а на минимальном
# окне 720 шапка всё равно влезает: 168 + 344 + 168 + 16 зазоров = 696 <= 700.
const RAIL_H := 40
const TAB_W := 170
const TAB_H := 40
const HEADER_SIDE := 168

# Тик перед заголовком карточки и поля карточки по горизонтали: от них же
# считается минимальная ширина карточки превью (сетка + 2 * CARD_PAD).
const TICK := Vector2(3, 14)
const CARD_PAD := 10

static func window_size(view: Vector2) -> Vector2:
	var w := clampf(view.x - W_GUTTER, W_MIN, W_MAX)
	var h := clampf(view.y - H_GUTTER, H_MIN, H_MAX)
	w = minf(w, view.x - EDGE)
	h = minf(h, view.y - EDGE)
	return Vector2(maxf(w, 1.0), maxf(h, 1.0))

# Одна формула на все перетекающие ряды: сколько колонок по min_col_width
# влезает в inner_width. Пол - единица, иначе на нулевой ширине (первый кадр)
# получался бы ноль колонок и карточки не показывались бы вовсе.
static func flow_columns(inner_width: float, min_col_width: float) -> int:
	if min_col_width <= 0.0:
		return 1
	return clampi(int(inner_width / min_col_width), 1, 3)

# Заголовок карточки: золотой тик 3x14, название капсом 11px и необязательная
# подпись справа. accent=false - секционные подписи редактора (тик и текст
# приглушены).
static func card_head(title: String, note := "", accent := true) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var tick := ColorRect.new()
	tick.custom_minimum_size = TICK
	tick.color = VTKSurface.GOLD if accent else VTKSurface.MUTED
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(tick)
	var ttl := Label.new()
	ttl.text = title.to_upper()
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ttl.add_theme_font_size_override("font_size", 11)
	ttl.add_theme_color_override("font_color",
		VTKSurface.GOLD if accent else VTKSurface.SECTION_INK)
	ttl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(ttl)
	if note != "":
		var nt := Label.new()
		nt.text = note
		nt.add_theme_font_size_override("font_size", 9)
		nt.add_theme_color_override("font_color", VTKSurface.BROWN)
		nt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		nt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(nt)
	return head

# Карточка: рамка surface + заголовок + готовое тело. Флаги размера тела не
# трогаем: телепорту нужен EXPAND_FILL (ScrollContainer), стене инвентаря -
# SHRINK_BEGIN, иначе её клетки растянутся вместо 70px. Поля карточки 10/10/7/7
# и есть отступ тела - отдельный MarginContainer не нужен.
static func card(title: String, note: String, body: Control, accent := true) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
		VTKSurface.surface("normal", false, false, false, CARD_PAD, CARD_PAD, 7, 7))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.add_child(card_head(title, note, accent))
	vb.add_child(body)
	card.add_child(vb)
	return card
