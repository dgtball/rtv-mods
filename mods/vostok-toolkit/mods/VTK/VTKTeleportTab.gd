extends RefCounted
## Вкладка «Телепорт»: карточки (карты, убежища, торговцы) перетекают по ширине
## окна: 3 колонки, 2 + третья во всю ширину, 1. Вынесена из VTKUI (батч 6e, R3).
##
## Вкладка владеет только своими боксами, всё остальное приходит извне:
## travel создаёт VTKUI через _ensure_travel (узел живёт ребёнком VTKUI),
## game_data грузит он же. Общие примитивы UI инжектируются Callable: motion
## тянет _tween_scale VTKUI, а объявить здесь вторую копию нельзя - DUP стенда
## ловит одноимённые функции в разных модулях.
##
## Имена методов сохранены от VTKUI: их держит layout_check (PRESENT на
## _make_tp_column, FUNCS по телам _build_teleport_tab и _make_tp_column),
## переименование сломало бы стенд.

const Loc = preload("res://mods/VTK/VTKLoc.gd")
const VTKSurface := preload("res://mods/VTK/VTKSurface.gd")
const VTKLook := preload("res://mods/VTK/VTKLook.gd")

# Инъекция из VTKUI: _attach_row_hover и _attach_motion.
var hover: Callable = Callable()
var motion: Callable = Callable()

var _tp_maps_box: VBoxContainer = null
var _tp_shelters_box: VBoxContainer = null
var _tp_traders_box: VBoxContainer = null

# Карточки и раскладка: карточки создаются один раз и перевешиваются, а не
# пересоздаются - иначе пропали бы боксы строк, которые наполняет
# _refresh_teleport_tab.
var _tp_cards: Array[Control] = []
var _tp_flow: VBoxContainer = null
var _tp_cols: int = 0

func _tp_section_label(section: String) -> String:
	match section:
		"maps":
			return Loc.txt("Maps")
		"shelters":
			return Loc.txt("Shelters")
		"traders":
			return Loc.txt("Traders")
	return ""

# Строка телепорта - цель клика, а не подпись: поля 18 и шрифт 14 дают высоту
# 59 вместо прежних 41. Поля одинаковы в обоих состояниях, иначе строка
# прыгала бы на ховере.
func _tp_row_style(hover: bool) -> StyleBox:
	return VTKSurface.surface("hover" if hover else "normal", false, false, false, 18, 18, 18, 18)

func _tp_row(title: String, note: String, enabled: bool, callback: Callable) -> Control:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_theme_stylebox_override("panel", _tp_row_style(false))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	row.add_child(hb)

	var nm := Label.new()
	nm.text = title
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", VTKSurface.INK if enabled else VTKSurface.INK_OFF)
	hb.add_child(nm)

	if note != "":
		var nt := Label.new()
		nt.text = note
		nt.add_theme_font_size_override("font_size", 10)
		nt.add_theme_color_override("font_color", VTKSurface.BROWN)
		nt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(nt)

	if enabled:
		var go := Label.new()
		go.text = "▸"
		go.add_theme_font_size_override("font_size", 16)
		go.add_theme_color_override("font_color", VTKSurface.GOLD)
		go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hb.add_child(go)
		hover.call(row, func(hv: bool) -> StyleBox:
			return _tp_row_style(hv))
		motion.call(row)
		var cb := callback
		row.gui_input.connect(func(ev: InputEvent):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if cb.is_valid():
					cb.call())
	else:
		var lock := TextureRect.new()
		lock.texture = VTKSurface.lock_icon(16, VTKSurface.GOLD_OFF)
		lock.custom_minimum_size = Vector2(16, 22)
		lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(lock)
	return row

func _make_tp_column(title: String, count: int, box: VBoxContainer) -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var card := VTKLook.card(title, str(count), scroll)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return card


func _build_teleport_tab(parent: VBoxContainer, travel: Node, game_data: Resource) -> void:
	var head := Label.new()
	head.text = Loc.txt("Teleport")
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", VTKSurface.GOLD)
	parent.add_child(head)

	_tp_maps_box = VBoxContainer.new()
	_tp_maps_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_maps_box.add_theme_constant_override("separation", 4)
	_tp_shelters_box = VBoxContainer.new()
	_tp_shelters_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_shelters_box.add_theme_constant_override("separation", 4)
	_tp_traders_box = VBoxContainer.new()
	_tp_traders_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_traders_box.add_theme_constant_override("separation", 4)

	var n_maps := 0
	var n_shelters := 0
	var n_traders := 0
	if travel != null and is_instance_valid(travel):
		n_maps = travel.MAPS.size()
		n_shelters = travel.SHELTERS.size()
		n_traders = travel.TRADERS.size()

	_tp_flow = VBoxContainer.new()
	_tp_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tp_flow.add_theme_constant_override("separation", 10)
	_tp_flow.resized.connect(_reflow_tp)
	parent.add_child(_tp_flow)

	_tp_cards = [
		_make_tp_column(_tp_section_label("maps"), n_maps, _tp_maps_box),
		_make_tp_column(_tp_section_label("shelters"), n_shelters, _tp_shelters_box),
		_make_tp_column(_tp_section_label("traders"), n_traders, _tp_traders_box),
	]
	_reflow_tp()

	_refresh_teleport_tab(travel, game_data)

func _make_tp_row(a: Control, b: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	row.add_child(a)
	row.add_child(b)
	return row

# Раскладка карточек по ширине окна: 3 колонки, 2 + третья во всю ширину, 1.
# Карточки сперва отцепляются от старых рядов и только потом ряды освобождаются:
# queue_free ряда унёс бы карточки вместе с собой. Пересборка - только при смене
# числа колонок, иначе репарент случался бы на каждый ресайз и мог съесть клик.
func _reflow_tp() -> void:
	if _tp_flow == null or _tp_cards.is_empty():
		return
	var cols := VTKLook.flow_columns(_tp_flow.size.x, 340.0)
	if cols == _tp_cols:
		return
	_tp_cols = cols
	for card in _tp_cards:
		if card.get_parent() != null:
			card.get_parent().remove_child(card)
	for row in _tp_flow.get_children():
		_tp_flow.remove_child(row)
		row.queue_free()
	if cols == 1:
		for card in _tp_cards:
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_tp_flow.add_child(card)
		return
	var first := _make_tp_row(_tp_cards[0], _tp_cards[1])
	_tp_flow.add_child(first)
	if cols == 3:
		first.add_child(_tp_cards[2])
		return
	# cols == 2: третья карточка во всю ширину под первым рядом.
	_tp_cards[2].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tp_flow.add_child(_tp_cards[2])

func _refresh_teleport_tab(travel: Node, game_data: Resource) -> void:
	if travel == null or not is_instance_valid(travel):
		return
	for box in [_tp_maps_box, _tp_shelters_box, _tp_traders_box]:
		if box == null:
			continue
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	var in_tutorial: bool = game_data != null and bool(game_data.get("tutorial"))

	for m in travel.MAPS:
		var map_note := Loc.txt("in the tutorial") if in_tutorial else ""
		var mm := String(m)
		_tp_maps_box.add_child(_tp_row(String(m), map_note, not in_tutorial, func(): travel.travel_to_map(mm)))

	var unlocked_only: bool = bool(travel.get("unlocked_only"))

	for s in travel.SHELTERS:
		var ss := String(s)
		if in_tutorial:
			_tp_shelters_box.add_child(_tp_row(String(s), Loc.txt("in the tutorial"), false, func(): travel.travel_to_shelter(ss)))
		else:
			var open: bool = bool(travel.is_shelter_unlocked(ss))
			var enabled: bool = not unlocked_only or open
			var note := "" if enabled else Loc.txt("Not unlocked yet")
			_tp_shelters_box.add_child(_tp_row(ss, note, enabled, func(): travel.travel_to_shelter(ss)))

	for t in travel.TRADERS:
		var entry: Dictionary = t
		var note3 := Loc.txt("in the tutorial") if in_tutorial else ""
		_tp_traders_box.add_child(_tp_row(String(entry["name"]), note3, not in_tutorial, func(): travel.travel_to_trader(entry)))
