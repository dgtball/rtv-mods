extends RefCounted

# Стенд-аналог ванильного res://Scripts/SlotData.gd: тот же набор полей и
# Update/Reset, что в игре, но без полей лута — их объявляет оверрайд
# LooterShooter, и родитель не должен их дублировать.

var itemData = null
var amount: int = 1
var chamber: bool = false
var nested: Array = []
var condition = 100
var position = 0
var mode = 1
var zoom = 1
var casing = false
var state: String = ""
var storage: Array = []

func Update(slotData) -> void:
	itemData = slotData.itemData
	nested = slotData.nested.duplicate()
	storage = slotData.storage.duplicate()
	condition = slotData.condition
	amount = slotData.amount
	position = slotData.position
	mode = slotData.mode
	zoom = slotData.zoom
	chamber = slotData.chamber
	casing = slotData.casing
	state = slotData.state

func Reset() -> void:
	itemData = null
	nested.clear()
	storage.clear()
	condition = 100
	amount = 0
	position = 0
	mode = 1
	zoom = 1
	chamber = false
	casing = false
	state = ""
