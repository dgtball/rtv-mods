extends SceneTree

const N = preload("res://mods/VTK/VTKNotes.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_group_items()
	t_group_items_fallback()
	t_item_key()
	t_completed_lists()
	t_is_completed()
	t_find_note()
	t_badge_text()
	t_build_icon_row()
	t_progress_totals()
	t_build_progress_row()
	t_build_progress()
	t_augment_note()
	print("")
	if fails == 0:
		print("Notes tests passed")
		quit(0)
	else:
		print("Notes tests failed: ", fails)
		quit(1)

func t_group_items() -> void:
	var a := {"resource_path": "res://A", "name": "Bandage"}
	var b := {"resource_path": "res://B", "name": "Saline"}
	var got := N.group_items([a, b, a, a, b])
	ck(got.size() == 2, "group_items: две группы из пяти предметов")
	if got.size() == 2:
		ck(got[0]["item"]["name"] == "Bandage" and got[0]["count"] == 3, "первый по появлению, count=3")
		ck(got[1]["item"]["name"] == "Saline" and got[1]["count"] == 2, "второй, count=2")
	ck(N.group_items([]).is_empty(), "group_items: пустой вход")
	ck(N.group_items(null).is_empty(), "group_items: null")

func t_group_items_fallback() -> void:
	# Без resource_path группируем по name.
	var x := {"resource_path": "", "name": "Rags"}
	var y := {"resource_path": "", "name": "Rags"}
	var got := N.group_items([x, y])
	ck(got.size() == 1 and got[0]["count"] == 2, "group_items: fallback на name")

func t_completed_lists() -> void:
	var traders := {"doctor": ["A", "B"], "generalist": ["C"]}
	var got := N.completed_lists(traders)
	ck(got.has("doctor") and got["doctor"].has("A"), "completed_lists: doctor")
	ck(got.has("generalist") and got["generalist"].has("C"), "completed_lists: generalist")
	ck(N.completed_lists(null).is_empty(), "completed_lists: null -> пусто")

func t_is_completed() -> void:
	var completed := N.completed_lists({"doctor": ["A"]})
	ck(N.is_completed({"trader": "Doctor", "name": "A"}, completed), "is_completed: Doctor/A сдан")
	ck(not N.is_completed({"trader": "Doctor", "name": "Z"}, completed), "is_completed: Doctor/Z не сдан")
	ck(not N.is_completed({"trader": "Hunter", "name": "A"}, completed), "is_completed: чужой торговец")
	ck(not N.is_completed(null, completed), "is_completed: null task")

func t_find_note() -> void:
	var note := {"trader": "Doctor", "name": "A"}
	var other := {"trader": "Doctor", "name": "B"}
	var notes := [other, note]
	var found = N.find_note(notes, {"trader": "Doctor", "name": "A"})
	ck(found != null and found.get("name") == "A", "find_note: находит по name+trader")
	ck(N.find_note(notes, {"trader": "Doctor", "name": "Q"}) == null, "find_note: чужого нет -> null")
	ck(N.find_note([], {"trader": "Doctor", "name": "A"}) == null, "find_note: пустой список")
	ck(N.find_note(null, {"trader": "Doctor", "name": "A"}) == null, "find_note: null")

func t_badge_text() -> void:
	ck(N.badge_text(1) == "", "badge_text: 1 -> пусто")
	ck(N.badge_text(0) == "", "badge_text: 0 -> пусто")
	ck(N.badge_text(2) == "×2", "badge_text: 2 -> ×2")
	ck(N.badge_text(5) == "×5", "badge_text: 5 -> ×5")

func t_item_key() -> void:
	ck(N.item_key({"resource_path": "res://A", "name": "Bandage"}) == "res://A",
		"item_key: приоритет resource_path")
	ck(N.item_key({"resource_path": "", "name": "Saline"}) == "Saline",
		"item_key: фолбэк на name")
	ck(N.item_key(null) == "", "item_key: null -> пусто")

func t_progress_totals() -> void:
	var a := {"resource_path": "res://A", "name": "Bandage"}
	var b := {"resource_path": "res://B", "name": "Saline"}
	var entries := N.group_items([a, a, b])
	var cov := {"res://A": {"got": 2, "need": 2}, "res://B": {"got": 0, "need": 1}}
	var t := N.progress_totals(entries, cov)
	ck(t == Vector2i(2, 3), "progress_totals: got/need суммируются по группам")
	# got капнут по need
	var capped := N.progress_totals(
		[{"item": {"resource_path": "res://A"}, "count": 1}],
		{"res://A": {"got": 9, "need": 2}})
	ck(cap_and_need(capped) == "2/2", "progress_totals: got капнут по need")
	ck(N.progress_totals([], {}).x == 0 and N.progress_totals([], {}).y == 0,
		"progress_totals: пусто -> 0/0")

func cap_and_need(v: Vector2i) -> String:
	return str(v.x) + "/" + str(v.y)

func t_build_progress_row() -> void:
	var tex := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var entries := [
		{"item": {"resource_path": "res://A", "name": "Bandage", "icon": tex}, "count": 1},
		{"item": {"resource_path": "res://B", "name": "Saline", "icon": tex}, "count": 1},
	]
	var row := N.build_progress_row(entries, {"res://A": {"got": 1, "need": 1}})
	ck(row != null and row.get_child_count() == 2, "build_progress_row: клетка на группу")
	if row.get_child_count() == 2:
		ck(_has_label_text(row.get_child(0), "1 / 1"), "чип: сданный 1 / 1")
		ck(_has_label_text(row.get_child(1), "0 / 1"), "чип: несданный 0 / 1 (нет ключа)")
	row.free()

func t_build_progress() -> void:
	var entries := [
		{"item": {"resource_path": "res://A", "name": "Bandage"}, "count": 1},
		{"item": {"resource_path": "res://B", "name": "Saline"}, "count": 1},
	]
	var box := N.build_progress(entries, {"res://A": {"got": 1, "need": 1}})
	ck(box.get_child_count() == 2, "build_progress: строка + полоса")
	var line = box.get_child(0)
	var left = line.get_child(0)
	var right = line.get_child(1)
	ck(left is Label and left.text == "Deposited 1 / 2", "build_progress: Deposited 1 / 2")
	ck(right is Label and right.text == "50%", "build_progress: 50%")
	ck(box.get_child(1) is ProgressBar, "build_progress: прогресс-бар на месте")
	box.free()

func _has_texture(node) -> bool:
	for c in node.get_children():
		if c is TextureRect and c.texture != null:
			return true
	return false

func _badge_of(node) -> String:
	for c in node.get_children():
		if c is Label and c.text.begins_with("×"):
			return c.text
	return ""

func _has_label_text(node, text: String) -> bool:
	for c in node.get_children():
		if c is Label and c.text == text:
			return true
	return false

func t_build_icon_row() -> void:
	var tex := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var row := N.build_icon_row([
		{"item": {"name": "Bandage", "icon": tex}, "count": 1},
		{"item": {"name": "Saline", "icon": tex}, "count": 3},
		{"item": {"name": "Rags", "icon": null}, "count": 1},
	])
	ck(row != null and row.get_child_count() == 3, "build_icon_row: клетка на предмет")
	if row.get_child_count() == 3:
		var c0 = row.get_child(0)
		ck(c0.tooltip_text == "Bandage", "тултип = имя предмета")
		ck(_has_texture(c0), "иконка есть -> TextureRect")
		ck(_badge_of(c0) == "", "count 1 -> без бейджа")
		var c1 = row.get_child(1)
		ck(_badge_of(c1) == "×3", "count 3 -> бейдж ×3")
		var c2 = row.get_child(2)
		ck(_has_label_text(c2, "Rags"), "нет иконки -> текстовый фоллбэк")
	row.free()

class FakeCard extends PanelContainer:
	var taskData = null
	var inputItems: Label
	var outputItems: Label
	var inputGrid: Control
	var outputGrid: Control

func _make_card(card: FakeCard, deliver: Array, receive: Array) -> void:
	var elements := VBoxContainer.new()
	card.add_child(elements)

	var description := Label.new()
	elements.add_child(description)

	var input_label := Label.new()
	input_label.text = "Deliver:"
	elements.add_child(input_label)
	card.inputItems = Label.new()
	card.inputItems.text = "Item, Item"
	input_label.add_child(card.inputItems)
	card.inputGrid = GridContainer.new()
	elements.add_child(card.inputGrid)

	var output_label := Label.new()
	output_label.text = "Receive:"
	elements.add_child(output_label)
	card.outputItems = Label.new()
	card.outputItems.text = "Item, Item"
	output_label.add_child(card.outputItems)
	card.outputGrid = GridContainer.new()
	elements.add_child(card.outputGrid)

	card.taskData = {"deliver": deliver, "receive": receive}

func t_augment_note() -> void:
	var card := FakeCard.new()
	var a := {"resource_path": "res://A", "name": "Bandage"}
	var b := {"resource_path": "res://B", "name": "Saline"}
	_make_card(card, [a, a, b], [b])
	N.augment_note(card, {"res://A": {"got": 1, "need": 2}})

	ck(card.inputItems.visible == false, "augment_note: текст Deliver скрыт")
	ck(card.outputItems.visible == false, "augment_note: текст Receive скрыт")
	ck(card.inputGrid.visible == false, "augment_note: грид Deliver скрыт")
	ck(card.outputGrid.visible == false, "augment_note: грид Receive скрыт")

	# Блок Deliver вставлен после секции 'Deliver:' — VBox[строка+полоса, ряд иконок].
	var input_label := card.inputItems.get_parent()
	ck(input_label.get_index() == 1, "секция Deliver на месте")
	var block = card.get_child(0).get_child(input_label.get_index() + 1)
	ck(block is Control and block.get_child_count() == 2,
		"Deliver: прогресс + ряд")
	var row_in = block.get_child(1)
	ck(row_in is Control and row_in.get_child_count() == 2,
		"ряд Deliver: 2 разных предмета")
	var output_label := card.outputItems.get_parent()
	var row_out = card.get_child(0).get_child(output_label.get_index() + 1)
	ck(row_out is Control and row_out.get_child_count() == 1,
		"ряд Receive: 1 предмет")

	# Пустые списки — ряд не строится, текст всё равно скрыт.
	var empty := FakeCard.new()
	_make_card(empty, [], [])
	N.augment_note(empty)
	ck(empty.get_child(0).get_child_count() == 5, "пустые списки: ряд не добавлен")

	# Live-refresh после вклада зовёт augment_note на той же карточке: блок
	# должен замениться, а не наслоиться (иначе прогресс задваивается).
	N.augment_note(card, {"res://A": {"got": 2, "need": 2}})
	ck(card.get_child(0).get_child_count() == 7, "повторный augment_note не наслаивает блоки")
	var block2 = card.get_child(0).get_child(input_label.get_index() + 1)
	ck(block2.name == "VTKNoteDeliver", "повторный блок — управляемый VTKNoteDeliver")

	card.free()
	empty.free()
