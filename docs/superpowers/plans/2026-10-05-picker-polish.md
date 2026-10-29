# Picker: сетки, обвесы-плитки, подкатегории — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Сетки занимают всю высоту и считают колонки от ширины, обвесы открываются кликом по предмету и показываются плитками с золотой рамкой, категории получают 41 подкатегорию из `JCMDatabase.gd`, все названия переведены.

**Architecture:** `VTKPicker.gd` получает три чистые строковые функции — `subcategory_of`, `SUBCATEGORY_ORDER` и `MAG_FOLDERS` — рядом с существующими `category_of`/`facets_of`, поэтому тестируются headless без ресурсов игры. `VTKUI.gd` перестраивает три вещи: ширину сеток через `_make_grid_columns`, шапку шага 1 в «Цель» + строку фильтров, и панель обвесов из чипов в плитки на базе `_make_item_cell`.

**Tech Stack:** Godot 4.6.3, GDScript, headless-проверка через `godot --headless --check-only`, тесты как `extends SceneTree`, структурный стенд на Python.

**Design doc:** `docs/superpowers/specs/2026-10-05-picker-polish-design.md`
**Reference:** `referens/JCM_x/mods/JCM/JCMDatabase.gd` — источник таксономии

## Global Constraints

- Отступы в `.gd` — только табы. Файлы `.gd` — UTF-8 без BOM.
- `VTKUI.gd`, `VTKPicker.gd`, `VTKData.gd` — CRLF. Остальные `.gd`, `.py`, `.md` — LF.
- Локализация функцией `Loc.txt()`, не `tr()` — перекрытие даёт Parse Error.
- Ключ словаря сам является английской строкой. Строка с кавычкой пишется в одинарных кавычках.
- Новая строка в UI = новая запись в `RU` того же прохода.
- Имена предметов не переводятся — они приходят из `Database` и используются как есть.
- Жёсткие пути внутрь игры запрещены: таблица подкатегорий хранит **имена папок**, а не пути. `AGENTS.md` предупреждает, что `res://`-пути ломаются на апдейтах.
- Версия: `4.5.0` → `4.6.0`. Формат `VTKsets.json` не меняется, значит MINOR.
- Словарь функций — `Loc.txt()`. Переопределение `tr()` запрещено.
- Каждый `.gd` табулирован; смешанных пробелов нет.

---

### Task 1: `subcategory_of` и таблица подкатегорий

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd` — после `category_of` (строка 65-74)
- Modify: `.check/project/tests/test_picker.gd` — вызов из `_init` и новый тест

**Interfaces:**
- Consumes: ничего, функция чистая
- Produces:
  - `Picker.SUBCATEGORY_ORDER: Array[String]` — 41 ключ в порядке JCM
  - `Picker.SUB_FOLDERS: Dictionary` — `"папка" → "ключ подкатегории"`
  - `Picker.MAG_FOLDERS: Array[String]` — папки пистолетов и ПП
  - `Picker.subcategory_of(path: String, type) -> String` — пустой `cat` даёт `""`

- [x] **Step 1: Написать падающий тест**

В `.check/project/tests/test_picker.gd` в `_init` после строки `t_category_of()` добавить вызов `t_subcategory_of()`, а в конец файла дописать:

```gdscript
func t_subcategory_of() -> void:
	# Папка ствола из третьего сегмента.
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM.tres", "Weapon") == "Assault Rifles",
		"AKM -> Assault Rifles")
	ck(P.subcategory_of("res://Items/Weapons/SVD/SVD.tres", "Weapon") == "Sniper Rifles",
		"SVD -> Sniper Rifles")
	ck(P.subcategory_of("res://Items/Weapons/Remington_870/Remington_870.tres", "Weapon") == "Shotguns",
		"Remington_870 -> Shotguns")
	ck(P.subcategory_of("res://Items/Weapons/Colt_1911/Colt_1911.tres", "Weapon") == "Pistols",
		"Colt_1911 -> Pistols")
	ck(P.subcategory_of("res://Items/Weapons/MP5/MP5.tres", "Weapon") == "SMGs",
		"MP5 -> SMGs")
	# Магазин опознаётся суффиксом, а не папкой: у Makarov папка одна и та же.
	ck(P.subcategory_of("res://Items/Weapons/Makarov/Makarov_Magazine.tres", "Attachment") == "Handgun & SMG Mags",
		"Makarov_Magazine -> Handgun & SMG Mags")
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM_Magazine.tres", "Attachment") == "Rifle & Sniper Mags",
		"AKM_Magazine -> Rifle & Sniper Mags")
	ck(P.subcategory_of("res://Items/Weapons/KP-31/KP-31_Drum.tres", "Attachment") == "Handgun & SMG Mags",
		"KP-31_Drum -> Handgun & SMG Mags")
	# Ствольная коробка KAR-21 не должна попасть в Assault Rifles.
	ck(P.subcategory_of("res://Items/Weapons/KAR-21/KAR-21_Barrel.tres", "Attachment") == "Weapon Parts",
		"KAR-21_Barrel -> Weapon Parts")
	# Трёхсегментные пути: папки нет, читаем второй сегмент.
	ck(P.subcategory_of("res://Items/Armor/Armor_Plate_II.tres", "Armor") == "Armor Plates",
		"Armor_Plate_II -> Armor Plates")
	ck(P.subcategory_of("res://Items/Keys/Key_Attic.tres", "Tool") == "Shelter Keys",
		"Key_Attic -> Shelter Keys")
	ck(P.subcategory_of("res://Items/Keys/Key_Cellar.tres", "Tool") == "Lootroom Keys",
		"Key_Cellar -> Lootroom Keys")
	ck(P.subcategory_of("res://Items/Books/Book_Children.tres", "Tool") == "Books",
		"Book_Children -> Books")
	# Прочие папки верхних уровней.
	ck(P.subcategory_of("res://Items/Rigs/LVPC/LVPC_Green.tres", "Armor") == "Rigs & Vests",
		"LVPC -> Rigs & Vests")
	ck(P.subcategory_of("res://Items/Rigs/Vest_Fishing/Vest_Fishing.tres", "Armor") == "Rigs & Vests",
		"Vest_Fishing -> Rigs & Vests")
	ck(P.subcategory_of("res://Items/Attachments/ACOG/ACOG.tres", "Attachment") == "Optics",
		"ACOG -> Optics")
	ck(P.subcategory_of("res://Items/Medical/IFAK/IFAK.tres", "Medical") == "First Aid",
		"IFAK -> First Aid")
	ck(P.subcategory_of("res://Items/Consumables/Beer/Beer.tres", "Consumable") == "Vices",
		"Beer -> Vices")
	ck(P.subcategory_of("res://Items/Clothing/Jeans_Black/Jeans_Black.tres", "Clothing") == "Pants",
		"Jeans_Black -> Pants")
	# Граната из слота, а не из папки.
	ck(P.subcategory_of("res://Items/Grenades/F1/F1.tres", "Consumable") == "Grenades",
		"F1 -> Grenades")
	# Инструменты и рыба известны таблице, а не попадают в fallback.
	ck(P.subcategory_of("res://Items/Instruments/Guitar/Guitar.tres", "Tool") == "Music & Fishing",
		"Guitar -> Music & Fishing")
	ck(P.subcategory_of("res://Items/Fishing/Bream/Bream.tres", "Food") == "Fish",
		"Bream -> Fish")
	# Неизвестная папка не теряется: её имя становится подкатегорией.
	ck(P.subcategory_of("res://Items/Weapons/Foo_Bar/Foo_Bar.tres", "Weapon") == "Foo_Bar",
		"Foo_Bar -> имя папки")
	# То же для трёхсегментного пути, где роль папки играет имя файла.
	ck(P.subcategory_of("res://Items/Junk/Thing_01.tres", "Tool") == "Thing_01",
		"Thing_01 -> имя файла")
	# Пустой путь и пустой тип.
	ck(P.subcategory_of("", "Weapon") == "", "пустой путь -> пусто")
	ck(P.subcategory_of("res://Items/Weapons/AKM/AKM.tres", null) == "", "пустой тип -> пусто")
```

- [x] **Step 2: Прогнать тест и убедиться, что он падает**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 9 scripts`, затем `Picker tests failed: 21` — функции нет.

- [x] **Step 3: Добавить таблицу и функцию в `VTKPicker.gd`**

Вставить сразу после `const CATEGORY_ORDER` (строка 18), перед `static func all_slots`:

```gdscript
# Порядок подкатегорий - как заголовки "-- X --" в JCMDatabase.gd, минус
# FURNITURE: там res://Assets, это не предметы для сета.
const SUBCATEGORY_ORDER := ["Assault Rifles", "Sniper Rifles", "Shotguns",
	"Pistols", "SMGs",
	"Handgun & SMG Mags", "Rifle & Sniper Mags",
	"Pistol & SMG Calibers", "Rifle Calibers", "Shotgun Shells",
	"First Aid", "Medication", "Hygiene & Utility",
	"Helmets & Night Vision", "Armor Plates", "Rigs & Vests", "Backpacks",
	"Belts", "Knives", "Grenades", "Hats", "Torso", "Pants", "Boots & Hands",
	"Weapon Parts", "Optics", "Lasers & Suppressors",
	"Hydration", "Canned Goods", "Snacks & Ingredients", "Cooked Meals",
	"Vices", "Fish",
	"Shelter Keys", "Lootroom Keys",
	"Electronics", "Utilities & Tools", "Survival", "Books",
	"Music & Fishing", "Lore"]

# Имя папки -> подкатегория. Ключ третий сегмент пути
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
	"Melatonin": "Medication", "Painkillers": "Medication",
	"Antiseptic": "Hygiene & Utility", "Balm": "Hygiene & Utility",
	"Deodorant": "Hygiene & Utility", "Gum": "Hygiene & Utility",
	"Lotion": "Hygiene & Utility", "Saline": "Hygiene & Utility",
	"Tissues": "Hygiene & Utility", "Wipes": "Hygiene & Utility",
	# Снаряжение
	"Helmet_Police": "Helmets & Night Vision", "PV7": "Helmets & Night Vision",
	"SSh-39": "Helmets & Night Vision",
	"LVPC": "Rigs & Vests", "K19": "Rigs & Vests",
	"Vest_Fishing": "Rigs & Vests",
	"Backpack_Jaeger": "Backpacks", "Backpack_Kantamus": "Backpacks",
	"Backpack_Nomad": "Backpacks", "Backpack_Patrol": "Backpacks",
	"Duffel_Retro": "Backpacks",
	"Kukkaro": "Belts",
	"Jaeger_140": "Knives", "Skrama_200": "Knives", "Skrama_240": "Knives",
	"F1": "Grenades", "M43": "Grenades", "M50": "Grenades", "RGD-5": "Grenades",
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
	# Обвесы
	"ACOG": "Optics", "EXPS": "Optics", "HMR": "Optics", "Kobra": "Optics",
	"Leopard": "Optics", "MRO": "Optics", "Micro": "Optics", "OZ5": "Optics",
	"POSP": "Optics", "PRO": "Optics", "PU": "Optics", "RMR": "Optics",
	"SRO": "Optics", "Vudu": "Optics",
	"ANPEQ": "Lasers & Suppressors", "Hybrid": "Lasers & Suppressors",
	"Monster": "Lasers & Suppressors", "Navy": "Lasers & Suppressors",
	"PBS": "Lasers & Suppressors", "PTN": "Lasers & Suppressors",
	"Rider": "Lasers & Suppressors", "Salvo": "Lasers & Suppressors",
	"Thor": "Lasers & Suppressors", "SOCOM": "Lasers & Suppressors",
	# Еда
	"Energy_Drink": "Hydration", "Juice_Orange": "Hydration",
	"Juice_Pear": "Hydration", "Juice_Raspberry": "Hydration",
	"Soda_Lemon": "Hydration", "Water_Bottle": "Hydration",
	"Canned_Meat": "Canned Goods", "Canned_Meatballs": "Canned Goods",
	"Canned_Pea_Soup": "Canned Goods", "Canned_Peach": "Canned Goods",
	"Canned_Pear": "Canned Goods", "Canned_Peas": "Canned Goods",
	"Canned_Pineapple": "Canned Goods", "Canned_Tomatoes": "Canned Goods",
	"Canned_Tuna": "Canned Goods", "Cat_Food": "Canned Goods",
	"Chocolate_War": "Snacks & Ingredients", "Coffee": "Snacks & Ingredients",
	"Crackers": "Snacks & Ingredients", "Energy_Powder": "Snacks & Ingredients",
	"Field_Ration": "Snacks & Ingredients", "Jam": "Snacks & Ingredients",
	"Mustard": "Snacks & Ingredients", "Peanuts": "Snacks & Ingredients",
	"Potato": "Snacks & Ingredients", "Salty_Liquorice": "Snacks & Ingredients",
	"Sugar": "Snacks & Ingredients", "Yeast": "Snacks & Ingredients",
	"Coffee_Brewed": "Cooked Meals", "Cooked_Fish_Soup": "Cooked Meals",
	"Cooked_Meatballs": "Cooked Meals", "Cooked_Pea_Soup": "Cooked Meals",
	"Cooked_Tomato_Soup": "Cooked Meals", "Kompot": "Cooked Meals",
	"Beer": "Vices", "Cigarettes": "Vices", "Cigars": "Vices", "Kilju": "Vices",
	"Snus": "Vices",
	"Bream": "Fish", "Perch": "Fish", "Pike": "Fish", "Roach": "Fish",
	# Ключи
	"Key_Attic": "Shelter Keys", "Key_Bunker": "Shelter Keys",
	"Key_Classroom": "Shelter Keys", "Key_Garage": "Shelter Keys",
	"Key_Cellar": "Lootroom Keys", "Key_Gymnasium": "Lootroom Keys",
	"Key_Tunnel": "Lootroom Keys",
	# Разное
	"Alarm_Clock": "Electronics", "Alcometer": "Electronics",
	"Batteries": "Electronics", "Battery": "Electronics",
	"Battery_Cables": "Electronics", "Casette_Electrofolk": "Electronics",
	"Casette_Nomad": "Electronics", "Casette_OST": "Electronics",
	"Casette_Player": "Electronics", "Casette_Radio": "Electronics",
	"Casette_Symphony": "Electronics", "Coffeemaster": "Electronics",
	"Cooking_Station": "Electronics", "Hotplate": "Electronics",
	"Inverter": "Electronics", "Narva": "Electronics", "Polaris": "Electronics",
	"VIRVE": "Electronics", "Watch_Tactical": "Electronics",
	"Aluminum_Foil": "Utilities & Tools", "Can_Empty": "Utilities & Tools",
	"Duct_Tape": "Utilities & Tools", "Happy_Stove": "Utilities & Tools",
	"Jerry_Can": "Utilities & Tools", "Lumber": "Utilities & Tools",
	"Matches": "Utilities & Tools", "Mess_Kit": "Utilities & Tools",
	"Nails": "Utilities & Tools", "Oil_Filter": "Utilities & Tools",
	"Soda_Empty": "Utilities & Tools", "Sticks": "Utilities & Tools",
	"Toolbox": "Utilities & Tools", "Water_Lock": "Utilities & Tools",
	"Weapon_Repair_Kit": "Utilities & Tools",
	"Blanket": "Survival", "Board_Game": "Survival", "Bucket": "Survival",
	"Coffee_Filter": "Survival", "Map": "Survival", "Map_Tactical": "Survival",
	"Mattress": "Survival", "Pillow": "Survival", "Rags": "Survival",
	"Sleeping_Bag": "Survival", "Toilet_Paper": "Survival",
	"Book_Children": "Books", "Book_Cooking": "Books",
	"Book_Fishing": "Books", "Book_Religion": "Books",
	"Fishing_Rod": "Music & Fishing", "Guitar": "Music & Fishing",
	"Harmonica": "Music & Fishing", "Tackle_Box": "Music & Fishing",
	"Cat": "Lore", "Oil_Sample": "Lore", "Patient_Report": "Lore",
	# Бронеплиты: папки нет, путь трёхсегментный, ключ - имя файла.
	"Armor_Plate_II": "Armor Plates", "Armor_Plate_IIIA": "Armor Plates",
	"Armor_Plate_III": "Armor Plates", "Armor_Plate_III+": "Armor Plates",
	"Armor_Plate_IV": "Armor Plates",
	"Backpack_Bag": "Backpacks", "Potato_Box": "Canned Goods",
}

# Папки, чей магазин относится к пистолетам и ПП. Остальные стволы дают
# Rifle & Sniper Mags. Список нужен потому, что папка у магазина та же, что
# у ствола: у Makarov она одна на Pistols и на Handgun & SMG Mags.
const MAG_FOLDERS := ["Makarov", "Colt_1911", "Glock_17", "P320", "HP-DA",
	"MP5", "MP5SD", "MP7", "Jatimatic", "KP-31", "MP5K"]

# Суффиксы файла, по которым предмет опознаётся как магазин или часть
# ствола, раньше разбора папки. Без этого KAR-21_Barrel попал бы в
# Assault Rifles, а Makarov_Magazine - в Pistols.
const MAG_SUFFIXES := ["_Magazine", "_Mag", "_Drum"]
const WEAPON_PART_SUFFIXES := ["_Barrel", "_Muzzle", "_Grip"]
```

- [x] **Step 4: Добавить саму функцию после `category_of`**

Вставить сразу после `category_of` (конец строки 74):

```gdscript
# Подкатегория предмета по его resource_path. Порядок правил важен:
# сначала суффикс имени файла, потом длина пути, потом папка.
# Суффикс - потому что у KAR-21 и Makarov папка одна на два разных смысла.
# Длина пути - потому что у Armor_Plate_II.tres папки нет вовсе, а у
# Keys/Sub/Key_Tunnel.tres она есть, и по имени это не отличить.
static func subcategory_of(path: String, type) -> String:
	if path == "" or type == null or str(type) == "":
		return ""
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
	if folder == "":
		return ""
	for suf in MAG_SUFFIXES:
		if stem.ends_with(suf):
			return "Handgun & SMG Mags" if MAG_FOLDERS.has(folder) else "Rifle & Sniper Mags"
	if SUB_FOLDERS.has(folder):
		return str(SUB_FOLDERS[folder])
	return folder
```

У трёхсегментного пути ключом служит **имя файла без расширения**, а не второй
сегмент: `res://Items/Keys/Key_Attic.tres` — второй сегмент это `Keys`, общий
для всех ключей и в таблице отсутствующий, а в таблице лежит именно `Key_Attic`.
Второй сегмент у трёхсегментного пути всегда означает верхний раздел
(`Armor`, `Keys`, `Books`) и ничего не различает внутри него.

Проверка суффикса магазина идёт **после** разбора папки, а не до него: папка
нужна как список `MAG_FOLDERS`, который решает, «пистолетный» магазин или
«винтовочный». Если проверять суффикс раньше, папки ещё нет в руках.

Таблица `SUB_FOLDERS` не должна содержать суффиксов магазинов и частей ствола:
иначе `KAR-21_Magazine.tres` разрешился бы в «Штурмовые винтовки» по папке
`KAR-21`, если бы порядок правил был другим.

- [x] **Step 5: Прогнать тесты**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1`
Expected: `Parse check passed: 9 scripts`, `Picker tests passed`, `Tests passed: 2 file(s)`.

- [x] **Step 6: Откатная точка**

Snapshot в `%TEMP%\opencode\vtk-snap-<метка>`: `loadouts/mods/VTK` и `.check/project/tests`.

---

### Task 2: Локализация подкатегорий

**Files:**
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — словарь `RU`
- Modify: `loadouts/mods/VTK/VTKPicker.gd` — комментарий над `CATEGORY_ORDER`

**Interfaces:**
- Consumes: `SUBCATEGORY_ORDER` из Task 1
- Produces: 41 ключ в `RU`

- [x] **Step 1: Выписать ключи из таблицы**

Run:
```powershell
Select-String -Path "loadouts\mods\VTK\VTKPicker.gd" -Pattern '": "' -AllMatches |
  Select-String -Pattern "Assault|Sniper|Shotgun|Pistol|SMG|Caliber|First Aid|Medication|Hygiene|Helmet|Armor|Rig|Backpack|Belt|Knives|Grenade|Hat|Torso|Pants|Boots|Weapon Parts|Optics|Lasers|Hydration|Canned|Snacks|Cooked|Vices|Fish|Shelter|Lootroom|Electronics|Utilities|Survival|Books|Music|Lore" |
  ForEach-Object { $_.Matches.Value }
```

Expected: 41 уникальных ключа. Список используется как источник истины для перевода — не из головы.

- [x] **Step 2: Дописать `RU` в `VTKLoc.gd`**

Добавить в словарь `RU` (LF-файл, отступ таб):

```
	'Assault Rifles': 'Штурмовые винтовки',
	'Sniper Rifles': 'Снайперские винтовки',
	'Shotguns': 'Дробовики',
	'Pistols': 'Пистолеты',
	'SMGs': 'Пистолеты-пулемёты',
	'Handgun & SMG Mags': 'Магазины пистолетов и ПП',
	'Rifle & Sniper Mags': 'Магазины винтовок и снайперок',
	'Pistol & SMG Calibers': 'Калибры пистолетов и ПП',
	'Rifle Calibers': 'Калибры винтовок',
	'Shotgun Shells': 'Дробовые патроны',
	'First Aid': 'Первая помощь',
	'Medication': 'Лекарства',
	'Hygiene & Utility': 'Гигиена и быт',
	'Helmets & Night Vision': 'Шлемы и ночное видение',
	'Armor Plates': 'Бронеплиты',
	'Rigs & Vests': 'Ригги и бронежилеты',
	'Backpacks': 'Рюкзаки',
	'Belts': 'Пояса',
	'Knives': 'Ножи',
	'Grenades': 'Гранаты',
	'Hats': 'Головные уборы',
	'Torso': 'Торс',
	'Pants': 'Брюки',
	'Boots & Hands': 'Обувь и перчатки',
	'Weapon Parts': 'Части ствола',
	'Optics': 'Оптика',
	'Lasers & Suppressors': 'Лазеры и глушители',
	'Hydration': 'Питьё',
	'Canned Goods': 'Консервы',
	'Snacks & Ingredients': 'Перекусы и продукты',
	'Cooked Meals': 'Готовые блюда',
	'Vices': 'Пороки',
	'Fish': 'Рыба',
	'Shelter Keys': 'Ключи убежищ',
	'Lootroom Keys': 'Ключи лутариев',
	'Electronics': 'Электроника',
	'Utilities & Tools': 'Хозтовары и инструменты',
	'Survival': 'Выживание',
	'Books': 'Книги',
	'Music & Fishing': 'Музыка и рыбалка',
	'Lore': 'Лор',
```

Ключ `'Grenades'` уже есть в `RU` — дублировать нельзя, это перезапишет значение молча. Убедиться, что он присутствует ровно один раз.

- [x] **Step 3: Проверить локализацию**

Run: `python .check\keycheck.py`
Expected: `RESULT: every Loc.txt() key has a RU entry`.

- [x] **Step 4: Поправить устаревший комментарий в `VTKPicker.gd`**

Комментарий над `CATEGORY_ORDER` (строки 13-15) ссылается на `_type_colors`, которого в `VTKUI.gd` больше нет. Заменить на:

```gdscript
# Порядок полок категорий. Значения - это str(item.type).to_lower(). Словарь
# имён полок живёт в VTKUI.gd как CATEGORY_LABELS: ключи там в игровом
# регистре, и по строке "armor" нельзя отличить категорию от уже
# существующего ключа "Armor". Категория из данных, которой здесь нет, не
# теряется: уходит в конец по алфавиту.
```

- [x] **Step 5: Откатная точка**

Snapshot.

---

### Task 3: Сетки по ширине и высоте

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_make_grid_columns`, строки 590-597 и 635-643
- Modify: `.check/layout_check.py` — список `PRESENT`

**Interfaces:**
- Consumes: ничего
- Produces: `_make_grid_columns(width: float) -> int`

- [x] **Step 1: Добавить символ в `PRESENT` и убедиться, что стенд красный**

В `.check/layout_check.py` в `PRESENT` дописать `"_make_grid_columns",`.

Run: `python .check\layout_check.py`
Expected: `MISS  _make_grid_columns`, ненулевой код возврата.

- [x] **Step 2: Добавить функцию под `SIDE_WIDTH` (строка 527)**

```gdscript
# Сколько клеток влезает в ширину. Константа "_gear_grid.columns = 4" давала
# четыре колонки в любом окне, а HFlowContainer на шаге 1 упирался в
# собственную ширину и показывал пять клеток вместо всей области.
func _make_grid_columns(width: float) -> int:
	if width <= 0.0:
		return 1
	var cell := 80.0
	var sep := 5.0
	return maxi(1, int(floor((width + sep) / (cell + sep))))
```

- [x] **Step 3: Шаг 2 — считать колонки от ширины**

Заменить строку 639 `_gear_grid.columns = 4` на:

```gdscript
	_gear_grid.columns = _make_grid_columns(_gear_grid_scroll.size.x)
	_gear_grid_scroll.resized.connect(func():
		if _gear_grid != null:
			_gear_grid.columns = _make_grid_columns(_gear_grid_scroll.size.x)
	)
```

- [x] **Step 4: Шаг 2 — убрать ограничение высоты**

Заменить строку 636:
```gdscript
	_gear_grid_scroll.custom_minimum_size = Vector2(0, 238)
	_gear_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```
на:
```gdscript
	_gear_grid_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gear_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

- [x] **Step 5: Шаг 1 — убрать ограничение высоты и растянуть полку**

Заменить строки 590-592:
```gdscript
	var shelves_scroll := ScrollContainer.new()
	shelves_scroll.custom_minimum_size = Vector2(0, 240)
	shelves_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
```
на:
```gdscript
	var shelves_scroll := ScrollContainer.new()
	shelves_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelves_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

В `_make_shelf` (строка 1271) добавить после создания `flow`:
```gdscript
	flow.size_flags_vertical = Control.SIZE_EXPAND_FILL
```

- [x] **Step 6: Проверить разбор и раскладку**

Run:
```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
```
Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `Tests passed: 2 file(s)`.

- [x] **Step 7: Откатная точка**

Snapshot.

---

### Task 4: Шапка шага 1 — «Цель» и строка фильтров

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_target_bar`, `_refresh_target_bar` (строки 1172-1190), новые переменные фильтра
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — ключи `Filter`, `Reset`
- Modify: `.check/layout_check.py` — `GONE` и `PRESENT`

**Interfaces:**
- Consumes: `Picker.category_of`, `Picker.subcategory_of` из Task 1
- Produces:
  - переменные `_target_cat: String`, `_target_sub: String`
  - `_set_target_cat(c: String)`, `_set_target_sub(s: String)`, `_reset_target_filters()`
  - `_target_bar` становится `VBoxContainer` с двумя строками

- [x] **Step 1: Стенд должен стать красным**

В `.check/layout_check.py` в `PRESENT` дописать `"_target_cat"`,
`"_target_sub"`, `"_reset_target_filters"`.

Ключ `All items` в `GONE` **не добавляется**: он остаётся в фасетах шага 2, и
стенд начал бы ругаться на живую строку. Отсутствие пункта на шаге 1 проверяется
глазами, а не символом.

Run: `python .check\layout_check.py`
Expected: `MISS  _target_cat`, ненулевой код возврата.

- [x] **Step 2: Объявить переменные и сменить тип `_target_bar`**

Рядом с `var _target_slot: String = ""` (строка 59) добавить:
```gdscript
# Фильтры каталога шага 1: категория и её подкатегория. Для экипировки
# смотреть все предметы не нужно, поэтому отдельного пункта "Все предметы"
# здесь нет - сброс делает чип "Сброс".
var _target_cat: String = ""
var _target_sub: String = ""
```

Строка 52 объявляет `var _target_bar: HBoxContainer = null`. Панель становится
двумя строками, поэтому тип меняется на `VBoxContainer`:
```gdscript
var _target_bar: VBoxContainer = null
```

В `_build_page_equipment` (строки 572-575) заменить создание:
```gdscript
	_target_bar = VBoxContainer.new()
	_target_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_bar.add_theme_constant_override("separation", 2)
	v.add_child(_target_bar)
```

Строка 428 обнуляет `_target_bar` — тип меняется автоматически, правки не
требует.

- [x] **Step 3: Сбросить фильтры вместе с целью**

В `_set_target_slot` (строка 1203) после `_open_att_path = ""` добавить:
```gdscript
	_target_cat = ""
	_target_sub = ""
```

- [x] **Step 4: Переписать `_rebuild_target_bar`**

Функция называется `_rebuild_target_bar` (строка 1170), не `_refresh_target_bar`.
Заменить её тело целиком:

```gdscript
func _refresh_target_bar() -> void:
	if _target_bar == null:
		return
	for child in _target_bar.get_children():
		_target_bar.remove_child(child)
		child.queue_free()

	var tgt := Label.new()
	tgt.text = Loc.txt("Target: ") + (_target_slot if _target_slot != "" else "-")
	tgt.add_theme_font_size_override("font_size", 10)
	tgt.add_theme_color_override("font_color", _gold)
	_target_bar.add_child(tgt)

	var line := HFlowContainer.new()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_theme_constant_override("h_separation", 4)
	line.add_theme_constant_override("v_separation", 2)

	var lbl := Label.new()
	lbl.text = Loc.txt("Filter") + ":"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color("#5f5347"))
	line.add_child(lbl)

	var found := _target_filter_items()
	for e in found:
		var c := str(e.get("cat", ""))
		var s := str(e.get("sub", ""))
		line.add_child(_make_filter_chip(c, s == ""))

	if _target_cat != "":
		for sub in _target_subcategories(found):
			line.add_child(_make_filter_chip(sub, true, true))

	var reset := Button.new()
	reset.text = Loc.txt("Reset")
	reset.add_theme_font_size_override("font_size", 9)
	reset.tooltip_text = Loc.txt("Reset")
	var any_on := _target_cat != "" or _target_sub != ""
	reset.add_theme_stylebox_override("normal", _make_chip_style(any_on))
	reset.add_theme_color_override("font_color", _gold if any_on else Color("#5f5347"))
	reset.pressed.connect(_reset_target_filters)
	line.add_child(reset)

	_target_bar.add_child(line)
```

- [x] **Step 5: Добавить три функции-хелпера после `_rebuild_target_bar`**

```gdscript
# Чип фильтра. level = true означает подкатегорию - она не снимает старший
# уровень, а меняет только себя.
func _make_filter_chip(key: String, on: bool, level: bool = false) -> Button:
	var b := Button.new()
	var name_txt := str(CATEGORY_LABELS.get(key, key))
	b.text = ("> " if level else "") + Loc.txt(name_txt)
	b.add_theme_font_size_override("font_size", 9)
	b.tooltip_text = name_txt
	b.add_theme_stylebox_override("normal", _make_chip_style(on))
	b.add_theme_color_override("font_color", _gold if on else Color("#cccccc"))
	if level:
		b.pressed.connect(func(): _set_target_sub(key))
	else:
		b.pressed.connect(func(): _set_target_cat(key))
	return b

func _set_target_cat(c: String) -> void:
	_target_cat = "" if _target_cat == c else c
	# Смена старшего уровня сбрасывает младший: иначе после "Винтовки" ->
	# "Пистолеты" остался бы фильтр "Снайперки" из прошлой ветки.
	_target_sub = ""
	_refresh_pages()

func _set_target_sub(s: String) -> void:
	_target_sub = "" if _target_sub == s else s
	_refresh_pages()

func _reset_target_filters() -> void:
	_target_cat = ""
	_target_sub = ""
	_refresh_pages()
```

- [x] **Step 6: Считать подкатегории и фильтровать каталог**

Добавить после `_reset_target_filters`:

```gdscript
# Записи каталога, подходящие слоту-цели, с посчитанной подкатегорией.
func _target_filter_items() -> Array:
	var out: Array = []
	if _draft == null:
		return out
	for e in _items_for_target():
		var it = e.get("item")
		if it == null:
			continue
		var row := {
			"item": it,
			"name": str(it.get("name", "")),
			"cat": str(e.get("cat", "")),
			"sub": Picker.subcategory_of(str(it.resource_path), it.get("type")),
		}
		out.append(row)
	return out

# Подкатегории, встречающиеся в отфильтрованном списке. Порядок - общий
# SUBCATEGORY_ORDER, чтобы чипы не прыгали между перестроениями.
func _target_subcategories(items: Array) -> Array:
	var seen := {}
	for e in items:
		if str(e.get("cat", "")) != _target_cat:
			continue
		seen[str(e.get("sub", ""))] = true
	var out: Array = []
	for s in Picker.SUBCATEGORY_ORDER:
		if seen.has(s):
			out.append(s)
	seen.erase("")
	out.sort()
	return out
```

- [x] **Step 7: Применить фильтры к каталогу шага 1**

В `_rebuild_shelves` (строка 1237) заменить строку `var found := _items_for_target()` на:

```gdscript
	var found := _target_filter_items()
	var q := _search_text
	for i in range(found.size() - 1, -1, -1):
		if not Picker.matches_search(str(found[i].get("name", "")), q):
			found.remove_at(i)
	if _target_cat != "":
		var only: Array = []
		for e in found:
			if str(e.get("cat", "")) == _target_cat:
				only.append(e)
		found = only
	if _target_sub != "":
		var only2: Array = []
		for e in found:
			if str(e.get("sub", "")) == _target_sub:
				only2.append(e)
		found = only2
```

Заметка об имплементации: `_target_filter_items()` уже возвращает словари с
`name` и `sub`, поэтому `_rebuild_shelves` больше не зовёт `Picker.shelves_of`
напрямую. Вызов `Picker.shelves_of(found)` ниже по функции остаётся — он
группирует по `cat`, а `shelves_of` читает только `item` и `cat`.

Запрос поиска уже есть: его держит `_search_text`, который `_set_search`
(строка 1211) присваивает из поля. Никакого `_search_field` не нужно — вместо
хелпера `_search_field_text()` читать существующую переменную:

```gdscript
	var q := _search_text
```

Второе: `_entry` (строка 1220) возвращает только `item` и `cat`. Раньше это не
мешало, потому что `shelves_of` имя не читает, а поиск фильтровался внутри
`_items_for_target`. Теперь фильтр переехал в `_rebuild_shelves`, и поиску
понадобится имя — но он уже берёт его из `_target_filter_items`, так что
`_entry` править не нужно.

- [x] **Step 8: Ключи `Filter` и `Reset` в `RU`**

Дописать в `VTKLoc.gd`:
```
	'Filter': 'Фильтр',
	'Reset': 'Сброс',
```

- [x] **Step 9: Проверить всё**

Run:
```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
```
Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `Tests passed: 2 file(s)`, `RESULT: every Loc.txt() key has a RU entry`.

- [x] **Step 10: Откатная точка**

Snapshot.

---

### Task 4b: Подкатегории вторым уровнем фасетов (добавлено по просьбе)

**Files:**
- Modify: `loadouts/mods/VTK/VTKPicker.gd` — `order_subcategories()`
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_gear_sub_key`, `_gear_subfacets`, `_set_gear_sub`, `_make_facet_row`
- Modify: `.check/project/tests/test_picker.gd` — `t_order_subcategories()`

**Interfaces:**
- Consumes: `subcategory_of` из Task 1, `SUBCATEGORY_ORDER`, `_entry()` с полем `sub`
- Produces: `_gear_sub_key: String`, `Picker.order_subcategories(names) -> Array`

- [x] **Step 1: Стенд красный**

В `.check/layout_check.py` в `PRESENT` дописаны `_gear_sub_key`, `_gear_subfacets`,
`_set_gear_sub`, `Picker.order_subcategories`.
Run: `python .check\layout_check.py`. Expected: `MISS` по всем четырём.

- [x] **Step 2: Тест на порядок подкатегорий**

`order_subcategories` живёт в `VTKPicker.gd`, а не в `VTKUI.gd`: это чистая функция
без путей внутрь игры, поэтому тестируется headless вместе с остальным Picker.
Тест `t_order_subcategories()` проверяет порядок таблицы, отбрасывание пустой
строки, схлопывание дублей и сортировку неизвестных подкатегорий в конце.

- [x] **Step 3: Подкатегории в `_entry()`**

`_entry()` кладёт в запись каталога `"sub"`. Считается один раз на предмет, и
`facets_of` разносит это поле дальше без своего пересчёта.

- [x] **Step 4: Второй уровень в фасетах**

`_rebuild_gear_facets()` добавляет строки подкатегорий сразу под активной
категорией и с отступом `margin_left = 10`. На строке «Все предметы» подкатегорий
нет: там список занял бы полколонки и означал бы третье измерение фильтра.

- [x] **Step 5: Фильтр по подкатегории**

`_rebuild_gear_grid()` сужает набор фасета по `_gear_sub_key`. `_set_gear_facet()`
сбрасывает подкатегорию при смене категории, `_set_gear_sub()` переключает её
повторным кликом, `_reset_picker_state()` обнуляет её с новым черновиком.

- [x] **Step 6: Проверить всё**

Run:
```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
```
Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`,
`Tests passed: 2 file(s)`, `RESULT: every Loc.txt() key has a RU entry`.

- [x] **Step 7: Откатная точка**

Snapshot.

---

### Task 5: Обвесы-плитки и вход из клетки

**Files:**
- Modify: `loadouts/mods/VTK/VTKUI.gd` — `_make_att_toggle` (строка 1770), `_build_att_panel` (строка 1741), `_place_into` (строка 1561)
- Modify: `loadouts/mods/VTK/VTKLoc.gd` — ключ `Attachments`
- Modify: `.check/layout_check.py` — `GONE` и `PRESENT`

**Interfaces:**
- Consumes: `_make_item_cell` (строка 1469), `toggle_attachment` из `VTKDraft.gd`
- Produces:
  - `_draft: Dictionary` — геттер в `VTKDraft.gd`, читает список обвесов дескриптора
  - `_make_att_cell(owner_path: String, grp: String, att_res) -> Control`
  - `_place_into` открывает панель обвесов

- [x] **Step 1: Стенд красный**

В `.check/layout_check.py`:
- в `GONE` дописать `"func _make_att_toggle("` — точная строка с `func` и открывающей скобкой, чтобы ловить удаление функции, а не любое упоминание.
- в `PRESENT` дописать `"_make_att_cell"`.

Run: `python .check\layout_check.py`
Expected: `MISS  _make_att_cell`.

- [x] **Step 2: Добавить геттер в `VTKDraft.gd`**

Функции `attachment_of` в черновике нет, а плитке нужно знать, выбран ли обвес.
Дописать в `VTKDraft.gd` после `toggle_attachment`:

```gdscript
# Какой обвес выбран у предмета, или "" если обвесов нет. UI спрашивает это
# для каждой клетки панели, поэтому список отдаётся наружу read-only.
func attachment_of(path: String) -> String:
	var d := descriptor_of(path)
	var ats = d.get("attachments")
	if typeof(ats) != TYPE_ARRAY:
		return ""
	for a in ats:
		return str(a)
	return ""
```

- [x] **Step 3: Добавить ключ в `RU`**

В `VTKLoc.gd`:
```
	'Attachments': 'Обвесы',
```

- [x] **Step 4: Переписать заголовок панели**

В `_build_att_panel` строка 1742 `head.text = Loc.txt("Target: ") + str(desc.get("name", "?"))` заменить на:

```gdscript
	head.text = Loc.txt("Attachments")
```

- [x] **Step 5: Заменить `_make_att_toggle` на плитку**

Функцию `_make_att_toggle` (строки 1770-1792) удалить целиком и заменить:

```gdscript
# Обвес как плитка, тем же кодом, что и предмет в каталоге. Раньше был чип, и
# состояние "выбран" не читалось: Godot рисует hover и pressed из темы, они
# перебивали normal, поэтому после клика не оставалось ничего. У плитки все
# четыре стиля заданы явно.
func _make_att_cell(owner_path: String, grp: String, att_res) -> Control:
	if att_res == null:
		return Control.new()
	var cell := Panel.new()
	cell.custom_minimum_size = Vector2(80, 110)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	var on := false
	if _draft != null:
		on = _draft.attachment_of(owner_path) == str(att_res.resource_path)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1a1510")
	normal.border_color = Color("#2a1f14")
	normal.border_width_all = 1
	normal.corner_radius_all = 4

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color("#221a12")
	hover.border_color = Color("#d48a3a44")
	hover.border_width_all = 1
	hover.corner_radius_all = 4

	var picked := StyleBoxFlat.new()
	picked.bg_color = Color("#2a1a0a")
	picked.border_color = _gold
	picked.border_width_all = 1
	picked.corner_radius_all = 4

	cell.add_theme_stylebox_override("panel", picked if on else normal)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var tex = TextureRect.new()
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.custom_minimum_size = Vector2(36, 36)
	if att_res.icon:
		tex.texture = att_res.icon
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(tex)

	var nm = Label.new()
	nm.text = str(att_res.name)
	nm.add_theme_font_size_override("font_size", 8)
	nm.add_theme_color_override("font_color", _gold if on else Color("#aaa"))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD
	nm.max_lines_visible = 2
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(nm)

	cell.tooltip_text = str(att_res.name) + "\n" + str(att_res.resource_path)
	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if _draft == null:
				return
			_draft.toggle_attachment(owner_path, str(att_res.resource_path), grp, _att_group_of)
			# Панель остаётся открытой: подбор обвесов идёт списком, и закрывать
			# её после каждого клика значило бы кликать дважды на каждый обвес.
			_refresh_pages()
	)
	cell.mouse_entered.connect(func():
		if not on:
			cell.add_theme_stylebox_override("panel", hover))
	cell.mouse_exited.connect(func():
		cell.add_theme_stylebox_override("panel", picked if on else normal))
	return cell
```

- [x] **Step 6: Вызвать плитку вместо чипа**

В `_build_att_panel` (строка 1763) заменить:
```gdscript
			flow.add_child(_make_att_toggle(path, grp, a))
```
на:
```gdscript
			flow.add_child(_make_att_cell(path, grp, _attachment_resource(a)))
```

Добавить хелпер после `_make_att_cell`:
```gdscript
# Из записи группы обвесов достаётся ресурс: _item_info отдаёт словарь с
# полем "resource", а плитке нужен сам ресурс - ради иконки и имени.
func _attachment_resource(a: Dictionary):
	return _item_info(str(a.get("path", ""))).get("resource")
```

- [x] **Step 7: Открывать обвесы кликом по предмету**

Функция `_place_into` (строка 1589) кладёт предмет и в конце зовёт `_after_place()`
дважды: из ветки с явным слотом (строка 1615) и после свободного размещения
(строка 1621). Обе точки проходят через `_after_place`, поэтому менять нужно его:

```gdscript
func _after_place() -> void:
	_clear_problem()
	_refresh_pages()
```

заменить на:

```gdscript
func _after_place() -> void:
	_clear_problem()
	# Клик по предмету открывает его обвесы: иначе до них надо было
	# добираться через кнопку в строке слота, о чём мало кто догадывался.
	# У обоймы панели нет - там тумблер заполнения, открывать нечего.
	if _last_placed != "" and not _is_magazine(_last_placed) \
			and Picker.has_panel(_item_info(_last_placed)):
		_open_att_path = _last_placed
	_last_placed = ""
	_refresh_pages()
```

И объявить `var _last_placed: String = ""` рядом с `var _open_att_path`, а в
`_place_into` присвоить `_last_placed = path` сразу после проверки
`_item_index` (строка 1599), до расчёта `amt`: если предмет не влезет в слот,
`_after_place` не зовётся и панель не откроется, а `_last_placed` уйдёт в
следующий клик и откроет панель не того предмета.

Проверить, что `_last_placed` обнуляется и в `_set_target_slot` (строка 1203):
смена цели закрывает панель, а вместе с ней должен и сброситься последний
предмет.

- [x] **Step 8: Проверить всё**

Run:
```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
```
Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `Tests passed: 2 file(s)`, `RESULT: every Loc.txt() key has a RU entry`.

- [x] **Step 9: Откатная точка**

Snapshot.

---

### Task 6: Документация, версия, пакет

**Files:**
- Modify: `loadouts/mod.txt` — `4.5.0` → `4.6.0`
- Modify: `AGENTS.md` — раздел «Проверка»
- Build: `Loadouts.vmz`

**Interfaces:**
- Consumes: всё из Task 1-5
- Produces: `Loadouts.vmz` версии 4.6.0

- [x] **Step 1: Поднять версию**

В `loadouts/mod.txt` заменить `version="4.5.0"` на `version="4.6.0"`.

- [x] **Step 2: Обновить `AGENTS.md`**

В разделе «Проверка» дописать:
```markdown
- Подкатегории берутся из `resource_path`, а таблица хранит только имена папок: жёсткие пути внутрь игры ломаются при апдейте. Магазин опознаётся суффиксом (`*_Magazine`, `*_Mag`, `*_Drum`), часть ствола — `*_Barrel`, потому что у `KAR-21` и `Makarov` папка одна на два смысла.
- Число колонок сетки считается от ширины в `_make_grid_columns`, а не задаётся константой: `GridContainer` без пересчёта давал четыре колонки в любом окне. Пересчёт вешается на `resized`, иначе на первом показе ширина нулевая и получается одна колонка.
```

- [x] **Step 3: Финальный прогон**

Run:
```powershell
python .check\layout_check.py
powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
python .check\keycheck.py
python .check\a2\run.py
python .check\encoding_check.py
```
Expected: `RESULT: символы раскладки на месте`, `Parse check passed: 9 scripts`, `RESULT: every Loc.txt() key has a RU entry`, `PASS=77 FAIL=0`.

- [x] **Step 4: Собрать пакет**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File pack.ps1`
Expected: печатает `Version in mod.txt: 4.6.0`, затем `Pack done`.

- [x] **Step 5: Проверить пакет**

Run: `python .check\encoding_check.py`
Expected: `pack version: 4.6.0`, `PROBLEMS: 0`.

- [x] **Step 6: Откатная точка**

Snapshot вместе с `Loadouts.vmz`.

- [x] **Step 7: Передать пользователю**

Сообщить путь к пакету и чек-лист:

1. Шаг 1: сетка занимает всю высоту, колонок больше пяти.
2. Шаг 1: строка «Фильтр» с чипами, `[Сброс]` возвращает все предметы слота, слот остаётся `Primary`.
3. Шаг 2: колонки считаются от ширины окна.
4. Клик по AKM кладёт его в `Primary` и открывает «Обвесы» с плитками.
5. Выбранный обвес остаётся золотым после ухода курсора.
6. Шаг 2: подкатегории «Штурмовые винтовки», «Снайперские винтовки», «Пистолеты» в фасетах.
7. RU: «Бронежилеты», «Оптика», «Рюкзаки» переведены.

---

---

## Отклонения от кода в плане

План — контракт, но шесть мест в нём разошлись с кодом или с решением
пользователя. Все шесть проверены стендами, все шесть записаны здесь.

### 1. `has_attachment` вместо `attachment_of` (Task 5, Step 2)

План предлагал `attachment_of(path)`, возвращающий первый элемент списка
обвесов. У ствола одновременно стоят прицел, коллиматор, дуло и лазер, и такой
геттер оставлял золотой ровно один обвес из четырёх — то самое, что пользователь
и попросил исправить. Вместо него `has_attachment(owner_path, att_path) -> bool`:
принадлежность по своему пути, спрашивается плиткой для каждого обвеса. Тест
`t_has_attachment()` в `test_draft.gd` закрепляет три обвеса разных групп
одновременно.

### 2. Имя предмета не исчезло из шапки панели (Task 5, Step 4)

План меняет `head.text` с `Loc.txt("Target: ") + имя` на `Loc.txt("Attachments")`.
Панель стоит под каталогом, и больше нигде на экране не сказано, чьи это обвесы,
поэтому заголовок стал «Обвесы», а имя предмета ушло отдельной строкой под ним.

### 3. `_make_att_toggle` удалён, флаг `on` не переехал (Task 5, шаги 5-6)

Плитка считает выбор сама через `has_attachment`. Пометка `e["on"] = ats.has(...)`
в `_att_entries` осталась бы вторым местом, где живёт состояние выбора, и читателей
у неё не осталось — поэтому удалена вместе с комментарием.

### 4. Поиск не дублируется в `_rebuild_shelves` (Task 4, Step 3)

План фильтрует `_items_for_target()` по запросу и потом ещё раз вызывает
`matches_search` в `_rebuild_shelves`. Второй прогон ничего не меняет, поэтому
убран. Зато `_set_search()` теперь перестраивает и шапку фильтров: её чипы
считаются из того же списка, и без этого после запроса «акм» строка фильтров
предлагала бы категории, чьи предметы уже отсеялись.

### 5. `out.sort()` убран из списка подкатегорий (Task 4, Step 5)

План дописывает подкатегории в порядке `SUBCATEGORY_ORDER` и сразу сортирует
результат, что этот порядок аннулирует. Сортировка осталась только для подкатегорий,
которых в таблице нет, — они идут после таблицы по алфавиту.

### 6. Устаревший комментарий над `CATEGORY_ORDER` (Task 2)

Комментарий перечислял 15 категорий из данных игры, которых в `CATEGORY_ORDER` нет:
после обновления игры он врал. Переписан на «управляет только порядком категорий в
UI; порядок выводится из данных».

### 7. Вертикальный `SIZE_EXPAND_FILL` в `_page_wrap` и `_page_columns`

План требовал убрать `custom_minimum_size` у полок и оставить один `SIZE_EXPAND_FILL`
на `shelves_scroll`. Этого мало: у `ScrollContainer` минимальная высота 0, и без
флага на контейнерах выше по вертикали до `_editor_panel` область схлопывалась в ноль
— сетка предметов не рисовалась вообще, при полностью рабочих данных и зелёном стенде.
Проверено пробой на Godot 4.6.3: без цепочки флагов `scroll.y = 0`, с цепочкой и полом
`scroll.y = 240`. Поэтому флаг добавлен `_page_wrap` и `_page_columns`, а
`custom_minimum_size` вернулся как пол на случай, когда внешний контейнер игры отдаёт
ровно минимальную высоту.

### 8. `Picker.category_allowed` для слотов оружия

Удилище, гитара и губная гармошка в игре помечены слотами `Primary`/`Secondary`
(`type = Fishing` и `Instrument`, что видно в бинарях предметов), поэтому в фильтр шага 1
к `Weapons` доезжали лишние чипы. Правило живёт в `VTKPicker.gd`, а не в `VTKUI.gd`,
чтобы тестироваться headless.

---

## Смешанные окончания строк

`VTKLoc.gd`, `VTKDraft.gd` и `VTKPicker.gd` хранятся в LF, `VTKUI.gd` и
`VTKData.gd` — в CRLF. Любой сплайс нормализует файл и возвращает ему исходные
окончания, иначе `encoding_check.py` падает на смешанных окончаниях.

---

## Что не делаем

- Не трогаем другие вкладки: `Sets`, `Settings`, `Teleport`.
- Не переводим имена предметов.
- Не меняем формат `VTKsets.json`.
- Не хардкодим пути в игру.
- `_make_chip_style` остаётся в файле для строк фасетов и слотов.