extends SceneTree

const P = preload("res://mods/VTK/VTKPicker.gd")

var fails := 0

func ck(cond: bool, msg: String) -> void:
	if cond:
		print("ok    ", msg)
	else:
		fails += 1
		print("FAIL  ", msg)

# Поля AKM (значения сняты headless с res://Items/Weapons/AKM/AKM.tres).
func _akm() -> Dictionary:
	return {
		"magazineScale": 0.5, "magazineOffset": 5.0,
		"opticScale": 0.5, "opticOffset": -5.0,
		"suppressorScale": 0.45, "suppressorOffset": -20.0,
		"magazineOpticScale": 0.5, "magazineOpticOffset": 0.0,
		"magazineSuppressorScale": 0.45, "magazineSuppressorOffset": Vector2(-20.0, 5.0),
		"opticSuppressorScale": 0.45, "opticSuppressorOffset": Vector2(-20.0, -5.0),
		"fullyModdedScale": 0.45, "fullyModdedOffset": Vector2(-20.0, 0.0),
	}

func _init() -> void:
	t_class()
	t_pack()
	t_placement()
	print("")
	if fails == 0:
		print("Composite tests passed")
		quit(0)
	else:
		print("Composite tests failed: ", fails)
		quit(1)

func t_class() -> void:
	ck(P.attachment_class("Optic") == "optic", "Optic -> optic")
	ck(P.attachment_class("Muzzle") == "muzzle", "Muzzle -> muzzle")
	ck(P.attachment_class("Magazine") == "magazine", "Magazine -> magazine")
	ck(P.attachment_class("Stock") == "", "Stock -> пусто")
	ck(P.attachment_class(null) == "", "null -> пусто")

func t_pack() -> void:
	var a := _akm()
	ck(P.composite_pack(a, ["magazine"]) == {"scale": 0.5, "offset": Vector2(0, -5)},
		"только магазин -> magazineScale/Offset")
	ck(P.composite_pack(a, ["optic"]) == {"scale": 0.5, "offset": Vector2(0, 5)},
		"только прицел -> opticScale/Offset")
	ck(P.composite_pack(a, ["muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, 0)},
		"только дуло -> suppressorScale/Offset")
	ck(P.composite_pack(a, ["magazine", "optic"]) == {"scale": 0.5, "offset": Vector2(0, 0)},
		"маг+прицел -> magazineOptic*")
	ck(P.composite_pack(a, ["magazine", "muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, -5)},
		"маг+дуло -> magazineSuppressor*")
	ck(P.composite_pack(a, ["optic", "muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, 5)},
		"прицел+дуло -> opticSuppressor*")
	ck(P.composite_pack(a, ["magazine", "optic", "muzzle"]) == {"scale": 0.45, "offset": Vector2(-20, 0)},
		"все три -> fullyModded*")
	ck(P.composite_pack(a, []) == {"scale": 0.5, "offset": Vector2.ZERO},
		"без обвесов -> база 0.5/ZERO")
	ck(P.composite_pack({}, ["optic"]) == {"scale": 0.5, "offset": Vector2.ZERO},
		"пустой ресурс не падает, отдаёт базу")

func t_placement() -> void:
	# AKM в клетке Primary: cell=(2*70+3, 6*70+15)=(143,435), повёрнут.
	var cell := Vector2(143, 435)
	var place := P.composite_placement(Vector2(6, 2), cell, 8.0, {"scale": 0.5, "offset": Vector2.ZERO}, true)
	# fit = min(135/128, 427/384) = 1.0546875 -> scale = fit*0.5 = 0.52734375.
	ck(absf(float(place["scale"]) - 0.52734375) < 0.001, "масштаб композита = fit*pack.scale (не вдвое больше)")
	ck((place["position"] as Vector2).is_equal_approx(cell * 0.5), "нулевой offset центрирует композит")
	# Вписывается в клетку с падом: natural=size*128=(768,256), поворот -> bbox=(256,768)*scale.
	var s := float(place["scale"])
	ck(256.0 * s <= (cell.x - 8.0) + 0.5 and 768.0 * s <= (cell.y - 8.0) + 0.5, "композит не вылезает из клетки")
	var off := P.composite_placement(Vector2(6, 2), cell, 8.0, {"scale": 0.45, "offset": Vector2(0, -5)}, true)
	# offset (0,-5) поворачивается в (-5,0); позиция = cell/2 + (-5,0)*fit.
	ck((off["position"] as Vector2).is_equal_approx(cell * 0.5 + Vector2(-5.0, 0.0) * 1.0546875), "offset поворачивается и масштабируется fit")
