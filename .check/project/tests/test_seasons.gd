extends SceneTree

const S = preload("res://mods/VTK/VTKSeasons.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

func _init() -> void:
	t_seasons_order()
	t_resolve_index()
	t_resolve_bounds()
	t_start_offset_for()
	t_vanilla_season()
	t_is_winter()
	t_uses_tint()
	t_palettes()
	t_blend()
	print("")
	if fails == 0:
		print("Seasons tests passed")
		quit(0)
	else:
		print("Seasons tests failed: ", fails)
		quit(1)

func t_seasons_order() -> void:
	ck(S.SEASONS == ["spring", "summer", "autumn", "winter"], "SEASONS: весна-лето-осень-зима")

func t_resolve_index() -> void:
	ck(S.resolve_index(1, 30, 0) == 0, "день 1 цикла 30 со стартом 0 - весна")
	ck(S.resolve_index(1, 30, 1) == 1, "день 1 со стартом 1 - лето")
	ck(S.resolve_index(30, 30, 0) == 0, "последний день сезона ещё в нём")
	ck(S.resolve_index(31, 30, 0) == 1, "первый день следующего сезона")
	ck(S.resolve_index(91, 30, 0) == 3, "третий переход - зима")
	ck(S.resolve_index(121, 30, 0) == 0, "второй круг заворачивается к весне")
	ck(S.resolve_index(331, 30, 3) == 2, "offset 3 сдвигает второй круг к осени")

func t_resolve_bounds() -> void:
	ck(S.resolve_index(5, 0, 0) == 0, "цикл 0 клампится к 1, деления на ноль нет")
	ck(S.resolve_index(1, -5, 0) == 0, "отрицательный цикл клампится к 1")
	ck(S.resolve_index(1, 30, 7) == 3, "offset вне диапазона сворачивается по модулю")
	ck(S.resolve_index(31, 30, -1) == 0, "отрицательный offset сворачивается по модулю")

func t_start_offset_for() -> void:
	ck(S.start_offset_for("spring") == 0, "spring - offset 0")
	ck(S.start_offset_for("summer") == 1, "summer - offset 1")
	ck(S.start_offset_for("autumn") == 2, "autumn - offset 2")
	ck(S.start_offset_for("winter") == 3, "winter - offset 3")
	ck(S.start_offset_for("SUMMER") == 1, "регистр не важен")
	ck(S.start_offset_for(" Winter ") == 3, "пробелы обрезаются")
	ck(S.start_offset_for("banana") == S.DEFAULT_START_OFFSET, "неизвестное имя - дефолт")
	ck(S.start_offset_for("") == S.DEFAULT_START_OFFSET, "пустая строка - дефолт")
	var rnd_ok := true
	for _i in range(32):
		var v := S.start_offset_for("random")
		if v < 0 or v >= S.SEASONS.size():
			rnd_ok = false
	ck(rnd_ok, "random всегда даёт валидный offset")

func t_vanilla_season() -> void:
	ck(S.vanilla_season(3) == 2, "зима - ванильный сезон 2")
	ck(S.vanilla_season(0) == 1, "весна - ванильный сезон 1")
	ck(S.vanilla_season(1) == 1, "лето - ванильный сезон 1")
	ck(S.vanilla_season(2) == 1, "осень - ванильный сезон 1")

func t_is_winter() -> void:
	ck(S.is_winter(3), "индекс 3 - зима")
	ck(not S.is_winter(0), "индекс 0 - не зима")

func t_uses_tint() -> void:
	ck(S.uses_tint(0), "весна тонируется")
	ck(S.uses_tint(1), "лето тонируется")
	ck(S.uses_tint(2), "осень тонируется")
	ck(not S.uses_tint(3), "зима не тонируется - работает ванильный снег")

func t_palettes() -> void:
	ck(S.SEASON_TREE_TINT.has("spring"), "палитра листвы: есть весна")
	ck(S.SEASON_TREE_TINT.has("autumn"), "палитра листвы: есть осень")
	ck(not S.SEASON_TREE_TINT.has("winter"), "палитра листвы: зимы нет (тон снимается)")
	ck(S.tree_tint(0) == S.SEASON_TREE_TINT["spring"], "tree_tint(весна) - из палитры")
	ck(S.tree_tint(2) == S.SEASON_TREE_TINT["autumn"], "tree_tint(осень) - из палитры")
	ck(S.tree_tint(3) == Color(1, 1, 1, 1), "tree_tint(зима) - белый (без изменений)")
	ck(S.grass_tint(2) == S.SEASON_GRASS_TINT["autumn"], "grass_tint(осень) - из палитры")
	ck(S.SEASON_AIR_TINT.size() == 4, "палитра воздуха: все четыре сезона")
	ck(S.air_tint(3) == S.SEASON_AIR_TINT["winter"], "air_tint(зима) - из палитры")
	ck(S.tree_tint(99) == Color(1, 1, 1, 1), "индекс вне диапазона - белый, без падения")
	ck(S.air_tint(-1) == Color(1, 1, 1, 1), "отрицательный индекс - белый")


func t_blend() -> void:
	var a := Color(0, 0, 0)
	var b := Color(1, 1, 1)
	ck(S.blend(a, b, 0.0) == a, "blend t=0 -> a")
	ck(S.blend(a, b, 1.0) == b, "blend t=1 -> b")
	ck(S.blend(a, b, -1.0) == a, "blend ниже 0 клампится к a")
	ck(S.blend(a, b, 2.0) == b, "blend выше 1 клампится к b")
	ck(S.blend(a, b, 0.5).is_equal_approx(Color(0.5, 0.5, 0.5)), "blend середина")
