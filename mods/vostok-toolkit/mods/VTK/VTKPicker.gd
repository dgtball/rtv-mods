extends RefCounted
## Чистые решения выбора предметов: слоты, фильтры, полосы категорий, группы
## обвесов. Ни load(), ни путей внутрь игры - поэтому файл тестируется headless,
## как VTKDraft. Всё, что знает про ресурсы, приходит снаружи готовыми данными.

# Порядок слотов в списке выбора. Это предпочтение, а не жёсткий список: слот
# из данных, которого здесь нет, не теряется, а дописывается в конец. И наоборот -
# предпочтительного слота, которого в игре нет, в списке не появляется, так что
# после обновления игры пустых строк не прибавится.
const SLOT_ORDER := ["Primary", "Secondary", "Knife", "Grenade_1", "Grenade_2",
	"Backpack", "Rig", "Helmet", "Head", "Torso", "Legs", "Belt", "Feet",
	"Hands", "Light", "Time", "Map", "NVG", "Player", "Matches"]

# Раскладка сетки экипировки (вариант E): фиксированная сетка 6×8. Запись -
# [слот, колонка, ряд, ширина, высота] в ячейках. Стволы вытянуты в рост
# (Primary 2×6, Secondary 2×4), крупная броня 2×2 (Helmet, Rig, Backpack),
# нож/гранаты и мелочь по краям. Порядок фиксирован, поэтому раскладка
# одинакова от сета к сету; UI берёт позиции отсюда, а не держит свой список.
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

# Группы шага 1 «Экипировка»: только то, что встаёт в клетку сетки, по слотам.
# Патроны, обвесы, еда, медицина, ключи, книги и мебель сюда не попадают.
const EQUIP_GROUPS := [
	["weapon", "Weapons"],
	["clothing", "Clothing"],
	["gear", "Gear"],
	["hobby", "Hobby"],
]

# Группы шага 2 «Инвентарь»: весь каталог по назначению. Порядок - это порядок
# строк в колонке фильтров.
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

# Слот -> группа шага 1. Слота, которого здесь нет (Armor у бронеплит, Player),
# на шаге 1 не существует: шаг показывает только то, что встаёт в клетку.
const EQUIP_SLOT_GROUPS := {
	"Primary": "weapon", "Secondary": "weapon", "Knife": "weapon",
	"Grenade_1": "weapon", "Grenade_2": "weapon",
	"Feet": "clothing", "Legs": "clothing", "Belt": "clothing",
	"Torso": "clothing", "Head": "clothing", "Hands": "clothing",
	"Helmet": "clothing", "Backpack": "clothing", "Rig": "clothing",
	"Light": "gear", "NVG": "gear", "Time": "gear", "Map": "gear",
	"Matches": "gear",
}

# Слот -> подпись подкатегории шага 1. Тождество, кроме гранат: два гнезда -
# один чип.
const SLOT_SUBS := {"Grenade_1": "Grenade", "Grenade_2": "Grenade"}

# Классы предметов, которые формально помечены Primary/Secondary, но оружием не
# являются. Проверяются раньше слотов.
const HOBBY_TYPES := ["fishing", "instrument"]

# Тип из данных -> группа шага 2. Синонимы живут здесь же: игра отдаёт и
# "Consumable", и "Consumables", разгрузку как "Rig", подсумок как
# "Belt Pouch", шлем как "Helmet", рюкзак как "Backpack". Незнакомый тип
# сюда не попадает и группы не получает.
const TYPE_GROUPS := {
	"weapon": "weapon", "knife": "weapon", "grenade": "weapon",
	"ammo": "ammo", "attachment": "ammo",
	"clothing": "clothing", "rig": "clothing", "belt pouch": "clothing",
	"helmet": "clothing", "backpack": "clothing", "armor": "clothing",
	"medical": "medical",
	"consumable": "food", "consumables": "food", "fish": "food",
	"fishing": "gear", "instrument": "gear", "music": "gear",
	"misc": "tools", "tool": "tools", "key": "tools",
	"literature": "tools", "lore": "tools", "electronics": "tools",
	"furniture": "furniture",
}

# Слоты, которые сами называют класс предмета: у фонарика, ПНВ, часов, карты и
# спичек папка модели (Polaris, PV7) ничего не говорит.
const GEAR_SLOTS := ["Light", "NVG", "Time", "Map", "Matches"]

static var _art_cache: Dictionary = {}
static var _subcat_cache: Dictionary = {}

# Кроп непрозрачной области иконки: AtlasTexture на оригинальном ресурсе, файлы
# игры не трогает. used_rect расширен на 3 пикселя и обрезан по границе текстуры,
# filter_clip убирает размытие по краю. Кэш по instance_id: иконки приходят из
# одного набора ресурсов и переживают перестроение UI.
#
# rotate разворачивает кроп на 90° против часовой (дуло вверх) и отдаёт
# ImageTexture: у стволов иконка вытянута вдоль горизонтали, а клетка Primary/
# Secondary вытянута по вертикали. Оригинал не мутируем - get_region копирует.
# Кэш разведён на два ключа на один instance_id (повёрнутый и нет): одна и та
# же иконка встречается и в слоте оружия, и в каталоге.
static func item_art(texture: Texture2D, rotate := false) -> Texture2D:
	if texture == null:
		return null
	var key := texture.get_instance_id()
	var ckey := key * 2 + (1 if rotate else 0)
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

# Ключи таблицы групп в её порядке: [["weapon", "Weapons"], ...] -> ["weapon", ...].
static func group_keys(groups: Array) -> Array:
	var out: Array = []
	for entry in groups:
		out.append(str(entry[0]))
	return out

# Подпись группы по ключу. Неизвестный ключ не возвращается сырым: capitalize()
# даёт "Furniture", а не "furniture".
static func group_label(groups: Array, key: String) -> String:
	for entry in groups:
		if str(entry[0]) == key:
			return str(entry[1])
	return key.capitalize()

# Набор слотов предмета без мусора: null и строка вместо массива - пустой набор.
static func _slot_list(slots) -> Array:
	if typeof(slots) != TYPE_ARRAY:
		return []
	var out: Array = []
	for s in slots:
		if s != null and str(s) != "":
			out.append(str(s))
	return out

# Группа шага 1 по слоту. Хобби проверяется раньше слотов: удилище и гитара
# формально помечены Primary/Secondary, но оружием не являются.
static func equip_group_of(type, slots) -> String:
	if type != null and HOBBY_TYPES.has(str(type).strip_edges().to_lower()):
		return "hobby"
	for s in _slot_list(slots):
		if EQUIP_SLOT_GROUPS.has(s):
			return str(EQUIP_SLOT_GROUPS[s])
	return ""

# Подкатегории шага 1 - это подписи его слотов. У Hobby их нет: удилище и
# гитара стоят в группе по одному-два, чип внутри неё ничего не добавляет.
static func equip_subs_of(type, slots) -> Array:
	if equip_group_of(type, slots) == "hobby":
		return []
	var out: Array = []
	for s in _slot_list(slots):
		if not EQUIP_SLOT_GROUPS.has(s):
			continue
		var sub := str(SLOT_SUBS.get(s, s))
		if not out.has(sub):
			out.append(sub)
	return out

# Группа шага 2. Слот важнее type: он и есть место, куда предмет встаёт. Так
# электроника со слотом Light/Time/Map/Matches уходит в Gear, а граната - в
# Weapons. Остальное решает type через TYPE_GROUPS.
static func inventory_group_of(type, slots) -> String:
	for s in _slot_list(slots):
		if GRENADE_SLOTS.has(s):
			return "weapon"
		if GEAR_SLOTS.has(s):
			return "gear"
	var t := "" if type == null else str(type).strip_edges().to_lower()
	return str(TYPE_GROUPS.get(t, ""))

# Порядок подкатегорий - один на оба шага: впереди подписи слотов шага 1 в
# порядке SLOT_ORDER, затем классы предметов шага 2 (как заголовки "-- X --" в
# JCMDatabase.gd), в конце группы мебели из FURN_SUB_FOLDERS: у мебели подпись
# считается по папке ассета, а не по SUB_FOLDERS.
const SUBCATEGORY_ORDER := [
	# Слоты шага 1. Гранаты схлопнуты в один чип, Player на шаге 1 не бывает.
	"Primary", "Secondary", "Knife", "Grenade", "Backpack", "Rig", "Helmet",
	"Head", "Torso", "Legs", "Belt", "Feet", "Hands", "Light", "Time", "Map",
	"NVG", "Matches",
	# Классы шага 2.
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

# Имя папки -> подкатегория. Ключ - третий сегмент пути
# ("res://Items/Weapons/AKM/AKM.tres" -> "AKM"), потому что второй сегмент
# повторяется: "Weapons" в JCM встречается семь раз. Пути в игру здесь не
# хранятся - только имена папок, поэтому апдейт игры таблицу не ломает.
const SUB_FOLDERS := {
	# Оружие
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
	# Боеприпасы
	"Ammo_45ACP": "Pistol & SMG Calibers", "Ammo_46x30": "Pistol & SMG Calibers",
	"Ammo_9x18": "Pistol & SMG Calibers", "Ammo_9x19": "Pistol & SMG Calibers",
	"Ammo_9x39": "Pistol & SMG Calibers",
	"Ammo_223": "Rifle Calibers", "Ammo_308": "Rifle Calibers",
	"Ammo_545x39": "Rifle Calibers", "Ammo_762x39": "Rifle Calibers",
	"Ammo_762x54R": "Rifle Calibers", "Ammo_12x70": "Shotgun Shells",
	# Медицина
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
	# Снаряжение
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
	# Обвесы. Три подкатегории по данным игры: subtype Optic даёт Scopes,
	# Laser - Lasers, Muzzle - глушители.
	"ACOG": "Scopes", "EXPS": "Scopes", "HMR": "Scopes", "Kobra": "Scopes",
	"Leopard": "Scopes", "MRO": "Scopes", "Micro": "Scopes",
	"POSP": "Scopes", "PRO": "Scopes", "PU": "Scopes", "RMR": "Scopes",
	"SRO": "Scopes", "Vudu": "Scopes",
	"OZ5": "Lasers", "ANPEQ": "Lasers",
	"Hybrid": "Suppressors", "Monster": "Suppressors", "Navy": "Suppressors",
	"PBS": "Suppressors", "PTN": "Suppressors", "Rider": "Suppressors",
	"Salvo": "Suppressors", "Thor": "Suppressors", "SOCOM": "Suppressors",
	# Еда
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
	# Пустая тара: не расходник, а мусор.
	"Can_Empty": "Garbage", "Soda_Empty": "Garbage",
	# Разное. Ключи, книги, ножи, электроника и гранаты сюда не попадают: их
	# класс называется типом или слотом, а не папкой модели.
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
	# Свернутые одиночные чипы: под каждым из этих предметов была своя папка,
	# но группа из одного предмета не нужна - уводим в ближайшую существующую.
	"Hand_Warmer": "Utility",
	"Suitcase_Driver": "Lore",
	"Air_Freshener": "Utilities & Tools",
	"Glue": "Utilities & Tools",
	"Leather": "Utilities & Tools",
	"Museum_Plate": "Utilities & Tools",
	"Radiator_Engine": "Utilities & Tools",
	"Screws": "Utilities & Tools",
	# Бронеплиты: папки нет, путь трёхсегментный, ключ - имя файла.
	"Armor_Plate_II": "Armor Plates", "Armor_Plate_IIIA": "Armor Plates",
	"Armor_Plate_III": "Armor Plates", "Armor_Plate_III+": "Armor Plates",
	"Armor_Plate_IV": "Armor Plates",
	"Backpack_Bag": "Backpacks", "Potato_Box": "Canned Goods",
}

# Подкатегории мебели. Путь мебели: res://Assets/<Папка>/..._F.tres, поэтому
# ключ - второй сегмент пути, а не предпоследний, как в SUB_FOLDERS. Папка,
# которой нет в таблице, остаётся без чипа.
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

# Папки, чей магазин относится к пистолетам и ПП. Остальные стволы дают
# Rifle & Sniper Mags. Список нужен потому, что папка у магазина та же, что
# у ствола: у Makarov она одна на Pistols и на Handgun & SMG Mags.
const MAG_FOLDERS := ["Makarov", "Colt_1911", "Glock_17", "P320", "HP-DA",
	"MP5", "MP5SD", "MP7", "Jatimatic", "KP-31", "MP5K"]

# Суффикс имени файла, по которым предмет опознаётся как магазин или часть
# ствола, раньше разбора папки. Без этого KAR-21_Barrel попал бы в
# Assault Rifles, а Makarov_Magazine - в Pistols.
const MAG_SUFFIXES := ["_Magazine", "_Mag", "_Drum"]
const WEAPON_PART_SUFFIXES := ["_Barrel", "_Muzzle", "_Grip"]


# Все слоты, встречающиеся у предметов, в предпочтительном порядке.
# На вход - список списков слотов, как их отдаёт item.slots.
static func all_slots(slot_lists) -> Array:
	var found := {}
	for s in slot_lists:
		if typeof(s) != TYPE_ARRAY:
			continue
		for one in s:
			# str(null) даёт "<null>", поэтому мусорный элемент отсекаем
			# сравнением, а не строкой: иначе в списке появился бы слот-призрак.
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

# Раскладка сетки экипировки, отфильтрованная по каталогу: present - результат
# all_slots. Слот, которого нет в предметах игры, из раскладки выпадает, иначе
# после обновления игры появилась бы пустая неинтерактивная клетка. Позиции
# оставшихся не сдвигаются: клетка пропавшего слота просто остаётся фоном.
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

# Подходит ли предмет под выбранный слот-цель. Пустая цель - фильтр выключен,
# подходит всё. Строка вместо массива слотами не считается.
static func matches_slot(slots, slot: String) -> bool:
	if slot == "":
		return true
	if typeof(slots) != TYPE_ARRAY:
		return false
	for s in slots:
		if str(s) == slot:
			return true
	return false

# Гнёзда гранат. Слот важнее type: в данных игры у гранаты type не "grenade",
# и группа "Гранаты" по одному type не набралась бы.
const GRENADE_SLOTS := ["Grenade_1", "Grenade_2"]

# Подкатегория предмета по его resource_path. Порядок правил важен:
# сначала слот, потом суффикс имени файла, потом папка предмета. Слот - потому
# что у гранаты, фонарика и спичек папка модели ничего не говорит. Суффикс -
# потому что у KAR-21 и Makarov папка одна на два разных смысла. Папка предмета -
# третий сегмент пути, а у трёхсегментного (Armor_Plate_II.tres,
# Key_Attic.tres) её нет вовсе, и роль папки играет имя файла.
static func subcategory_of(path: String, type, slots := []) -> String:
	# Разбор пути зовётся на каждый предмет при каждой пересборке каталога;
	# таблицы подкатегорий неизменны, поэтому результат мемоизируем по пути.
	# Слоты входят в ключ: одна и та же граната со слотом даёт "Grenades", а без
	# слота - пустой класс. Разделитель - печатный "|": встроенный NUL-символ
	# Godot не переживает, при загрузке скрипта он печатает Unicode parsing error
	# и подменяет байт на U+FFFD. Ни в путях, ни в type символа "|" не бывает.
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
	# Мебель: папка - второй сегмент пути (res://Assets/<Папка>/...).
	if t == "furniture":
		var fsegs: PackedStringArray = path.trim_prefix("res://").split("/")
		if fsegs.size() >= 2:
			return str(FURN_SUB_FOLDERS.get(fsegs[1], ""))
		return ""
	# Слот называет класс точнее папки: у фонарика (Polaris), ПНВ (PV7), часов,
	# карты и спичек папка модели ничего не говорит.
	for s in _slot_list(slots):
		if GEAR_SLOTS.has(s):
			return s
		if GRENADE_SLOTS.has(s):
			return "Grenades"
	# Классы, у которых в данных свой тип и своя единственная подкатегория.
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
	# res://Items/<папка>/<файл> - три сегмента после res://,
	# res://Items/<папка>/<ствол>/<файл> - четыре.
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
	# Электроника без слота остаётся электроникой: фонарик, ПНВ, часы и карта
	# уходят в Gear по слоту выше, всё остальное - сюда.
	if t == "electronics":
		return "Electronics"
	# Незнакомая папка чипа не даёт: подпись из имени папки ломала вёрстку
	# (каждая новая папка в апдейте игры росла отдельным чипом).
	return ""

# Подкатегории в порядке таблицы, остальные - после них по алфавиту. Пустая
# строка отбрасывается: неопознанная папка не должна превращаться в чип.
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

# Единственная нарезка каталога: полки шага 1, строки фильтров шага 2 и
# подкатегории внутри строки. На вход - записи _entry, имя поля с группой
# ("eq_group", "inv_group", "inv_sub") и порядок ключей. Значение поля может
# быть строкой или списком строк: предмет в двух слотах попадает в обе
# подкатегории, но на полке лежит один раз.
#
# with_all вставляет первой строку "Все предметы" - она считает весь вход,
# включая записи без группы: иначе предмет без чипа нельзя было бы найти
# мышью, а сумма строк не совпадала бы со счётчиком.
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
	# Незнакомый ключ не теряется: уходит в конец по алфавиту.
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

# Есть ли что показать в панели обвесов: непустой compatible. Тумблер заполнения
# обоймы обрабатывается отдельно (_is_magazine), поэтому maxAmount здесь не
# участвует (у патронов он равен вместимости стака). Единая проверка для клетки,
# строки слота, чипа и самой панели - иначе метка и содержимое панели разойдутся.
static func att_panel_needed(info) -> bool:
	if typeof(info) != TYPE_DICTIONARY:
		return false
	var compat = info.get("compatible")
	return compat is Array and compat.size() > 0

# Обвесы, сгруппированные по их собственному subtype: оптику нельзя надеть
# вместе с оптикой, а дуло с дулом. Элемент группы: {"grp": String, "items": Array},
# элемент обвеса: {"path": String, "name": String, "subtype": String}.
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

# Класс обвеса по данным игры. Vanilla Item.UpdateAttachments делит обвесы на
# Optic/Muzzle/Magazine, и только эти классы участвуют в выборе позы оружия.
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

# Пакеты масштаб+смещение оружия под навешанные классы (Item.UpdateSprite).
# offset отдаётся в неповёрнутом 64-пространстве: одиночные смещения в данных
# скаляр и в ванили едут по одной оси, парные - Vector2; знак уже приведён к
# "position += offset", поворот применяет вызывающий. Ключ - классы через "+".
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

# Поза композита в клетке: базовый арт (панель vanilla = size*64, при повороте
# оси меняются местами) вписываем в клетку, масштаб = panel->cell * pack.scale.
# Текстура тетриса вдвое плотнее панели (natural = size*128), поэтому sprite
# scale = fit * pack.scale, без /0.5. offset - в панельном 64-пространстве, при
# повороте разворачивается на тот же -90°, знак уже приведён к "position += offset".
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
