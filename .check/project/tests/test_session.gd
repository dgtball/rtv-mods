extends SceneTree

const Session = preload("res://mods/VTK/VTKLoadoutSession.gd")
const Draft = preload("res://mods/VTK/VTKDraft.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_defaults()
	t_reset()
	t_attachment_target_by_page()
	t_set_attachment_target()
	t_toggle_attachment_target()
	t_clear_attachments()
	t_new_draft()
	t_clear_draft()
	t_edit_draft()
	print("")
	if fails == 0:
		print("Session tests passed")
		quit(0)
	else:
		print("Session tests failed: ", fails)
		quit(1)

func t_defaults() -> void:
	var s = Session.new()
	ck(s.draft == null, "новое состояние без черновика")
	ck(s.page == 0, "новая страница нулевая")
	ck(s.target_slot == "" and s.target_cat == "" and s.target_sub == "", "цель и фильтры пусты")
	ck(s.search_text == "" and s.gear_search == "", "оба поиска пусты")
	ck(s.gear_facet_key == "" and s.gear_sub_key == "", "фасеты шага 2 пусты")
	ck(not s.gear_only_selected and not s.gear_subs_collapsed, "тумблеры шага 2 выключены")
	ck(s.open_equip_att == "" and s.open_gear_att == "", "обе панели обвесов закрыты")
	ck(s.last_placed == "", "ничего только что положено")

func t_reset() -> void:
	var s = Session.new()
	s.target_slot = "Primary"
	s.search_text = "ak"
	s.gear_search = "med"
	s.gear_facet_key = "Weapon"
	s.gear_sub_key = "Barrel"
	s.gear_subs_collapsed = true
	s.gear_only_selected = true
	s.open_equip_att = "res://a.tres"
	s.open_gear_att = "res://b.tres"
	s.last_placed = "res://c.tres"
	s.reset_picker_state()
	ck(s.target_slot == "" and s.search_text == "" and s.gear_search == "", "сброс чистит цель и поиски")
	ck(s.gear_facet_key == "" and s.gear_sub_key == "", "сброс чистит фасеты")
	ck(not s.gear_only_selected and not s.gear_subs_collapsed, "сброс выключает тумблеры")
	ck(s.open_equip_att == "" and s.open_gear_att == "", "сброс закрывает обе панели обвесов")
	ck(s.last_placed == "", "сброс забывает только что положенный предмет")
	ck(s.page == 0, "сброс не трогает страницу")

func t_attachment_target_by_page() -> void:
	var s = Session.new()
	s.open_equip_att = "res://eq.tres"
	s.open_gear_att = "res://gr.tres"
	s.page = 0
	ck(s.attachment_target() == "res://eq.tres", "страница 0 показывает панель экипировки")
	s.page = 1
	ck(s.attachment_target() == "res://gr.tres", "страница 1 показывает панель снаряжения")

func t_set_attachment_target() -> void:
	var s = Session.new()
	s.page = 0
	s.set_attachment_target("res://eq.tres")
	ck(s.open_equip_att == "res://eq.tres", "запись на странице 0 идёт в экипировку")
	ck(s.open_gear_att == "", "запись страницы 0 не тронула снаряжение")
	s.page = 1
	s.set_attachment_target("res://gr.tres")
	ck(s.open_gear_att == "res://gr.tres", "запись на странице 1 идёт в снаряжение")
	ck(s.open_equip_att == "res://eq.tres", "запись страницы 1 не тронула экипировку")

func t_toggle_attachment_target() -> void:
	var s = Session.new()
	s.page = 0
	s.toggle_attachment_target("res://eq.tres")
	ck(s.open_equip_att == "res://eq.tres", "переключатель открывает панель")
	s.toggle_attachment_target("res://eq.tres")
	ck(s.open_equip_att == "", "повторный переключатель закрывает панель")
	s.toggle_attachment_target("res://eq.tres")
	s.toggle_attachment_target("res://other.tres")
	ck(s.open_equip_att == "res://other.tres", "другой предмет заменяет открытую панель")
	s.page = 1
	s.toggle_attachment_target("res://gr.tres")
	ck(s.open_gear_att == "res://gr.tres", "переключатель страницы 1 пишет в своё поле")
	ck(s.open_equip_att == "res://other.tres", "переключатель страницы 1 не трогает экипировку")

func t_clear_attachments() -> void:
	var s = Session.new()
	s.open_equip_att = "res://eq.tres"
	s.open_gear_att = "res://gr.tres"
	s.clear_attachments()
	ck(s.open_equip_att == "" and s.open_gear_att == "", "очистка закрывает обе панели")

func t_new_draft() -> void:
	var s = Session.new()
	s.open_equip_att = "res://eq.tres"
	s.open_gear_att = "res://gr.tres"
	s.new_draft()
	ck(s.draft != null, "новый черновик создан")
	ck(s.draft is Draft, "черновик нужного типа")
	ck(s.draft.item_count() == 0, "новый черновик пуст")
	ck(s.open_equip_att == "" and s.open_gear_att == "", "новый черновик закрывает панели обвесов")

func t_clear_draft() -> void:
	var s = Session.new()
	s.draft = Draft.new()
	s.open_equip_att = "res://eq.tres"
	s.open_gear_att = "res://gr.tres"
	s.clear_draft()
	ck(s.draft == null, "черновик сброшен")
	ck(s.open_equip_att == "" and s.open_gear_att == "", "отмена закрывает панели обвесов")

func t_edit_draft() -> void:
	var s = Session.new()
	var d = Draft.new()
	d.set_name = "Тест"
	d.add("res://v.tres", "АК", ["Primary"], 1.0, "Weapon")
	s.open_equip_att = "res://eq.tres"
	s.open_gear_att = "res://gr.tres"
	s.edit_draft(d)
	ck(s.draft == d, "редактирование приняло переданный черновик")
	ck(s.draft.set_name == "Тест", "имя редактируемого сета доступно")
	ck(s.draft.item_count() == 1, "состав редактируемого сета на месте")
	ck(s.open_equip_att == "" and s.open_gear_att == "", "вход в редактор закрывает панели обвесов")
