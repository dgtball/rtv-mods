extends RefCounted
# Рейл сетов и превью состава (вкладка «Сеты»): список сохранённых сетов,
# выбор активного, захват хоткея и превью выбранного сета с полосой управления
# над карточками.
# Модуль владеет левой и правой колонками ряда и общим билдером превью
# (_build_set_preview), который переиспользует страница Готово редактора.
# Ссылка на узел VTKUI (_ui) нужна для общих сцен: перерисовка списка/превью
# (refresh_rail), рендер предметных колонок превью
# (_make_equip_preview/_make_inventory_panel), открытие/закрытие черновика
# (_ui._session.draft/_ui._cancel_draft) и подвес hover/motion на карточки.
const Loc = preload("res://mods/VTK/VTKLoc.gd")
const VTKSurface := preload("res://mods/VTK/VTKSurface.gd")
const LD := preload("res://mods/VTK/VTKData.gd")
const VTKLook := preload("res://mods/VTK/VTKLook.gd")

# Ширина рейла сетов. Окно фиксированной ширины (720-1200), поэтому рейл
# держим компактным: карточкам хватает воздуха, а редактор справа всё равно
# забирает большую часть ширины.
const RAIL_WIDTH := 280

var _ui

# Колонки ряда: рейл слева, превью/редактор справа.
var _rail_box: VBoxContainer = null
var _list_container: VBoxContainer = null
var _cards_grid: GridContainer = null
var _right_box: VBoxContainer = null
var _preview_box: VBoxContainer = null
# Активная карточка рейла: её состав показывает превью справа.
var _selected_set: String = ""
var _editing_name: String = ""
# Захват клавиши для хоткея: _bind_target - имя сохранённого сета (превью),
# _bind_pending - бинд для ещё не сохранённого черновика (страница Готово),
# _bind_btn - кнопка, чей текст показывает состояние, а _pending_qk применится
# в _save_loadout редактора после replace_set.
var _bind_target: String = ""
var _bind_pending: bool = false
var _bind_btn: Button = null
# Кнопка хоткея на странице Готово: её непустое состояние показываем текстом
# «Назначить клавишу», а не «?». В остальных местах кнопка хоткея - превью сета.
var _done_bind_btn: Button = null
# Строка отказа записи под списком сетов: удаление и бинд хоткея живут в рейле
# и превью, где _editor._page_label не виден.
var _rail_note: Label = null
var _pending_qk: int = 0
# Callable из VTKUI: перерисовать список и превью (LIST|PREVIEW).
var refresh_rail: Callable

func _init(ui) -> void:
	_ui = ui


func _build_loadouts_tab(parent: VBoxContainer) -> void:
	# Рейл и правая колонка - ряд через HBox: сам parent вертикальный (таб),
	# и без ряда обе колонки легли бы друг под другом.
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	# Рейл - та же подложка, что у колонок телепорта/снаряжения: inset-панель
	# с видимым только правым бордюром-разделителем. Без неё список сетов
	# висел бы на общей подложке таба и не читался как отдельная зона.
	var rail_panel := PanelContainer.new()
	rail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rp := VTKSurface.panel(true, 6).duplicate(true)
	rp.border_width_left = 0
	rp.border_width_top = 0
	rp.border_width_bottom = 0
	rp.shadow_color = Color(0, 0, 0, 0)
	rail_panel.add_theme_stylebox_override("panel", rp)
	row.add_child(rail_panel)

	_rail_box = VBoxContainer.new()
	_rail_box.custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	_rail_box.add_theme_constant_override("separation", 6)
	rail_panel.add_child(_rail_box)

	_rail_box.add_child(VTKLook.card_head(Loc.txt("Saved loadouts")))

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail_box.add_child(_list_container)

	_cards_grid = _make_cards_grid()
	_list_container.add_child(_cards_grid)

	_rail_note = Label.new()
	_rail_note.add_theme_font_size_override("font_size", 10)
	_rail_note.add_theme_color_override("font_color", VTKSurface.DANGER)
	_rail_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rail_note.visible = false
	_rail_box.add_child(_rail_note)

	_right_box = VBoxContainer.new()
	_right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_theme_constant_override("separation", 6)
	row.add_child(_right_box)

	_preview_box = VBoxContainer.new()
	_preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_child(_preview_box)

# Полоса управления превью/Done: ряд на всю ширину над карточками. Заголовок
# «Управление» удалён - полоса из кнопок читается сама. Ребёнок без заданной
# минимальной ширины получает EXPAND_FILL и делит остаток; ребёнок с
# custom_minimum_size.x остаётся при своей ширине (на «Готово» так живут хоткей,
# «Сохранить» и «Отмена», а поле имени забирает остаток).
func _make_control_row(buttons: Array) -> Control:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	for btn in buttons:
		btn.custom_minimum_size.y = 30
		if btn.custom_minimum_size.x == 0.0:
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	return row

# Общий билдер превью сета: полоса управления, разделитель и две карточки -
# экипировка и инвентарь. Кнопки стоят НАД карточками (вариант B макета):
# экипировка занимает почти всю видимую высоту, и футер с «Применить» уезжал бы
# под кромку скролла. Им же собрана страница Done, чтобы состав выглядел
# одинаково. fill=false на странице Done: превью идёт по содержимому, а строка
# полей сразу под ним. controls=null - полосы нет.
func _build_set_preview(eq: Dictionary, gear: Array, fill := true, controls: Control = null) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL if fill else Control.SIZE_SHRINK_BEGIN
	box.add_theme_constant_override("separation", 6)
	if controls != null:
		box.add_child(controls)
	var head_sep := ColorRect.new()
	head_sep.custom_minimum_size = Vector2(0, 1)
	head_sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_sep.color = VTKSurface.SEPARATOR
	head_sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(head_sep)
	# HFlow, а не HBox: в окне 960 (вьюпорт 1280×720) превью достаётся ~626 px,
	# а ряд карточек - 845. HBox дал бы горизонтальный скроллбар; flow переносит
	# стену инвентаря под экипировку, и раскладка остаётся одна.
	var row := HFlowContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL if fill else Control.SIZE_SHRINK_BEGIN
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	row.add_child(_ui._editor._make_equip_preview(eq))
	row.add_child(_ui._editor._make_inventory_panel(gear))
	box.add_child(row)
	return box

# Превью выбранного сета в правой колонке. Схлопывается при открытом
# черновике: правая колонка принадлежит редактору.
func _refresh_preview() -> void:
	if _preview_box == null:
		return
	for child in _preview_box.get_children():
		_preview_box.remove_child(child)
		child.queue_free()
	_preview_box.visible = _ui._session.draft == null
	if _ui._session.draft != null:
		return
	var pack: Dictionary = {}
	if _selected_set != "":
		pack = LD.get_set(_selected_set)
	if pack.is_empty():
		_selected_set = ""
		var ph := Label.new()
		ph.text = Loc.txt("Select a set on the left")
		ph.add_theme_font_size_override("font_size", 11)
		ph.add_theme_color_override("font_color", VTKSurface.GREY_DIM)
		_preview_box.add_child(ph)
		return

	var eq_d: Dictionary = pack.get("equip", {})
	var gr_a: Array = pack.get("gear", [])
	var qk := int(pack.get("quick_key", 0))

	var card_head := VBoxContainer.new()
	card_head.add_theme_constant_override("separation", 2)
	var nm := Label.new()
	nm.text = str(pack.get("name", _selected_set))
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", VTKSurface.INK)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_head.add_child(nm)
	_preview_box.add_child(card_head)

	var apply_btn := Button.new()
	apply_btn.text = Loc.txt("Apply")
	VTKSurface.style_button(apply_btn, true)
	apply_btn.pressed.connect(func(): LD.load_loadout(_selected_set))
	var edit_btn := Button.new()
	edit_btn.text = Loc.txt("Edit")
	VTKSurface.style_button(edit_btn)
	edit_btn.pressed.connect(func(): _ui._edit_loadout(_selected_set))
	var qk_btn := Button.new()
	if qk > 0:
		qk_btn.text = _keycode_to_string(qk)
		qk_btn.add_theme_color_override("font_color", VTKSurface.GOLD)
	else:
		qk_btn.text = "?"
		qk_btn.add_theme_color_override("font_color", VTKSurface.TEXT_OFF)
	VTKSurface.style_button(qk_btn, qk > 0)
	qk_btn.pressed.connect(func(): _begin_bind(_selected_set, qk_btn))
	var del_btn := Button.new()
	del_btn.text = Loc.txt("Delete")
	VTKSurface.style_button(del_btn, false, true)
	del_btn.pressed.connect(func(): _ui._delete_loadout(_selected_set))

	_preview_box.add_child(_build_set_preview(
		eq_d, gr_a, true,
		_make_control_row([apply_btn, edit_btn, qk_btn, del_btn])))

func _make_cards_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return grid

# Пунктирная карточка «+ Создать сет». StyleBoxFlat штрихов не умеет, а
# штатный компонент рамки убран из вёрстки, поэтому рамка рисуется вручную.
# Loc во внутреннем классе недоступен - текст приходит аргументом.
class CreateCard extends Panel:
	const S := preload("res://mods/VTK/VTKSurface.gd")

	var _action: Callable

	func _init(action: Callable, label: String) -> void:
		_action = action
		custom_minimum_size = Vector2(0, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var st := StyleBoxFlat.new()
		st.bg_color = VTKSurface.RAIL_BG
		st.corner_radius_all = 4
		add_theme_stylebox_override("panel", st)
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", VTKSurface.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		gui_input.connect(func(ev):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_action.call()
		)

	func _draw() -> void:
		S.draw_dashes(self,
			Rect2(Vector2(2, 2), size - Vector2(4, 4)), VTKSurface.BROWN)

func _refresh_loadout_list() -> void:
	for child in _list_container.get_children():
		_list_container.remove_child(child)
		child.queue_free()
	_cards_grid = _make_cards_grid()
	_list_container.add_child(_cards_grid)

	var loadouts = LD.get_all()
	if loadouts.is_empty():
		var empty = Label.new()
		empty.text = Loc.txt("No saved loadouts")
		empty.add_theme_color_override("font_color", VTKSurface.GREY_DIM)
		_list_container.add_child(empty)
		_list_container.add_child(CreateCard.new(_ui._start_new_draft, Loc.txt("+ Create loadout")))
		return

	for ld in loadouts:
		if typeof(ld) != TYPE_DICTIONARY:
			continue
		var nm := str(ld.get("name", ""))
		var pack: Dictionary = LD.get_set(nm)
		var active := nm == _selected_set

		# Карточка только выбирает: Apply/Edit/клавиша живут в превью справа,
		# иначе в рейле шириной 236 четыре кнопки не помещаются.
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_theme_stylebox_override("panel", VTKSurface.surface("normal", active, false, active, 12, 12, 11, 11))
		_ui._attach_row_hover(card, func(hv: bool):
			return VTKSurface.surface("hover" if hv else "normal", active, false, active, 12, 12, 11, 11))
		_ui._attach_motion(card)
		card.gui_input.connect(func(ev):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_select_set(nm)
		)

		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)

		var top = HBoxContainer.new()
		top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl = Label.new()
		name_lbl.text = nm
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(name_lbl)
		var qk := int(ld.get("quick_key", 0))
		if qk > 0:
			var kb = Label.new()
			kb.text = _keycode_to_string(qk)
			kb.add_theme_font_size_override("font_size", 9)
			kb.add_theme_color_override("font_color", VTKSurface.GOLD)
			kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_child(kb)
		box.add_child(top)

		var eq_d: Dictionary = pack.get("equip", {})
		var gr_a: Array = pack.get("gear", [])
		var meta = Label.new()
		meta.text = str(eq_d.size() + gr_a.size()) + Loc.txt(" items · ") + str(eq_d.size()) + Loc.txt(" in equipment")
		meta.add_theme_font_size_override("font_size", 10)
		meta.add_theme_color_override("font_color", VTKSurface.GREY_DIM)
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(meta)

		_cards_grid.add_child(card)

	_list_container.add_child(CreateCard.new(_ui._start_new_draft, Loc.txt("+ Create loadout")))

func _select_set(nm: String) -> void:
	_selected_set = nm
	# Клик по сету при открытом редакторе закрывает черновик и открывает
	# превью: правки не сохранённого черновика теряются, без диалога.
	if _ui._session.draft != null:
		_ui._cancel_draft()
	else:
		refresh_rail.call()

func _handle_bind_key(event: InputEventKey) -> void:
	if event.keycode == KEY_ESCAPE:
		_end_bind()
		return
	if _ui._is_toggle_event(event):
		_end_bind()
		return
	var kc := int(event.physical_keycode)
	if kc == 0:
		kc = int(event.keycode)
	if kc == 0:
		return
	if _bind_target != "":
		# Клавиша, занятая другим сетом, забирается: чужой бинд снимается.
		var rc := LD.set_quick_key_unique(_bind_target, kc)
		_bind_target = ""
		_bind_btn = null
		_set_note("" if rc == OK else Loc.txt("Could not save your sets"))
		# Перерисовка в обоих случаях: при отказе она возвращает прежнюю
		# клавишу, иначе кнопка показывала бы несохранённый бинд.
		refresh_rail.call()
	else:
		# Черновик ещё не в файле - бинд копится до сохранения.
		_pending_qk = kc
		_bind_pending = false
		_apply_qk_btn(_bind_btn, kc)
		_bind_btn = null

func _begin_bind(target: String, btn: Button, pending := false) -> void:
	_bind_target = target
	_bind_pending = pending
	_bind_btn = btn
	if btn != null:
		btn.text = Loc.txt("Press a key…")
		btn.add_theme_color_override("font_color", VTKSurface.GREY_DIM)

func _end_bind() -> void:
	var btn := _bind_btn
	var qk := _display_qk()
	if _bind_target != "":
		var pack: Dictionary = LD.get_set(_bind_target)
		qk = int(pack.get("quick_key", 0)) if not pack.is_empty() else 0
	_bind_target = ""
	_bind_pending = false
	_bind_btn = null
	_apply_qk_btn(btn, qk)

# Текст и цвет кнопки хоткея по её состоянию: назначенная клавиша - золотым,
# неназначенная на странице Готово - подписью «Назначить клавишу», в остальных
# местах - прежним «?». Одна точка правды для сборки, захвата клавиши и отмены,
# иначе после смены кнопки где-то остаётся старый текст.
func _apply_qk_btn(btn: Button, qk: int) -> void:
	if btn == null:
		return
	if qk > 0:
		btn.text = _keycode_to_string(qk)
		btn.add_theme_color_override("font_color", VTKSurface.GOLD)
		VTKSurface.style_button(btn, true)
	elif btn == _done_bind_btn:
		btn.text = Loc.txt("Assign key")
		btn.add_theme_color_override("font_color", VTKSurface.BTN_INK)
		VTKSurface.style_button(btn)
	else:
		btn.text = "?"
		btn.add_theme_color_override("font_color", VTKSurface.TEXT_OFF)
		VTKSurface.style_button(btn)

# Единая точка показа отказа записи в рейле: текст и видимость вместе.
func _set_note(msg: String) -> void:
	if _rail_note == null:
		return
	_rail_note.text = msg
	_rail_note.visible = msg != ""

# Бинд, который показывает кнопка на странице Готово: нажатый в захвате,
# если он есть, иначе сохранённый у редактируемого сета.
func _display_qk() -> int:
	if _pending_qk > 0:
		return _pending_qk
	if _editing_name != "":
		var pack: Dictionary = LD.get_set(_editing_name)
		if not pack.is_empty():
			return int(pack.get("quick_key", 0))
	return 0

static func _keycode_to_string(kc: int) -> String:
	if kc <= 0:
		return "?"
	return OS.get_keycode_string(kc)
