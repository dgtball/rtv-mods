extends RefCounted
## Р§РёСЃС‚С‹Рµ СЂРµС€РµРЅРёСЏ РІС‹Р±РѕСЂР° РїСЂРµРґРјРµС‚РѕРІ: СЃР»РѕС‚С‹, С„РёР»СЊС‚СЂС‹, РїРѕР»РѕСЃС‹ РєР°С‚РµРіРѕСЂРёР№, РіСЂСѓРїРїС‹
## РѕР±РІРµСЃРѕРІ. РќРё load(), РЅРё РїСѓС‚РµР№ РІРЅСѓС‚СЂСЊ РёРіСЂС‹ - РїРѕСЌС‚РѕРјСѓ С„Р°Р№Р» С‚РµСЃС‚РёСЂСѓРµС‚СЃСЏ headless,
## РєР°Рє VTKDraft. Р’СЃС‘, С‡С‚Рѕ Р·РЅР°РµС‚ РїСЂРѕ СЂРµСЃСѓСЂСЃС‹, РїСЂРёС…РѕРґРёС‚ СЃРЅР°СЂСѓР¶Рё РіРѕС‚РѕРІС‹РјРё РґР°РЅРЅС‹РјРё.

# РџРѕСЂСЏРґРѕРє СЃР»РѕС‚РѕРІ РІ СЃРїРёСЃРєРµ РІС‹Р±РѕСЂР°. Р­С‚Рѕ РїСЂРµРґРїРѕС‡С‚РµРЅРёРµ, Р° РЅРµ Р¶С‘СЃС‚РєРёР№ СЃРїРёСЃРѕРє: СЃР»РѕС‚
# РёР· РґР°РЅРЅС‹С…, РєРѕС‚РѕСЂРѕРіРѕ Р·РґРµСЃСЊ РЅРµС‚, РЅРµ С‚РµСЂСЏРµС‚СЃСЏ, Р° РґРѕРїРёСЃС‹РІР°РµС‚СЃСЏ РІ РєРѕРЅРµС†. Р РЅР°РѕР±РѕСЂРѕС‚ -
# РїСЂРµРґРїРѕС‡С‚РёС‚РµР»СЊРЅРѕРіРѕ СЃР»РѕС‚Р°, РєРѕС‚РѕСЂРѕРіРѕ РІ РёРіСЂРµ РЅРµС‚, РІ СЃРїРёСЃРєРµ РЅРµ РїРѕСЏРІР»СЏРµС‚СЃСЏ, С‚Р°Рє С‡С‚Рѕ
# РїРѕСЃР»Рµ РѕР±РЅРѕРІР»РµРЅРёСЏ РёРіСЂС‹ РїСѓСЃС‚С‹С… СЃС‚СЂРѕРє РЅРµ РїСЂРёР±Р°РІРёС‚СЃСЏ.
const SLOT_ORDER := ["Primary", "Secondary", "Knife", "Grenade_1", "Grenade_2",
	"Backpack", "Rig", "Helmet", "Head", "Torso", "Legs", "Belt", "Feet",
	"Hands", "Light", "Time", "Map", "NVG", "Player", "Matches"]

# Р Р°СЃРєР»Р°РґРєР° СЃРµС‚РєРё СЌРєРёРїРёСЂРѕРІРєРё (РІР°СЂРёР°РЅС‚ E): С„РёРєСЃРёСЂРѕРІР°РЅРЅР°СЏ СЃРµС‚РєР° 6Г—8. Р—Р°РїРёСЃСЊ -
# [СЃР»РѕС‚, РєРѕР»РѕРЅРєР°, СЂСЏРґ, С€РёСЂРёРЅР°, РІС‹СЃРѕС‚Р°] РІ СЏС‡РµР№РєР°С…. РЎС‚РІРѕР»С‹ РІС‹С‚СЏРЅСѓС‚С‹ РІ СЂРѕСЃС‚
# (Primary 2Г—6, Secondary 2Г—4), РєСЂСѓРїРЅР°СЏ Р±СЂРѕРЅСЏ 2Г—2 (Helmet, Rig, Backpack),
# РЅРѕР¶/РіСЂР°РЅР°С‚С‹ Рё РјРµР»РѕС‡СЊ РїРѕ РєСЂР°СЏРј. РџРѕСЂСЏРґРѕРє С„РёРєСЃРёСЂРѕРІР°РЅ, РїРѕСЌС‚РѕРјСѓ СЂР°СЃРєР»Р°РґРєР°
# РѕРґРёРЅР°РєРѕРІР° РѕС‚ СЃРµС‚Р° Рє СЃРµС‚Сѓ; UI Р±РµСЂС‘С‚ РїРѕР·РёС†РёРё РѕС‚СЃСЋРґР°, Р° РЅРµ РґРµСЂР¶РёС‚ СЃРІРѕР№ СЃРїРёСЃРѕРє.
const EQUIP_GRID := [
	["Primary", 0, 0, 2, 6],
	["Helmet", 2, 0, 2, 2],
	["Secondary", 4, 0, 2, 4],
	["Rig", 2, 2, 2, 2],
	["Backpack", 2, 4, 2, 2],
	["Knife", 4, 4, 2, 1],
	["Grenade_1", 4, 5, 1, 1],
	["Grenade_2", 5, 5, 1, 1],
	["Head", 0, 6, 1, 1],
	["Torso", 1, 6, 1, 1],
	["Legs", 2, 6, 1, 1],
	["Belt", 3, 6, 1, 1],
	["Hands", 4, 6, 1, 1],
	["Feet", 5, 6, 1, 1],
	["Matches", 0, 7, 1, 1],
	["Light", 1, 7, 1, 1],
	["NVG", 2, 7, 1, 1],
	["Map", 3, 7, 1, 1],
	["Time", 4, 7, 1, 1],
	["Player", 5, 7, 1, 1],
]
const EQUIP_COLS := 6
const EQUIP_ROWS := 8

# Р“СЂСѓРїРїС‹ С€Р°РіР° 1 В«Р­РєРёРїРёСЂРѕРІРєР°В»: С‚РѕР»СЊРєРѕ С‚Рѕ, С‡С‚Рѕ РІСЃС‚Р°С‘С‚ РІ РєР»РµС‚РєСѓ СЃРµС‚РєРё, РїРѕ СЃР»РѕС‚Р°Рј.
# РџР°С‚СЂРѕРЅС‹, РѕР±РІРµСЃС‹, РµРґР°, РјРµРґРёС†РёРЅР°, РєР»СЋС‡Рё, РєРЅРёРіРё Рё РјРµР±РµР»СЊ СЃСЋРґР° РЅРµ РїРѕРїР°РґР°СЋС‚.
const EQUIP_GROUPS := [
	["weapon", "Weapons"],
	["clothing", "Clothing"],
	["gear", "Gear"],
	["hobby", "Hobby"],
]

# Р“СЂСѓРїРїС‹ С€Р°РіР° 2 В«РРЅРІРµРЅС‚Р°СЂСЊВ»: РІРµСЃСЊ РєР°С‚Р°Р»РѕРі РїРѕ РЅР°Р·РЅР°С‡РµРЅРёСЋ. РџРѕСЂСЏРґРѕРє - СЌС‚Рѕ РїРѕСЂСЏРґРѕРє
# СЃС‚СЂРѕРє РІ РєРѕР»РѕРЅРєРµ С„РёР»СЊС‚СЂРѕРІ.
const INVENTORY_GROUPS := [
	["weapon", "Weapons"],
	["ammo", "Ammo & attachments"],
	["clothing", "Clothing"],
	["gear", "Gear"],
	["medical", "Medical"],
	["food", "Food"],
	["tools", "Tools & sundries"],
	["furniture", "Furniture"],
]

# РЎР»РѕС‚ -> РіСЂСѓРїРїР° С€Р°РіР° 1. РЎР»РѕС‚Р°, РєРѕС‚РѕСЂРѕРіРѕ Р·РґРµСЃСЊ РЅРµС‚ (Armor Сѓ Р±СЂРѕРЅРµРїР»РёС‚), РЅР° С€Р°РіРµ 1
# РЅРµ СЃСѓС‰РµСЃС‚РІСѓРµС‚: С€Р°Рі РїРѕРєР°Р·С‹РІР°РµС‚ С‚РѕР»СЊРєРѕ С‚Рѕ, С‡С‚Рѕ РІСЃС‚Р°С‘С‚ РІ РєР»РµС‚РєСѓ. РћР±СЂР°С‚РЅРѕРµ С‚РѕР¶Рµ
# РІРµСЂРЅРѕ: РєР°Р¶РґР°СЏ РєР»РµС‚РєР° СЃРµС‚РєРё РѕР±СЏР·Р°РЅР° РёРјРµС‚СЊ РіСЂСѓРїРїСѓ, РёРЅР°С‡Рµ РѕРЅР° РєР»РёРєР°Р±РµР»СЊРЅР°, РЅРѕ
# РІСЃРµРіРґР° РѕС‚РІРµС‡Р°РµС‚ "Nothing fits" - С‚Р°Рє РІС‹РїР°Р» Player Сѓ РєР°СЃСЃРµС‚РЅРѕРіРѕ РїР»РµРµСЂР°.
const EQUIP_SLOT_GROUPS := {
	"Primary": "weapon", "Secondary": "weapon", "Knife": "weapon",
	"Grenade_1": "weapon", "Grenade_2": "weapon",
	"Feet": "clothing", "Legs": "clothing", "Belt": "clothing",
	"Torso": "clothing", "Head": "clothing", "Hands": "clothing",
	"Helmet": "clothing", "Backpack": "clothing", "Rig": "clothing",
	"Light": "gear", "NVG": "gear", "Time": "gear", "Map": "gear",
	"Matches": "gear", "Player": "gear",
}

# РЎР»РѕС‚ -> РїРѕРґРїРёСЃСЊ РїРѕРґРєР°С‚РµРіРѕСЂРёРё С€Р°РіР° 1. РўРѕР¶РґРµСЃС‚РІРѕ, РєСЂРѕРјРµ РіСЂР°РЅР°С‚: РґРІР° РіРЅРµР·РґР° -
# РѕРґРёРЅ С‡РёРї.
const SLOT_SUBS := {"Grenade_1": "Grenade", "Grenade_2": "Grenade"}

# РљР»Р°СЃСЃС‹ РїСЂРµРґРјРµС‚РѕРІ, РєРѕС‚РѕСЂС‹Рµ С„РѕСЂРјР°Р»СЊРЅРѕ РїРѕРјРµС‡РµРЅС‹ Primary/Secondary, РЅРѕ РѕСЂСѓР¶РёРµРј РЅРµ
# СЏРІР»СЏСЋС‚СЃСЏ. РџСЂРѕРІРµСЂСЏСЋС‚СЃСЏ СЂР°РЅСЊС€Рµ СЃР»РѕС‚РѕРІ.
const HOBBY_TYPES := ["fishing", "instrument"]

# РўРёРї РёР· РґР°РЅРЅС‹С… -> РіСЂСѓРїРїР° С€Р°РіР° 2. РЎРёРЅРѕРЅРёРјС‹ Р¶РёРІСѓС‚ Р·РґРµСЃСЊ Р¶Рµ: РёРіСЂР° РѕС‚РґР°С‘С‚ Рё
# "Consumable", Рё "Consumables", СЂР°Р·РіСЂСѓР·РєСѓ РєР°Рє "Rig", РїРѕРґСЃСѓРјРѕРє РєР°Рє
# "Belt Pouch", С€Р»РµРј РєР°Рє "Helmet", СЂСЋРєР·Р°Рє РєР°Рє "Backpack". РќРµР·РЅР°РєРѕРјС‹Р№ С‚РёРї
# СЃСЋРґР° РЅРµ РїРѕРїР°РґР°РµС‚ Рё РіСЂСѓРїРїС‹ РЅРµ РїРѕР»СѓС‡Р°РµС‚.
const TYPE_GROUPS := {
	"weapon": "weapon", "knife": "weapon", "grenade": "weapon",
	"ammo": "ammo", "attachment": "ammo",
	"clothing": "clothing", "rig": "clothing", "belt pouch": "clothing",
	"helmet": "clothing", "backpack": "clothing", "armor": "clothing",
	"medical": "medical",
	"consumable": "food", "consumables": "food", "fish": "food",
	"fishing": "gear", "instrument": "gear",
	"misc": "tools", "key": "tools",
	"literature": "tools", "lore": "tools", "electronics": "tools",
	"furniture": "furniture",
}

# РЎР»РѕС‚С‹, РєРѕС‚РѕСЂС‹Рµ СЃР°РјРё РЅР°Р·С‹РІР°СЋС‚ РєР»Р°СЃСЃ РїСЂРµРґРјРµС‚Р°: Сѓ С„РѕРЅР°СЂРёРєР°, РџРќР’, С‡Р°СЃРѕРІ, РєР°СЂС‚С‹ Рё
# СЃРїРёС‡РµРє РїР°РїРєР° РјРѕРґРµР»Рё (Polaris, PV7) РЅРёС‡РµРіРѕ РЅРµ РіРѕРІРѕСЂРёС‚.
const GEAR_SLOTS := ["Light", "NVG", "Time", "Map", "Matches"]

static var _art_cache: Dictionary = {}
static var _subcat_cache: Dictionary = {}

# РљСЂРѕРї РЅРµРїСЂРѕР·СЂР°С‡РЅРѕР№ РѕР±Р»Р°СЃС‚Рё РёРєРѕРЅРєРё: AtlasTexture РЅР° РѕСЂРёРіРёРЅР°Р»СЊРЅРѕРј СЂРµСЃСѓСЂСЃРµ, С„Р°Р№Р»С‹
# РёРіСЂС‹ РЅРµ С‚СЂРѕРіР°РµС‚. used_rect СЂР°СЃС€РёСЂРµРЅ РЅР° 3 РїРёРєСЃРµР»СЏ Рё РѕР±СЂРµР·Р°РЅ РїРѕ РіСЂР°РЅРёС†Рµ С‚РµРєСЃС‚СѓСЂС‹,
# filter_clip СѓР±РёСЂР°РµС‚ СЂР°Р·РјС‹С‚РёРµ РїРѕ РєСЂР°СЋ. РљСЌС€ РїРѕ resource_path: РїСѓС‚СЊ СЃС‚Р°Р±РёР»РµРЅ, Р°
# instance_id - Р°РґСЂРµСЃ РѕР±СЉРµРєС‚Р°, Рё РїРѕСЃР»Рµ РїРµСЂРµР·Р°РіСЂСѓР·РєРё РєР°С‚Р°Р»РѕРіР° РѕСЃРІРѕР±РѕР¶РґС‘РЅРЅС‹Р№ id
# РјРѕРі РґРѕСЃС‚Р°С‚СЊСЃСЏ С‡СѓР¶РѕР№ С‚РµРєСЃС‚СѓСЂРµ (Сѓ СЃРѕР±СЃС‚РІРµРЅРЅРѕСЃС‚Рё Р±РµР· РїСѓС‚Рё РѕСЃС‚Р°С‘С‚СЃСЏ С„РѕР»Р±СЌРє РЅР°
# instance_id).
#
# rotate СЂР°Р·РІРѕСЂР°С‡РёРІР°РµС‚ РєСЂРѕРї РЅР° 90В° РїСЂРѕС‚РёРІ С‡Р°СЃРѕРІРѕР№ (РґСѓР»Рѕ РІРІРµСЂС…) Рё РѕС‚РґР°С‘С‚
# ImageTexture: Сѓ СЃС‚РІРѕР»РѕРІ РёРєРѕРЅРєР° РІС‹С‚СЏРЅСѓС‚Р° РІРґРѕР»СЊ РіРѕСЂРёР·РѕРЅС‚Р°Р»Рё, Р° РєР»РµС‚РєР° Primary/
# Secondary РІС‹С‚СЏРЅСѓС‚Р° РїРѕ РІРµСЂС‚РёРєР°Р»Рё. РћСЂРёРіРёРЅР°Р» РЅРµ РјСѓС‚РёСЂСѓРµРј - get_region РєРѕРїРёСЂСѓРµС‚.
# РљСЌС€ СЂР°Р·РІРµРґС‘РЅ РЅР° РґРІР° РєР»СЋС‡Р° РЅР° РѕРґРЅСѓ С‚РµРєСЃС‚СѓСЂСѓ (РїРѕРІС‘СЂРЅСѓС‚С‹Р№ Рё РЅРµС‚): РѕРґРЅР° Рё С‚Р°
# Р¶Рµ РёРєРѕРЅРєР° РІСЃС‚СЂРµС‡Р°РµС‚СЃСЏ Рё РІ СЃР»РѕС‚Рµ РѕСЂСѓР¶РёСЏ, Рё РІ РєР°С‚Р°Р»РѕРіРµ.
static func item_art(texture: Texture2D, rotate := false) -> Texture2D:
	if texture == null:
		return null
	var path: String = texture.resource_path
	var base: String = path if path != "" else str(texture.get_instance_id())
	var ckey := base + (":r" if rotate else "")
	if _art_cache.has(ckey):
		return _art_cache[ckey]
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	var used := image.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return texture
	var rect := Rect2(used).grow(3.0).intersection(Rect2(Vector2.ZERO, texture.get_size()))
	if rect.size.x <= 0 or rect.size.y <= 0:
		return texture
	var art: Texture2D
	if rotate:
		var region := image.get_region(Rect2i(rect))
		region.rotate_90(ClockDirection.COUNTERCLOCKWISE)
		art = ImageTexture.create_from_image(region)
	else:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = rect
		atlas.filter_clip = true
		art = atlas
	_art_cache[ckey] = art
	return art

static func clear_cache() -> void:
	# РљР°С‚Р°Р»РѕРі РїРµСЂРµСЃРѕР±СЂР°РЅ - РєРµС€ РѕС‚ РїСЂРѕС€Р»РѕРіРѕ РЅР°Р±РѕСЂР° СЂРµСЃСѓСЂСЃРѕРІ С‚РµСЂСЏРµС‚ СЃРјС‹СЃР»; С‚РѕС‚ Р¶Рµ
	# РєРѕРЅС‚СЂР°РєС‚, С‡С‚Рѕ Сѓ С‡РёСЃС‚РєРё РєРµС€РµР№ ItemStore (info/РёРєРѕРЅРєРё).
	_art_cache.clear()
	_subcat_cache.clear()

static func clear() -> void:
	clear_cache()

static func clear_art_cache() -> void:
	_art_cache.clear()

static func clear_subcat_cache() -> void:
	_subcat_cache.clear()

# РљР»СЋС‡Рё С‚Р°Р±Р»РёС†С‹ РіСЂСѓРїРї РІ РµС‘ РїРѕСЂСЏРґРєРµ: [["weapon", "Weapons"], ...] -> ["weapon", ...].
static func group_keys(groups: Array) -> Array:
	var out: Array = []
	for entry in groups:
		out.append(str(entry[0]))
	return out

# РџРѕРґРїРёСЃСЊ РіСЂСѓРїРїС‹ РїРѕ РєР»СЋС‡Сѓ. РќРµРёР·РІРµСЃС‚РЅС‹Р№ РєР»СЋС‡ РЅРµ РІРѕР·РІСЂР°С‰Р°РµС‚СЃСЏ СЃС‹СЂС‹Рј: capitalize()
# РґР°С‘С‚ "Furniture", Р° РЅРµ "furniture".
static func group_label(groups: Array, key: String) -> String:
	for entry in groups:
		if str(entry[0]) == key:
			return str(entry[1])
	return key.capitalize()

# РќР°Р±РѕСЂ СЃР»РѕС‚РѕРІ РїСЂРµРґРјРµС‚Р° Р±РµР· РјСѓСЃРѕСЂР°: null Рё СЃС‚СЂРѕРєР° РІРјРµСЃС‚Рѕ РјР°СЃСЃРёРІР° - РїСѓСЃС‚РѕР№ РЅР°Р±РѕСЂ.
# unique СЃР»РёРІР°РµС‚ РїРѕРІС‚РѕСЂС‹ - СЌС‚РѕРіРѕ Р¶РґС‘С‚ Р°РІС‚Рѕ-СЌРєРёРї (VTKEquip); РєР°С‚Р°Р»РѕРі Рё С„Р°СЃРµС‚С‹
# РїРѕСЂСЏРґРєР° РЅРµ РјРµРЅСЏСЋС‚, РїРѕСЌС‚РѕРјСѓ РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ РїРѕРІС‚РѕСЂС‹ СЃРѕС…СЂР°РЅСЏСЋС‚СЃСЏ. Р•РґРёРЅСЃС‚РІРµРЅРЅС‹Р№
# РЅРѕСЂРјР°Р»РёР·Р°С‚РѕСЂ СЃР»РѕС‚РѕРІ РІ РјРѕРґРµ: ItemStore Рё Equip С…РѕРґСЏС‚ СЃСЋРґР°.
static func slot_list(slots, unique := false) -> Array:
	if typeof(slots) != TYPE_ARRAY:
		return []
	var out: Array = []
	for s in slots:
		if s == null:
			continue
		var n := str(s)
		if n == "":
			continue
		if unique and out.has(n):
			continue
		out.append(n)
	return out

# Р“СЂСѓРїРїР° С€Р°РіР° 1 РїРѕ СЃР»РѕС‚Сѓ. РҐРѕР±Р±Рё РїСЂРѕРІРµСЂСЏРµС‚СЃСЏ СЂР°РЅСЊС€Рµ СЃР»РѕС‚РѕРІ: СѓРґРёР»РёС‰Рµ Рё РіРёС‚Р°СЂР°
# С„РѕСЂРјР°Р»СЊРЅРѕ РїРѕРјРµС‡РµРЅС‹ Primary/Secondary, РЅРѕ РѕСЂСѓР¶РёРµРј РЅРµ СЏРІР»СЏСЋС‚СЃСЏ.
static func equip_group_of(type, slots) -> String:
	if type != null and HOBBY_TYPES.has(str(type).strip_edges().to_lower()):
		return "hobby"
	for s in slot_list(slots):
		if EQUIP_SLOT_GROUPS.has(s):
			return str(EQUIP_SLOT_GROUPS[s])
	return ""

# РџРѕРґРєР°С‚РµРіРѕСЂРёРё С€Р°РіР° 1 - СЌС‚Рѕ РїРѕРґРїРёСЃРё РµРіРѕ СЃР»РѕС‚РѕРІ. РЈ Hobby РёС… РЅРµС‚: СѓРґРёР»РёС‰Рµ Рё
# РіРёС‚Р°СЂР° СЃС‚РѕСЏС‚ РІ РіСЂСѓРїРїРµ РїРѕ РѕРґРЅРѕРјСѓ-РґРІР°, С‡РёРї РІРЅСѓС‚СЂРё РЅРµС‘ РЅРёС‡РµРіРѕ РЅРµ РґРѕР±Р°РІР»СЏРµС‚.
static func equip_subs_of(type, slots) -> Array:
	if equip_group_of(type, slots) == "hobby":
		return []
	var out: Array = []
	for s in slot_list(slots):
		if not EQUIP_SLOT_GROUPS.has(s):
			continue
		var sub := str(SLOT_SUBS.get(s, s))
		if not out.has(sub):
			out.append(sub)
	return out

# Р“СЂСѓРїРїР° С€Р°РіР° 2. РЎР»РѕС‚ РІР°Р¶РЅРµРµ type: РѕРЅ Рё РµСЃС‚СЊ РјРµСЃС‚Рѕ, РєСѓРґР° РїСЂРµРґРјРµС‚ РІСЃС‚Р°С‘С‚. РўР°Рє
# СЌР»РµРєС‚СЂРѕРЅРёРєР° СЃРѕ СЃР»РѕС‚РѕРј Light/Time/Map/Matches СѓС…РѕРґРёС‚ РІ Gear, Р° РіСЂР°РЅР°С‚Р° - РІ
# Weapons. РћСЃС‚Р°Р»СЊРЅРѕРµ СЂРµС€Р°РµС‚ type С‡РµСЂРµР· TYPE_GROUPS.
static func inventory_group_of(type, slots) -> String:
	for s in slot_list(slots):
		if GRENADE_SLOTS.has(s):
			return "weapon"
		if GEAR_SLOTS.has(s):
			return "gear"
	var t := "" if type == null else str(type).strip_edges().to_lower()
	return str(TYPE_GROUPS.get(t, ""))

# РџРѕСЂСЏРґРѕРє РїРѕРґРєР°С‚РµРіРѕСЂРёР№ - РѕРґРёРЅ РЅР° РѕР±Р° С€Р°РіР°: РІРїРµСЂРµРґРё РїРѕРґРїРёСЃРё СЃР»РѕС‚РѕРІ С€Р°РіР° 1 РІ
# РїРѕСЂСЏРґРєРµ SLOT_ORDER, Р·Р°С‚РµРј РєР»Р°СЃСЃС‹ РїСЂРµРґРјРµС‚РѕРІ С€Р°РіР° 2 (РєР°Рє Р·Р°РіРѕР»РѕРІРєРё "-- X --" РІ
# JCMDatabase.gd), РІ РєРѕРЅС†Рµ РіСЂСѓРїРїС‹ РјРµР±РµР»Рё РёР· FURN_SUB_FOLDERS: Сѓ РјРµР±РµР»Рё РїРѕРґРїРёСЃСЊ
# СЃС‡РёС‚Р°РµС‚СЃСЏ РїРѕ РїР°РїРєРµ Р°СЃСЃРµС‚Р°, Р° РЅРµ РїРѕ SUB_FOLDERS.
const SUBCATEGORY_ORDER := [
	# РЎР»РѕС‚С‹ С€Р°РіР° 1. Р“СЂР°РЅР°С‚С‹ СЃС…Р»РѕРїРЅСѓС‚С‹ РІ РѕРґРёРЅ С‡РёРї.
	"Primary", "Secondary", "Knife", "Grenade", "Backpack", "Rig", "Helmet",
	"Head", "Torso", "Legs", "Belt", "Feet", "Hands", "Light", "Time", "Map",
	"NVG", "Player", "Matches",
	# РљР»Р°СЃСЃС‹ С€Р°РіР° 2.
	"Assault Rifles", "Sniper Rifles", "Shotguns", "Pistols", "SMGs",
	"Knives", "Grenades",
	"Handgun & SMG Mags", "Rifle & Sniper Mags",
	"Pistol & SMG Calibers", "Rifle Calibers", "Shotgun Shells",
	"First Aid", "Medication", "Utility",
	"Helmets", "Armor Plates", "Rigs & Vests", "Backpacks",
	"Belts", "Hats", "Pants", "Boots & Hands",
	"Weapon Parts", "Scopes", "Suppressors", "Lasers",
	"Hydration", "Canned Goods", "Snacks & Ingredients", "Cooked Meals",
	"Vices", "Fish", "Garbage",
	"Utilities & Tools", "Music", "Fishing", "Lore",
	"Keys", "Books", "Electronics",
	"Storage & Cabinets", "Seating & Beds", "Tables & Shelving",
	"Appliances & Electronics", "Decor"]

# РРјСЏ РїР°РїРєРё -> РїРѕРґРєР°С‚РµРіРѕСЂРёСЏ. РљР»СЋС‡ - С‚СЂРµС‚РёР№ СЃРµРіРјРµРЅС‚ РїСѓС‚Рё
# ("res://Items/Weapons/AKM/AKM.tres" -> "AKM"), РїРѕС‚РѕРјСѓ С‡С‚Рѕ РІС‚РѕСЂРѕР№ СЃРµРіРјРµРЅС‚
# РїРѕРІС‚РѕСЂСЏРµС‚СЃСЏ: "Weapons" РІ JCM РІСЃС‚СЂРµС‡Р°РµС‚СЃСЏ СЃРµРјСЊ СЂР°Р·. РџСѓС‚Рё РІ РёРіСЂСѓ Р·РґРµСЃСЊ РЅРµ
# С…СЂР°РЅСЏС‚СЃСЏ - С‚РѕР»СЊРєРѕ РёРјРµРЅР° РїР°РїРѕРє, РїРѕСЌС‚РѕРјСѓ Р°РїРґРµР№С‚ РёРіСЂС‹ С‚Р°Р±Р»РёС†Сѓ РЅРµ Р»РѕРјР°РµС‚.
const SUB_FOLDERS := {
	# РћСЂСѓР¶РёРµ
	"AK-12": "Assault Rifles", "AKM": "Assault Rifles",
	"AKS-74U": "Assault Rifles", "HK416": "Assault Rifles",
	"KAR-21": "Assault Rifles", "M4A1": "Assault Rifles",
	"MK18": "Assault Rifles", "RK-62": "Assault Rifles",
	"RK-95": "Assault Rifles",
	"M28": "Sniper Rifles", "M78": "Sniper Rifles", "Mosin": "Sniper Rifles",
	"SVD": "Sniper Rifles", "VSS": "Sniper Rifles",
	"Remington_870": "Shotguns",
	"Colt_1911": "Pistols", "Glock_17": "Pistols", "HP-DA": "Pistols",
	"Makarov": "Pistols", "P320": "Pistols",
	"Jatimatic": "SMGs", "KP-31": "SMGs", "MP5": "SMGs", "MP5K": "SMGs",
	"MP5SD": "SMGs", "MP7": "SMGs",
	# Р‘РѕРµРїСЂРёРїР°СЃС‹
	"Ammo_45ACP": "Pistol & SMG Calibers", "Ammo_46x30": "Pistol & SMG Calibers",
	"Ammo_9x18": "Pistol & SMG Calibers", "Ammo_9x19": "Pistol & SMG Calibers",
	"Ammo_9x39": "Pistol & SMG Calibers",
	"Ammo_223": "Rifle Calibers", "Ammo_308": "Rifle Calibers",
	"Ammo_545x39": "Rifle Calibers", "Ammo_762x39": "Rifle Calibers",
	"Ammo_762x54R": "Rifle Calibers", "Ammo_12x70": "Shotgun Shells",
	# РњРµРґРёС†РёРЅР°
	"AFAK": "First Aid", "Bandage": "First Aid",
	"Bandage_Improvised": "First Aid", "IFAK": "First Aid",
	"Medkit": "First Aid", "Splint": "First Aid",
	"Splint_Improvised": "First Aid", "Tourniquet": "First Aid",
	"Tourniquet_Improvised": "First Aid",
	"Antibiotics": "Medication", "Cold_Medicine": "Medication",
	"Melatonin": "Utility", "Painkillers": "Medication",
	"Antiseptic": "Utility", "Balm": "Utility",
	"Deodorant": "Utility", "Gum": "Utility",
	"Lotion": "Utility", "Saline": "Utility",
	"Thermal_Blanket": "Utility",
	"Tissues": "Utility", "Wipes": "Utility",
	# РЎРЅР°СЂСЏР¶РµРЅРёРµ
	"Helmet_Police": "Helmets", "SSh-39": "Helmets",
	"LVPC": "Rigs & Vests", "K19": "Rigs & Vests",
	"Vest_Fishing": "Rigs & Vests",
	"Backpack_Jaeger": "Backpacks", "Backpack_Kantamus": "Backpacks",
	"Backpack_Nomad": "Backpacks", "Backpack_Patrol": "Backpacks",
	"Duffel_Retro": "Backpacks",
	"Kukkaro": "Belts",
	"Beanie_Flame": "Hats", "Cap_M62": "Hats", "Hat_Foil": "Hats",
	"Hat_Mosquito": "Hats", "Hat_Sauna": "Hats",
	"Fleece_Tactical_Brown": "Torso", "Fleece_Tactical_Green": "Torso",
	"Hoodie_Border_Zone": "Torso", "Hoodie_Gray": "Torso",
	"Jacket_M62": "Torso", "Jacket_Santa": "Torso",
	"Jacket_Winter_Blue": "Torso", "Jacket_Winter_Red": "Torso",
	"Windbreaker_Black": "Torso", "Windbreaker_Green": "Torso",
	"Jeans_Black": "Pants", "Pants_Hiking": "Pants",
	"Boots_Combat": "Boots & Hands", "Gloves_Leather": "Boots & Hands",
	"Gloves_Work": "Boots & Hands",
	# РћР±РІРµСЃС‹. РўСЂРё РїРѕРґРєР°С‚РµРіРѕСЂРёРё РїРѕ РґР°РЅРЅС‹Рј РёРіСЂС‹: subtype Optic РґР°С‘С‚ Scopes,
	# Laser - Lasers, Muzzle - РіР»СѓС€РёС‚РµР»Рё.
	"ACOG": "Scopes", "EXPS": "Scopes", "HMR": "Scopes", "Kobra": "Scopes",
	"Leopard": "Scopes", "MRO": "Scopes", "Micro": "Scopes",
	"POSP": "Scopes", "PRO": "Scopes", "PU": "Scopes", "RMR": "Scopes",
	"SRO": "Scopes", "Vudu": "Scopes",
	"OZ5": "Lasers", "ANPEQ": "Lasers",
	"Hybrid": "Suppressors", "Monster": "Suppressors", "Navy": "Suppressors",
	"PBS": "Suppressors", "PTN": "Suppressors", "Rider": "Suppressors",
	"Salvo": "Suppressors", "Thor": "Suppressors", "SOCOM": "Suppressors",
	# Р•РґР°
	"Energy_Drink": "Hydration", "Juice_Orange": "Hydration",
	"Juice_Pear": "Hydration", "Juice_Raspberry": "Hydration",
	"Soda_Lemon": "Hydration", "Water_Bottle": "Hydration",
	"Canned_Meat": "Canned Goods", "Canned_Meatballs": "Canned Goods",
	"Canned_Pea_Soup": "Canned Goods", "Canned_Peaches": "Canned Goods",
	"Canned_Peas": "Canned Goods",
	"Canned_Pear": "Canned Goods",
	"Canned_Pineapple": "Canned Goods", "Canned_Tomatoes": "Canned Goods",
	"Canned_Tuna": "Canned Goods", "Cat_Food": "Canned Goods",
	"Chocolate_War": "Snacks & Ingredients", "Coffee": "Snacks & Ingredients",
	"Crackers": "Snacks & Ingredients", "Energy_Powder": "Snacks & Ingredients",
	"Field_Ration": "Cooked Meals", "Jam": "Snacks & Ingredients",
	"Mustard": "Snacks & Ingredients", "Peanuts": "Snacks & Ingredients",
	"Potato": "Snacks & Ingredients", "Salty_Liquorice": "Snacks & Ingredients",
	"Sugar": "Snacks & Ingredients", "Yeast": "Snacks & Ingredients",
	"Coffee_Brewed": "Cooked Meals", "Cooked_Fish_Soup": "Cooked Meals",
	"Cooked_Meatballs": "Cooked Meals", "Cooked_Pea_Soup": "Cooked Meals",
	"Cooked_Tomato_Soup": "Cooked Meals", "Kompot": "Cooked Meals",
	"Beer": "Vices", "Cigarettes": "Vices", "Cigars": "Vices", "Kilju": "Vices",
	"Snus": "Vices",
	"Bream": "Fish", "Perch": "Fish", "Pike": "Fish", "Roach": "Fish",
	# РџСѓСЃС‚Р°СЏ С‚Р°СЂР°: РЅРµ СЂР°СЃС…РѕРґРЅРёРє, Р° РјСѓСЃРѕСЂ.
	"Can_Empty": "Garbage", "Soda_Empty": "Garbage",
	# Р Р°Р·РЅРѕРµ. РљР»СЋС‡Рё, РєРЅРёРіРё, РЅРѕР¶Рё, СЌР»РµРєС‚СЂРѕРЅРёРєР° Рё РіСЂР°РЅР°С‚С‹ СЃСЋРґР° РЅРµ РїРѕРїР°РґР°СЋС‚: РёС…
	# РєР»Р°СЃСЃ РЅР°Р·С‹РІР°РµС‚СЃСЏ С‚РёРїРѕРј РёР»Рё СЃР»РѕС‚РѕРј, Р° РЅРµ РїР°РїРєРѕР№ РјРѕРґРµР»Рё.
	"Aluminum_Foil": "Utilities & Tools", "Duct_Tape": "Utilities & Tools",
	"Happy_Stove": "Utilities & Tools", "Jerry_Can": "Utilities & Tools",
	"Lumber": "Utilities & Tools", "Matches": "Utilities & Tools",
	"Mess_Kit": "Utilities & Tools", "Nails": "Utilities & Tools",
	"Oil_Filter": "Utilities & Tools", "Sticks": "Utilities & Tools",
	"Tarp": "Utilities & Tools", "Toolbox": "Utilities & Tools", "Water_Lock": "Utilities & Tools",
	"Weapon_Repair_Kit": "Utilities & Tools",
	"Blanket": "Utilities & Tools", "Board_Game": "Utilities & Tools",
	"Bucket": "Utilities & Tools", "Coffee_Filter": "Utilities & Tools",
	"Map": "Utilities & Tools", "Map_Tactical": "Utilities & Tools",
	"Mattress": "Utilities & Tools", "Pillow": "Utilities & Tools",
	"Rags": "Utilities & Tools", "Sleeping_Bag": "Utilities & Tools",
	"Toilet_Paper": "Utilities & Tools",
	"Fishing_Rod": "Fishing", "Tackle_Box": "Fishing",
	"Guitar": "Music", "Harmonica": "Music",
	"Cat": "Lore", "Oil_Sample": "Lore", "Patient_Report": "Lore",
	# РЎРІРµСЂРЅСѓС‚С‹Рµ РѕРґРёРЅРѕС‡РЅС‹Рµ С‡РёРїС‹: РїРѕРґ РєР°Р¶РґС‹Рј РёР· СЌС‚РёС… РїСЂРµРґРјРµС‚РѕРІ Р±С‹Р»Р° СЃРІРѕСЏ РїР°РїРєР°,
	# РЅРѕ РіСЂСѓРїРїР° РёР· РѕРґРЅРѕРіРѕ РїСЂРµРґРјРµС‚Р° РЅРµ РЅСѓР¶РЅР° - СѓРІРѕРґРёРј РІ Р±Р»РёР¶Р°Р№С€СѓСЋ СЃСѓС‰РµСЃС‚РІСѓСЋС‰СѓСЋ.
	"Hand_Warmer": "Utility",
	"Suitcase_Driver": "Lore",
	"Air_Freshener": "Utilities & Tools",
	"Glue": "Utilities & Tools",
	"Leather": "Utilities & Tools",
	"Museum_Plate": "Utilities & Tools",
	"Radiator_Engine": "Utilities & Tools",
	"Screws": "Utilities & Tools",
	# Р‘СЂРѕРЅРµРїР»РёС‚С‹: РїР°РїРєРё РЅРµС‚, РїСѓС‚СЊ С‚СЂС‘С…СЃРµРіРјРµРЅС‚РЅС‹Р№, РєР»СЋС‡ - РёРјСЏ С„Р°Р№Р»Р°.
	"Armor_Plate_II": "Armor Plates", "Armor_Plate_IIIA": "Armor Plates",
	"Armor_Plate_III": "Armor Plates", "Armor_Plate_III+": "Armor Plates",
	"Armor_Plate_IV": "Armor Plates",
	}

# РџРѕРґРєР°С‚РµРіРѕСЂРёРё РјРµР±РµР»Рё. РџСѓС‚СЊ РјРµР±РµР»Рё: res://Assets/<РџР°РїРєР°>/..._F.tres, РїРѕСЌС‚РѕРјСѓ
# РєР»СЋС‡ - РІС‚РѕСЂРѕР№ СЃРµРіРјРµРЅС‚ РїСѓС‚Рё, Р° РЅРµ РїСЂРµРґРїРѕСЃР»РµРґРЅРёР№, РєР°Рє РІ SUB_FOLDERS. РџР°РїРєР°,
# РєРѕС‚РѕСЂРѕР№ РЅРµС‚ РІ С‚Р°Р±Р»РёС†Рµ, РѕСЃС‚Р°С‘С‚СЃСЏ Р±РµР· С‡РёРїР°.
const FURN_SUB_FOLDERS := {
	"Bookshelf": "Decor",
	"Cabinet_Medical": "Storage & Cabinets",
	"Cabinet_Office": "Storage & Cabinets",
	"Cabinet_Wood": "Storage & Cabinets",
	"Crate_Military": "Storage & Cabinets",
	"Crate_Special": "Storage & Cabinets",
	"Cupboard": "Decor",
	"Locker": "Storage & Cabinets",
	"Nightstand": "Storage & Cabinets",
	"Bed_Civilian": "Seating & Beds",
	"Bed_Nomad": "Seating & Beds",
	"Bench_Campsite": "Seating & Beds",
	"Chair_Office": "Seating & Beds",
	"Chair_School": "Seating & Beds",
	"Chair_Sun": "Seating & Beds",
	"Sofa_Leather": "Seating & Beds",
	"Stool_Military": "Seating & Beds",
	"Stool_Padded": "Seating & Beds",
	"Shelf_Metal": "Tables & Shelving",
	"Shelf_Wall": "Tables & Shelving",
	"Shelf_Wood": "Tables & Shelving",
	"Table_Cabin": "Tables & Shelving",
	"Table_Canteen": "Tables & Shelving",
	"Table_Kitchen": "Tables & Shelving",
	"Table_Office": "Tables & Shelving",
	"Freezer": "Appliances & Electronics",
	"Fridge": "Appliances & Electronics",
	"Radio": "Appliances & Electronics",
	"Stove": "Appliances & Electronics",
	"Television": "Appliances & Electronics",
	"Calendar": "Decor",
	"Carpet": "Decor",
	"Curtains": "Decor",
	"Dartboard": "Decor",
	"Painting": "Decor",
	"Pallet": "Decor",
	"Posters": "Decor",
	"Rack_Coat": "Decor",
	"Rya": "Decor",
	"Sign_Border_Zone": "Decor",
	"Target_Stand": "Decor",
	"Trolley": "Decor",
	"Weapon_Display": "Decor",
}

# РџР°РїРєРё, С‡РµР№ РјР°РіР°Р·РёРЅ РѕС‚РЅРѕСЃРёС‚СЃСЏ Рє РїРёСЃС‚РѕР»РµС‚Р°Рј Рё РџРџ. РћСЃС‚Р°Р»СЊРЅС‹Рµ СЃС‚РІРѕР»С‹ РґР°СЋС‚
# Rifle & Sniper Mags. РЎРїРёСЃРѕРє РЅСѓР¶РµРЅ РїРѕС‚РѕРјСѓ, С‡С‚Рѕ РїР°РїРєР° Сѓ РјР°РіР°Р·РёРЅР° С‚Р° Р¶Рµ, С‡С‚Рѕ
# Сѓ СЃС‚РІРѕР»Р°: Сѓ Makarov РѕРЅР° РѕРґРЅР° РЅР° Pistols Рё РЅР° Handgun & SMG Mags.
const MAG_FOLDERS := ["Makarov", "Colt_1911", "Glock_17", "P320", "HP-DA",
	"MP5", "MP5SD", "MP7", "Jatimatic", "KP-31", "MP5K"]

# РЎСѓС„С„РёРєСЃ РёРјРµРЅРё С„Р°Р№Р»Р°, РїРѕ РєРѕС‚РѕСЂС‹Рј РїСЂРµРґРјРµС‚ РѕРїРѕР·РЅР°С‘С‚СЃСЏ РєР°Рє РјР°РіР°Р·РёРЅ РёР»Рё С‡Р°СЃС‚СЊ
# СЃС‚РІРѕР»Р°, СЂР°РЅСЊС€Рµ СЂР°Р·Р±РѕСЂР° РїР°РїРєРё. Р‘РµР· СЌС‚РѕРіРѕ KAR-21_Barrel РїРѕРїР°Р» Р±С‹ РІ
# Assault Rifles, Р° Makarov_Magazine - РІ Pistols.
const MAG_SUFFIXES := ["_Magazine", "_Mag", "_Drum"]
const WEAPON_PART_SUFFIXES := ["_Barrel", "_Muzzle", "_Grip"]


# Р’СЃРµ СЃР»РѕС‚С‹, РІСЃС‚СЂРµС‡Р°СЋС‰РёРµСЃСЏ Сѓ РїСЂРµРґРјРµС‚РѕРІ, РІ РїСЂРµРґРїРѕС‡С‚РёС‚РµР»СЊРЅРѕРј РїРѕСЂСЏРґРєРµ.
# РќР° РІС…РѕРґ - СЃРїРёСЃРѕРє СЃРїРёСЃРєРѕРІ СЃР»РѕС‚РѕРІ, РєР°Рє РёС… РѕС‚РґР°С‘С‚ item.slots.
static func all_slots(slot_lists) -> Array:
	var found := {}
	for s in slot_lists:
		if typeof(s) != TYPE_ARRAY:
			continue
		for one in s:
			# str(null) РґР°С‘С‚ "<null>", РїРѕСЌС‚РѕРјСѓ РјСѓСЃРѕСЂРЅС‹Р№ СЌР»РµРјРµРЅС‚ РѕС‚СЃРµРєР°РµРј
			# СЃСЂР°РІРЅРµРЅРёРµРј, Р° РЅРµ СЃС‚СЂРѕРєРѕР№: РёРЅР°С‡Рµ РІ СЃРїРёСЃРєРµ РїРѕСЏРІРёР»СЃСЏ Р±С‹ СЃР»РѕС‚-РїСЂРёР·СЂР°Рє.
			if one == null:
				continue
			var n := str(one)
			if n != "":
				found[n] = true
	var out: Array = []
	for s in SLOT_ORDER:
		if found.has(s):
			out.append(s)
			found.erase(s)
	var rest := found.keys()
	rest.sort()
	for s in rest:
		out.append(str(s))
	return out

# Р Р°СЃРєР»Р°РґРєР° СЃРµС‚РєРё СЌРєРёРїРёСЂРѕРІРєРё, РѕС‚С„РёР»СЊС‚СЂРѕРІР°РЅРЅР°СЏ РїРѕ РєР°С‚Р°Р»РѕРіСѓ: present - СЂРµР·СѓР»СЊС‚Р°С‚
# all_slots. РЎР»РѕС‚, РєРѕС‚РѕСЂРѕРіРѕ РЅРµС‚ РІ РїСЂРµРґРјРµС‚Р°С… РёРіСЂС‹, РёР· СЂР°СЃРєР»Р°РґРєРё РІС‹РїР°РґР°РµС‚, РёРЅР°С‡Рµ
# РїРѕСЃР»Рµ РѕР±РЅРѕРІР»РµРЅРёСЏ РёРіСЂС‹ РїРѕСЏРІРёР»Р°СЃСЊ Р±С‹ РїСѓСЃС‚Р°СЏ РЅРµРёРЅС‚РµСЂР°РєС‚РёРІРЅР°СЏ РєР»РµС‚РєР°. РџРѕР·РёС†РёРё
# РѕСЃС‚Р°РІС€РёС…СЃСЏ РЅРµ СЃРґРІРёРіР°СЋС‚СЃСЏ: РєР»РµС‚РєР° РїСЂРѕРїР°РІС€РµРіРѕ СЃР»РѕС‚Р° РїСЂРѕСЃС‚Рѕ РѕСЃС‚Р°С‘С‚СЃСЏ С„РѕРЅРѕРј.
static func equip_layout(present: Array) -> Dictionary:
	var cells: Array = []
	for row in EQUIP_GRID:
		if present.has(str(row[0])):
			cells.append(row.duplicate())
	return {
		"cols": EQUIP_COLS,
		"rows": EQUIP_ROWS,
		"cells": cells,
	}

# РџРѕРґС…РѕРґРёС‚ Р»Рё РїСЂРµРґРјРµС‚ РїРѕРґ РІС‹Р±СЂР°РЅРЅС‹Р№ СЃР»РѕС‚-С†РµР»СЊ. РџСѓСЃС‚Р°СЏ С†РµР»СЊ - С„РёР»СЊС‚СЂ РІС‹РєР»СЋС‡РµРЅ,
# РїРѕРґС…РѕРґРёС‚ РІСЃС‘. РЎС‚СЂРѕРєР° РІРјРµСЃС‚Рѕ РјР°СЃСЃРёРІР° СЃР»РѕС‚Р°РјРё РЅРµ СЃС‡РёС‚Р°РµС‚СЃСЏ.
static func matches_slot(slots, slot: String) -> bool:
	if slot == "":
		return true
	if typeof(slots) != TYPE_ARRAY:
		return false
	for s in slots:
		if str(s) == slot:
			return true
	return false

# Р“РЅС‘Р·РґР° РіСЂР°РЅР°С‚. РЎР»РѕС‚ РІР°Р¶РЅРµРµ type: РІ РґР°РЅРЅС‹С… РёРіСЂС‹ Сѓ РіСЂР°РЅР°С‚С‹ type РЅРµ "grenade",
# Рё РіСЂСѓРїРїР° "Р“СЂР°РЅР°С‚С‹" РїРѕ РѕРґРЅРѕРјСѓ type РЅРµ РЅР°Р±СЂР°Р»Р°СЃСЊ Р±С‹.
const GRENADE_SLOTS := ["Grenade_1", "Grenade_2"]

# РџРѕРґРєР°С‚РµРіРѕСЂРёСЏ РїСЂРµРґРјРµС‚Р° РїРѕ РµРіРѕ resource_path. РџРѕСЂСЏРґРѕРє РїСЂР°РІРёР» РІР°Р¶РµРЅ:
# СЃРЅР°С‡Р°Р»Р° СЃР»РѕС‚, РїРѕС‚РѕРј СЃСѓС„С„РёРєСЃ РёРјРµРЅРё С„Р°Р№Р»Р°, РїРѕС‚РѕРј РїР°РїРєР° РїСЂРµРґРјРµС‚Р°. РЎР»РѕС‚ - РїРѕС‚РѕРјСѓ
# С‡С‚Рѕ Сѓ РіСЂР°РЅР°С‚С‹, С„РѕРЅР°СЂРёРєР° Рё СЃРїРёС‡РµРє РїР°РїРєР° РјРѕРґРµР»Рё РЅРёС‡РµРіРѕ РЅРµ РіРѕРІРѕСЂРёС‚. РЎСѓС„С„РёРєСЃ -
# РїРѕС‚РѕРјСѓ С‡С‚Рѕ Сѓ KAR-21 Рё Makarov РїР°РїРєР° РѕРґРЅР° РЅР° РґРІР° СЂР°Р·РЅС‹С… СЃРјС‹СЃР»Р°. РџР°РїРєР° РїСЂРµРґРјРµС‚Р° -
# С‚СЂРµС‚РёР№ СЃРµРіРјРµРЅС‚ РїСѓС‚Рё, Р° Сѓ С‚СЂС‘С…СЃРµРіРјРµРЅС‚РЅРѕРіРѕ (Armor_Plate_II.tres,
# Key_Attic.tres) РµС‘ РЅРµС‚ РІРѕРІСЃРµ, Рё СЂРѕР»СЊ РїР°РїРєРё РёРіСЂР°РµС‚ РёРјСЏ С„Р°Р№Р»Р°.
static func subcategory_of(path: String, type, slots := []) -> String:
	# Р Р°Р·Р±РѕСЂ РїСѓС‚Рё Р·РѕРІС‘С‚СЃСЏ РЅР° РєР°Р¶РґС‹Р№ РїСЂРµРґРјРµС‚ РїСЂРё РєР°Р¶РґРѕР№ РїРµСЂРµСЃР±РѕСЂРєРµ РєР°С‚Р°Р»РѕРіР°;
	# С‚Р°Р±Р»РёС†С‹ РїРѕРґРєР°С‚РµРіРѕСЂРёР№ РЅРµРёР·РјРµРЅРЅС‹, РїРѕСЌС‚РѕРјСѓ СЂРµР·СѓР»СЊС‚Р°С‚ РјРµРјРѕРёР·РёСЂСѓРµРј РїРѕ РїСѓС‚Рё.
	# РЎР»РѕС‚С‹ РІС…РѕРґСЏС‚ РІ РєР»СЋС‡: РѕРґРЅР° Рё С‚Р° Р¶Рµ РіСЂР°РЅР°С‚Р° СЃРѕ СЃР»РѕС‚РѕРј РґР°С‘С‚ "Grenades", Р° Р±РµР·
	# СЃР»РѕС‚Р° - РїСѓСЃС‚РѕР№ РєР»Р°СЃСЃ. Р Р°Р·РґРµР»РёС‚РµР»СЊ - РїРµС‡Р°С‚РЅС‹Р№ "|": РІСЃС‚СЂРѕРµРЅРЅС‹Р№ NUL-СЃРёРјРІРѕР»
	# Godot РЅРµ РїРµСЂРµР¶РёРІР°РµС‚, РїСЂРё Р·Р°РіСЂСѓР·РєРµ СЃРєСЂРёРїС‚Р° РѕРЅ РїРµС‡Р°С‚Р°РµС‚ Unicode parsing error
	# Рё РїРѕРґРјРµРЅСЏРµС‚ Р±Р°Р№С‚ РЅР° U+FFFD. РќРё РІ РїСѓС‚СЏС…, РЅРё РІ type СЃРёРјРІРѕР»Р° "|" РЅРµ Р±С‹РІР°РµС‚.
	var key := path + "|" + str(type) + "|" + str(slots)
	if _subcat_cache.has(key):
		return _subcat_cache[key]
	var sub := _subcategory_of_uncached(path, type, slots)
	_subcat_cache[key] = sub
	return sub

static func _subcategory_of_uncached(path: String, type, slots) -> String:
	if path == "" or type == null or str(type) == "":
		return ""
	var t := str(type).strip_edges().to_lower()
	# РњРµР±РµР»СЊ: РїР°РїРєР° - РІС‚РѕСЂРѕР№ СЃРµРіРјРµРЅС‚ РїСѓС‚Рё (res://Assets/<РџР°РїРєР°>/...).
	if t == "furniture":
		var fsegs: PackedStringArray = path.trim_prefix("res://").split("/")
		if fsegs.size() >= 2:
			return str(FURN_SUB_FOLDERS.get(fsegs[1], ""))
		return ""
	# РЎР»РѕС‚ РЅР°Р·С‹РІР°РµС‚ РєР»Р°СЃСЃ С‚РѕС‡РЅРµРµ РїР°РїРєРё: Сѓ С„РѕРЅР°СЂРёРєР° (Polaris), РџРќР’ (PV7), С‡Р°СЃРѕРІ,
	# РєР°СЂС‚С‹ Рё СЃРїРёС‡РµРє РїР°РїРєР° РјРѕРґРµР»Рё РЅРёС‡РµРіРѕ РЅРµ РіРѕРІРѕСЂРёС‚.
	for s in slot_list(slots):
		if GEAR_SLOTS.has(s):
			return s
		if GRENADE_SLOTS.has(s):
			return "Grenades"
	# РљР»Р°СЃСЃС‹, Сѓ РєРѕС‚РѕСЂС‹С… РІ РґР°РЅРЅС‹С… СЃРІРѕР№ С‚РёРї Рё СЃРІРѕСЏ РµРґРёРЅСЃС‚РІРµРЅРЅР°СЏ РїРѕРґРєР°С‚РµРіРѕСЂРёСЏ.
	if t == "knife":
		return "Knives"
	if t == "key":
		return "Keys"
	if t == "literature":
		return "Books"
	var leaf := path.get_file()
	if leaf.get_extension() == "":
		return ""
	var stem := leaf.get_basename()
	for suf in WEAPON_PART_SUFFIXES:
		if stem.ends_with(suf):
			return "Weapon Parts"
	# res://Items/<РїР°РїРєР°>/<С„Р°Р№Р»> - С‚СЂРё СЃРµРіРјРµРЅС‚Р° РїРѕСЃР»Рµ res://,
	# res://Items/<РїР°РїРєР°>/<СЃС‚РІРѕР»>/<С„Р°Р№Р»> - С‡РµС‚С‹СЂРµ.
	var segs := path.trim_prefix("res://").split("/")
	var folder := ""
	if segs.size() >= 4:
		folder = segs[2]
	elif segs.size() == 3:
		folder = stem
	if folder != "":
		for suf in MAG_SUFFIXES:
			if stem.ends_with(suf):
				return "Handgun & SMG Mags" if MAG_FOLDERS.has(folder) else "Rifle & Sniper Mags"
		if SUB_FOLDERS.has(folder):
			return str(SUB_FOLDERS[folder])
	# Р­Р»РµРєС‚СЂРѕРЅРёРєР° Р±РµР· СЃР»РѕС‚Р° РѕСЃС‚Р°С‘С‚СЃСЏ СЌР»РµРєС‚СЂРѕРЅРёРєРѕР№: С„РѕРЅР°СЂРёРє, РџРќР’, С‡Р°СЃС‹ Рё РєР°СЂС‚Р°
	# СѓС…РѕРґСЏС‚ РІ Gear РїРѕ СЃР»РѕС‚Сѓ РІС‹С€Рµ, РІСЃС‘ РѕСЃС‚Р°Р»СЊРЅРѕРµ - СЃСЋРґР°.
	if t == "electronics":
		return "Electronics"
	# РќРµР·РЅР°РєРѕРјР°СЏ РїР°РїРєР° С‡РёРїР° РЅРµ РґР°С‘С‚: РїРѕРґРїРёСЃСЊ РёР· РёРјРµРЅРё РїР°РїРєРё Р»РѕРјР°Р»Р° РІС‘СЂСЃС‚РєСѓ
	# (РєР°Р¶РґР°СЏ РЅРѕРІР°СЏ РїР°РїРєР° РІ Р°РїРґРµР№С‚Рµ РёРіСЂС‹ СЂРѕСЃР»Р° РѕС‚РґРµР»СЊРЅС‹Рј С‡РёРїРѕРј).
	return ""

# РџРѕРґРєР°С‚РµРіРѕСЂРёРё РІ РїРѕСЂСЏРґРєРµ С‚Р°Р±Р»РёС†С‹, РѕСЃС‚Р°Р»СЊРЅС‹Рµ - РїРѕСЃР»Рµ РЅРёС… РїРѕ Р°Р»С„Р°РІРёС‚Сѓ. РџСѓСЃС‚Р°СЏ
# СЃС‚СЂРѕРєР° РѕС‚Р±СЂР°СЃС‹РІР°РµС‚СЃСЏ: РЅРµРѕРїРѕР·РЅР°РЅРЅР°СЏ РїР°РїРєР° РЅРµ РґРѕР»Р¶РЅР° РїСЂРµРІСЂР°С‰Р°С‚СЊСЃСЏ РІ С‡РёРї.
static func order_subcategories(names) -> Array:
	var seen := {}
	for n in names:
		if str(n) != "":
			seen[str(n)] = true
	var out: Array = []
	for s in SUBCATEGORY_ORDER:
		if seen.has(s):
			out.append(s)
			seen.erase(s)
	var rest := seen.keys()
	rest.sort()
	for s in rest:
		out.append(str(s))
	return out

# Р•РґРёРЅСЃС‚РІРµРЅРЅР°СЏ РЅР°СЂРµР·РєР° РєР°С‚Р°Р»РѕРіР°: РїРѕР»РєРё С€Р°РіР° 1, СЃС‚СЂРѕРєРё С„РёР»СЊС‚СЂРѕРІ С€Р°РіР° 2 Рё
# РїРѕРґРєР°С‚РµРіРѕСЂРёРё РІРЅСѓС‚СЂРё СЃС‚СЂРѕРєРё. РќР° РІС…РѕРґ - Р·Р°РїРёСЃРё _entry, РёРјСЏ РїРѕР»СЏ СЃ РіСЂСѓРїРїРѕР№
# ("eq_group", "inv_group", "inv_sub") Рё РїРѕСЂСЏРґРѕРє РєР»СЋС‡РµР№. Р—РЅР°С‡РµРЅРёРµ РїРѕР»СЏ РјРѕР¶РµС‚
# Р±С‹С‚СЊ СЃС‚СЂРѕРєРѕР№ РёР»Рё СЃРїРёСЃРєРѕРј СЃС‚СЂРѕРє: РїСЂРµРґРјРµС‚ РІ РґРІСѓС… СЃР»РѕС‚Р°С… РїРѕРїР°РґР°РµС‚ РІ РѕР±Рµ
# РїРѕРґРєР°С‚РµРіРѕСЂРёРё, РЅРѕ РЅР° РїРѕР»РєРµ Р»РµР¶РёС‚ РѕРґРёРЅ СЂР°Р·.
#
# with_all РІСЃС‚Р°РІР»СЏРµС‚ РїРµСЂРІРѕР№ СЃС‚СЂРѕРєСѓ "Р’СЃРµ РїСЂРµРґРјРµС‚С‹" - РѕРЅР° СЃС‡РёС‚Р°РµС‚ РІРµСЃСЊ РІС…РѕРґ,
# РІРєР»СЋС‡Р°СЏ Р·Р°РїРёСЃРё Р±РµР· РіСЂСѓРїРїС‹: РёРЅР°С‡Рµ РїСЂРµРґРјРµС‚ Р±РµР· С‡РёРїР° РЅРµР»СЊР·СЏ Р±С‹Р»Рѕ Р±С‹ РЅР°Р№С‚Рё
# РјС‹С€СЊСЋ, Р° СЃСѓРјРјР° СЃС‚СЂРѕРє РЅРµ СЃРѕРІРїР°РґР°Р»Р° Р±С‹ СЃРѕ СЃС‡С‘С‚С‡РёРєРѕРј.
static func buckets(entries: Array, field: String, order: Array, with_all: bool) -> Array:
	var all: Array = []
	var groups: Dictionary = {}
	for e in entries:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		all.append(e)
		var val = e.get(field, "")
		var keys: Array = []
		if typeof(val) == TYPE_ARRAY:
			for k in val:
				keys.append(str(k))
		elif val != null:
			keys.append(str(val))
		for k in keys:
			if k == "":
				continue
			if not groups.has(k):
				groups[k] = []
			(groups[k] as Array).append(e)
	var out: Array = []
	if with_all:
		out.append({"key": "", "items": all, "count": all.size()})
	for k in order:
		var key := str(k)
		if not groups.has(key):
			continue
		out.append({"key": key, "items": groups[key], "count": (groups[key] as Array).size()})
		groups.erase(key)
	# РќРµР·РЅР°РєРѕРјС‹Р№ РєР»СЋС‡ РЅРµ С‚РµСЂСЏРµС‚СЃСЏ: СѓС…РѕРґРёС‚ РІ РєРѕРЅРµС† РїРѕ Р°Р»С„Р°РІРёС‚Сѓ.
	var rest := groups.keys()
	rest.sort()
	for k in rest:
		out.append({"key": str(k), "items": groups[k], "count": (groups[k] as Array).size()})
	return out

static func matches_search(item_name: String, query: String) -> bool:
	var q := query.strip_edges().to_lower()
	if q == "":
		return true
	return str(item_name).to_lower().find(q) >= 0

# Р•СЃС‚СЊ Р»Рё С‡С‚Рѕ РїРѕРєР°Р·Р°С‚СЊ РІ РїР°РЅРµР»Рё РѕР±РІРµСЃРѕРІ: РЅРµРїСѓСЃС‚РѕР№ compatible. РўСѓРјР±Р»РµСЂ Р·Р°РїРѕР»РЅРµРЅРёСЏ
# РѕР±РѕР№РјС‹ РѕР±СЂР°Р±Р°С‚С‹РІР°РµС‚СЃСЏ РѕС‚РґРµР»СЊРЅРѕ (_is_magazine), РїРѕСЌС‚РѕРјСѓ maxAmount Р·РґРµСЃСЊ РЅРµ
# СѓС‡Р°СЃС‚РІСѓРµС‚ (Сѓ РїР°С‚СЂРѕРЅРѕРІ РѕРЅ СЂР°РІРµРЅ РІРјРµСЃС‚РёРјРѕСЃС‚Рё СЃС‚Р°РєР°). Р•РґРёРЅР°СЏ РїСЂРѕРІРµСЂРєР° РґР»СЏ РєР»РµС‚РєРё,
# СЃС‚СЂРѕРєРё СЃР»РѕС‚Р°, С‡РёРїР° Рё СЃР°РјРѕР№ РїР°РЅРµР»Рё - РёРЅР°С‡Рµ РјРµС‚РєР° Рё СЃРѕРґРµСЂР¶РёРјРѕРµ РїР°РЅРµР»Рё СЂР°Р·РѕР№РґСѓС‚СЃСЏ.
static func att_panel_needed(info) -> bool:
	if typeof(info) != TYPE_DICTIONARY:
		return false
	var compat = info.get("compatible")
	return compat is Array and compat.size() > 0

# РћР±РІРµСЃС‹, СЃРіСЂСѓРїРїРёСЂРѕРІР°РЅРЅС‹Рµ РїРѕ РёС… СЃРѕР±СЃС‚РІРµРЅРЅРѕРјСѓ subtype: РѕРїС‚РёРєСѓ РЅРµР»СЊР·СЏ РЅР°РґРµС‚СЊ
# РІРјРµСЃС‚Рµ СЃ РѕРїС‚РёРєРѕР№, Р° РґСѓР»Рѕ СЃ РґСѓР»РѕРј. Р­Р»РµРјРµРЅС‚ РіСЂСѓРїРїС‹: {"grp": String, "items": Array},
# СЌР»РµРјРµРЅС‚ РѕР±РІРµСЃР°: {"path": String, "name": String, "subtype": String}.
static func group_attachments(attachments) -> Array:
	var groups: Array = []
	var index := {}
	for a in attachments:
		if typeof(a) != TYPE_DICTIONARY:
			continue
		var path := str(a.get("path", ""))
		if path == "":
			continue
		var grp := "Other"
		if a.get("subtype") != null:
			grp = str(a.get("subtype"))
		if grp == "":
			grp = "Other"
		if not index.has(grp):
			index[grp] = groups.size()
			groups.append({"grp": grp, "items": []})
		groups[index[grp]]["items"].append(
			{"path": path, "name": str(a.get("name", "?")), "subtype": grp})
	return groups

# РљР»Р°СЃСЃ РѕР±РІРµСЃР° РїРѕ РґР°РЅРЅС‹Рј РёРіСЂС‹. Vanilla Item.UpdateAttachments РґРµР»РёС‚ РѕР±РІРµСЃС‹ РЅР°
# Optic/Muzzle/Magazine, Рё С‚РѕР»СЊРєРѕ СЌС‚Рё РєР»Р°СЃСЃС‹ СѓС‡Р°СЃС‚РІСѓСЋС‚ РІ РІС‹Р±РѕСЂРµ РїРѕР·С‹ РѕСЂСѓР¶РёСЏ.
static func attachment_class(subtype) -> String:
	match str(subtype):
		"Optic":
			return "optic"
		"Muzzle":
			return "muzzle"
		"Magazine":
			return "magazine"
		_:
			return ""

# РџР°РєРµС‚С‹ РјР°СЃС€С‚Р°Р±+СЃРјРµС‰РµРЅРёРµ РѕСЂСѓР¶РёСЏ РїРѕРґ РЅР°РІРµС€Р°РЅРЅС‹Рµ РєР»Р°СЃСЃС‹ (Item.UpdateSprite).
# offset РѕС‚РґР°С‘С‚СЃСЏ РІ РЅРµРїРѕРІС‘СЂРЅСѓС‚РѕРј 64-РїСЂРѕСЃС‚СЂР°РЅСЃС‚РІРµ: РѕРґРёРЅРѕС‡РЅС‹Рµ СЃРјРµС‰РµРЅРёСЏ РІ РґР°РЅРЅС‹С…
# СЃРєР°Р»СЏСЂ Рё РІ РІР°РЅРёР»Рё РµРґСѓС‚ РїРѕ РѕРґРЅРѕР№ РѕСЃРё, РїР°СЂРЅС‹Рµ - Vector2; Р·РЅР°Рє СѓР¶Рµ РїСЂРёРІРµРґС‘РЅ Рє
# "position += offset", РїРѕРІРѕСЂРѕС‚ РїСЂРёРјРµРЅСЏРµС‚ РІС‹Р·С‹РІР°СЋС‰РёР№. РљР»СЋС‡ - РєР»Р°СЃСЃС‹ С‡РµСЂРµР· "+".
const COMPOSITE_PACKS := {
	"magazine": {"s": "magazineScale", "o": "magazineOffset", "k": "y", "sd": 0.5},
	"optic": {"s": "opticScale", "o": "opticOffset", "k": "y", "sd": 0.5},
	"muzzle": {"s": "suppressorScale", "o": "suppressorOffset", "k": "x", "sd": 0.45},
	"magazine+optic": {"s": "magazineOpticScale", "o": "magazineOpticOffset", "k": "y", "sd": 0.5},
	"magazine+muzzle": {"s": "magazineSuppressorScale", "o": "magazineSuppressorOffset", "k": "vec", "sd": 0.45},
	"optic+muzzle": {"s": "opticSuppressorScale", "o": "opticSuppressorOffset", "k": "vec", "sd": 0.45},
	"magazine+optic+muzzle": {"s": "fullyModdedScale", "o": "fullyModdedOffset", "k": "vec", "sd": 0.45},
}

static func composite_pack(res, classes: Array) -> Dictionary:
	var present: Array = []
	for c in ["magazine", "optic", "muzzle"]:
		if classes.has(c):
			present.append(c)
	if present.is_empty():
		return {"scale": 0.5, "offset": Vector2.ZERO}
	var key := str(present[0])
	for i in range(1, present.size()):
		key += "+" + str(present[i])
	if not COMPOSITE_PACKS.has(key):
		return {"scale": 0.5, "offset": Vector2.ZERO}
	var p: Dictionary = COMPOSITE_PACKS[key]
	var sc = res.get(p["s"])
	if sc == null:
		sc = float(p["sd"])
	var o = res.get(p["o"])
	var off := Vector2.ZERO
	if p["k"] == "vec":
		if o is Vector2:
			off = Vector2(o.x, -o.y)
	elif p["k"] == "y":
		off = Vector2(0.0, -(float(o) if o != null else 0.0))
	else:
		off = Vector2(float(o) if o != null else 0.0, 0.0)
	return {"scale": float(sc), "offset": off}

# РџРѕР·Р° РєРѕРјРїРѕР·РёС‚Р° РІ РєР»РµС‚РєРµ: Р±Р°Р·РѕРІС‹Р№ Р°СЂС‚ (РїР°РЅРµР»СЊ vanilla = size*64, РїСЂРё РїРѕРІРѕСЂРѕС‚Рµ
# РѕСЃРё РјРµРЅСЏСЋС‚СЃСЏ РјРµСЃС‚Р°РјРё) РІРїРёСЃС‹РІР°РµРј РІ РєР»РµС‚РєСѓ, РјР°СЃС€С‚Р°Р± = panel->cell * pack.scale.
# РўРµРєСЃС‚СѓСЂР° С‚РµС‚СЂРёСЃР° РІРґРІРѕРµ РїР»РѕС‚РЅРµРµ РїР°РЅРµР»Рё (natural = size*128), РїРѕСЌС‚РѕРјСѓ sprite
# scale = fit * pack.scale, Р±РµР· /0.5. offset - РІ РїР°РЅРµР»СЊРЅРѕРј 64-РїСЂРѕСЃС‚СЂР°РЅСЃС‚РІРµ, РїСЂРё
# РїРѕРІРѕСЂРѕС‚Рµ СЂР°Р·РІРѕСЂР°С‡РёРІР°РµС‚СЃСЏ РЅР° С‚РѕС‚ Р¶Рµ -90В°, Р·РЅР°Рє СѓР¶Рµ РїСЂРёРІРµРґС‘РЅ Рє "position += offset".
static func composite_placement(base: Vector2, cell: Vector2, pad: float, pack: Dictionary, rotated: bool) -> Dictionary:
	var bx := base.x * 64.0
	var by := base.y * 64.0
	if rotated:
		var t := bx
		bx = by
		by = t
	var fit := minf((cell.x - pad) / bx, (cell.y - pad) / by)
	var scale := fit * float(pack["scale"])
	var off: Vector2 = pack["offset"]
	if rotated:
		off = Vector2(off.y, -off.x)
	return {"scale": scale, "position": cell * 0.5 + off * fit}
