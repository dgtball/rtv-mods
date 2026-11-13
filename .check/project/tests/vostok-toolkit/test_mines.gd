extends SceneTree

const Mines = preload("res://mods/VTK/VTKMines.gd")

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
	t_mine_is_recognised()
	t_grenade_is_not_a_mine()
	t_partial_match_is_not_a_mine()
	print("")
	if fails == 0:
		print("Mines tests passed")
		quit(0)
	else:
		print("Mines tests failed: ", fails)
		quit(1)

class FakeMine extends Node3D:
	var isDetonated := false

	func Detonate() -> void:
		isDetonated = true

# Ванильная граната тоже объявляет Detonate(), но isDetonated у неё нет.
class FakeGrenade extends Node3D:
	func Detonate() -> void:
		pass

class FakeBomb extends Node3D:
	var isDetonated := false

# Свойство без метода и метод без свойства — не мина: иначе зона превратила бы
# гранату в мину с дистанционным взрывателем.
func t_mine_is_recognised() -> void:
	var mine := FakeMine.new()
	ck(Mines._is_mine(mine), "Detonate + isDetonated -> мина")
	mine.free()

func t_grenade_is_not_a_mine() -> void:
	var grenade := FakeGrenade.new()
	ck(not Mines._is_mine(grenade), "один Detonate без isDetonated -> не мина")
	grenade.free()

func t_partial_match_is_not_a_mine() -> void:
	var bomb := FakeBomb.new()
	ck(not Mines._is_mine(bomb), "isDetonated без Detonate -> не мина")
	bomb.free()
	ck(not Mines._is_mine(null), "null -> не мина")
