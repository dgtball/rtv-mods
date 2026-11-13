extends SceneTree

const Blasts = preload("res://mods/VTK/VTKBlasts.gd")

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
	t_empty_ring()
	t_hit_inside_radius()
	t_miss_outside_radius()
	t_exact_radius_boundary()
	t_stale_window()
	t_player_flag_carried()
	t_cap_drops_oldest()
	t_record_prunes_stale()
	t_nearest_wins()
	t_one_record_many_victims()
	t_prune_explicit()
	print("")
	if fails == 0:
		print("Blasts tests passed")
		quit(0)
	else:
		print("Blasts tests failed: ", fails)
		quit(1)

func t_empty_ring() -> void:
	ck(Blasts.match([], Vector3.ZERO, 1000).is_empty(), "пустое кольцо не совпадает")

func t_hit_inside_radius() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 2.0, false)
	ck(not Blasts.match(ring, Vector3(0, 0, 10), 1500).is_empty(),
		"h=2.0: жертва в 10 м по земле в радиусе")

func t_miss_outside_radius() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 2.0, false)
	ck(Blasts.match(ring, Vector3(0, 0, 11), 1500).is_empty(),
		"h=2.0: 11 м по земле уже вне радиуса (sqrt(121+4) > 11)")

func t_exact_radius_boundary() -> void:
	# h = 0.0, чтобы расстояние совпало с земным ровно: границы включительные.
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 0.0, false)
	ck(not Blasts.match(ring, Vector3(11, 0, 0), 1500).is_empty(),
		"ровно 11.0 м ещё совпадает (dist <= BLAST_RADIUS)")
	ck(Blasts.match(ring, Vector3(11.1, 0, 0), 1500).is_empty(),
		"11.1 м уже вне радиуса")

func t_stale_window() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 2.0, false)
	ck(not Blasts.match(ring, Vector3.ZERO, 2000).is_empty(), "возраст ровно 1000 мс ещё в окне")
	ck(Blasts.match(ring, Vector3.ZERO, 2001).is_empty(), "1001 мс уже вне окна")

func t_player_flag_carried() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 0.5, true)
	ck(bool(Blasts.match(ring, Vector3.ZERO, 1200)["player"]), "player=true переносится")
	ring = Blasts.record([], Vector3.ZERO, 1000, 2.0, false)
	ck(not bool(Blasts.match(ring, Vector3.ZERO, 1200)["player"]), "player=false переносится")

func t_cap_drops_oldest() -> void:
	var ring: Array = []
	for i in 10:
		ring = Blasts.record(ring, Vector3(i, 0, 0), 1000 + i, 2.0, false)
	ck(ring.size() == 8, "кольцо режется до 8")
	ck((ring[0]["pos"] as Vector3).x == 2.0, "выброшены две самые старые записи")
	ck((ring[7]["pos"] as Vector3).x == 9.0, "свежая запись последняя")

func t_record_prunes_stale() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 2.0, false)
	ring = Blasts.record(ring, Vector3.ONE, 3000, 2.0, false)
	ck(ring.size() == 1 and (ring[0]["pos"] as Vector3) == Vector3.ONE, "record выбрасывает протухшее")

func t_nearest_wins() -> void:
	var ring: Array = Blasts.record([], Vector3(0, 0, 0), 1000, 2.0, false)
	ring = Blasts.record(ring, Vector3(0, 0, 6), 1100, 2.0, true)
	ck(bool(Blasts.match(ring, Vector3(0, 0, 6), 1200)["player"]),
		"из двух записей выбирается ближайшая")

func t_one_record_many_victims() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 2.0, true)
	var a: Dictionary = Blasts.match(ring, Vector3(0, 0, 5), 1100)
	var b: Dictionary = Blasts.match(ring, Vector3(0, 0, -5), 1100)
	ck(bool(a["player"]) and bool(b["player"]), "одна запись накрывает несколько жертв")
	ck(ring.size() == 1, "match не съедает запись")

func t_prune_explicit() -> void:
	var ring: Array = Blasts.record([], Vector3.ZERO, 1000, 2.0, false)
	ck(Blasts.prune(ring, 1500).size() == 1, "prune оставляет свежее")
	ck(Blasts.prune(ring, 5000).is_empty(), "prune чистит протухшее")
