# РџР»Р°РЅ: РїРµСЂРµСЂР°Р±РѕС‚РєР° РІРєР»Р°РґРєРё В«РЎРµС‚С‹В» (РіРёР±СЂРёРґ H3)

РЎС‚Р°С‚СѓСЃ: С‡РµСЂРЅРѕРІРёРє РЅР° СЂРµРІСЊСЋ.
РСЃС‚РѕС‡РЅРёРє С‚СЂРµР±РѕРІР°РЅРёР№: `docs/superpowers/specs/2026-10-08-sets-tab-layout-design.md` (СѓС‚РІРµСЂР¶РґРµРЅРѕ 2026-10-08).
РњРѕРєР°РїС‹: `.docs/setsmockups/h3-*.html` (СѓС‚РІРµСЂР¶РґС‘РЅРЅС‹Рµ), СЂР°Р·Р±РѕСЂ РїРѕ РЅРёРј вЂ” РІ Р·Р°РґР°С‡Р°С… РЅРёР¶Рµ.

## РђСЂС…РёС‚РµРєС‚СѓСЂР°

РЎРµР№С‡Р°СЃ (4.8.3): РІРєР»Р°РґРєР° В«РЎРµС‚С‹В» вЂ” РІРµСЂС‚РёРєР°Р»СЊРЅР°СЏ СЃС‚РѕРїРєР° `title в†’ СЃРїРёСЃРѕРє РєР°СЂС‚РѕС‡РµРє (3 РєРѕР»РѕРЅРєРё, Apply/Edit/вњ•/РєР»Р°РІРёС€Р° РЅР° РєР°Р¶РґРѕР№) в†’ HSeparator в†’ СЂРµРґР°РєС‚РѕСЂ`; С€Р°Рі 1 РґРµСЂР¶РёС‚ Р»РµРІСѓСЋ РєРѕР»РѕРЅРєСѓ СЃР»РѕС‚РѕРІ (`_page_columns` + `_side_slots_box`, СЃС‚СЂРѕРєРё `_make_slot_row`); С€Р°Рі 2 вЂ” С‡РёРїС‹ РІС‹Р±СЂР°РЅРЅС‹С… РїСЂРµРґРјРµС‚РѕРІ СЃРІРµСЂС…Сѓ (`_gear_chips`, `_make_gear_chip`) Рё РєР»РµС‚РєРё РєР°С‚Р°Р»РѕРіР° Р±РµР· СѓРїСЂР°РІР»РµРЅРёР№; РїР°РЅРµР»СЊ РѕР±РІРµСЃРѕРІ РІСЃС‚СЂРѕРµРЅРЅР°СЏ (`_equip_att_box`/`_gear_att_box` РїРѕРґ РїРѕР»РєР°РјРё/РєР°С‚Р°Р»РѕРіРѕРј, `_rebuild_att_box`).

Р¦РµР»РµРІР°СЏ СЃС‚СЂСѓРєС‚СѓСЂР° (H3):

```
РІРєР»Р°РґРєР° В«РЎРµС‚С‹В» (tab vbox)
в”њв”Ђв”Ђ _rail_box (236px, С‚РѕР»СЊРєРѕ РєРѕРЅС‚РµРЅС‚)          в†ђ СЂРµР№Р»: Р·Р°РіРѕР»РѕРІРѕРє, РєР°СЂС‚РѕС‡РєРё-СЃС‚СЂРѕРєРё
в”‚     title / _list_container(_cards_grid Г—1) / CreateCard(РїСѓРЅРєС‚РёСЂ)
в””в”Ђв”Ђ _right_box (EXPAND_FILL)
      в”њв”Ђв”Ђ _preview_box   вЂ” РїСЂРµРІСЊСЋ РІС‹Р±СЂР°РЅРЅРѕРіРѕ СЃРµС‚Р° (РІРёРґРЅРѕ, РєРѕРіРґР° _draft == null)
      в””в”Ђв”Ђ _editor_panel  вЂ” СЃС‚РµР»РїРµСЂ + С‚СЂРё СЃС‚СЂР°РЅРёС†С‹ (РІРёРґРЅРѕ, РєРѕРіРґР° _draft != null)

СЃС‚СЂР°РЅРёС†Р° В«Р­РєРёРїРёСЂРѕРІРєР°В»:  _slots_flow (С‡РёРїС‹ СЃР»РѕС‚РѕРІ, С„РёРєСЃ. РІС‹СЃРѕС‚Р°) в†’ _target_bar в†’ РїРѕРёСЃРє в†’ РїРѕР»РєРё в†’ (РѕР±РІРµСЃС‹ С‚РµРїРµСЂСЊ РѕРІРµСЂР»РµР№)
СЃС‚СЂР°РЅРёС†Р° В«РЎРЅР°СЂСЏР¶РµРЅРёРµВ»:  РїРѕРёСЃРє в†’ РїРѕР»РєР° С„Р°СЃРµС‚РѕРІ (+ РїСѓРЅРєС‚РёСЂРЅР°СЏ ChosenRow В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ») | СЃРµС‚РєР° РєР»РµС‚РѕРє СЃ СЂСЏРґР°РјРё СѓРїСЂР°РІР»РµРЅРёСЏ (в€’ n + вљЎ вњ•, РћР±РІРµСЃС‹/mag)
РѕР±РІРµСЃС‹:  _att_overlay вЂ” РѕРІРµСЂР»РµР№ РїРѕРІРµСЂС… РІРєР»Р°РґРєРё (Р·Р°С‚РµРјРЅРµРЅРёРµ + РїР°РЅРµР»СЊ), Р° РЅРµ РІСЃС‚СЂРѕРµРЅРЅС‹Рµ Р±Р»РѕРєРё
С„РѕРєСѓСЃ:   в›¶ РІ С€Р°РїРєРµ СЂРµРґР°РєС‚РѕСЂР° РїСЂСЏС‡РµС‚ _rail_box
```

Р“СЂР°С„ Р·Р°РґР°С‡ (РєР°Р¶РґР°СЏ Р·Р°РґР°С‡Р° вЂ” РѕС‚РґРµР»СЊРЅС‹Р№ С†РёРєР» РєСЂР°СЃРЅС‹Р№ в†’ Р·РµР»С‘РЅС‹Р№ в†’ РєРѕРјРјРёС‚):

```
T0 (РєРѕРјРјРёС‚ РЅРµР·Р°РєРѕРјРјРёС‡РµРЅРЅРѕРіРѕ VTKFeed)
 в”њв”Ђ T1  VTKData.spawn_gear + test_spawn        (РЅРµР·Р°РІРёСЃРёРјР°СЏ)
 в”њв”Ђ T2  СЃС‚СЂСѓРєС‚СѓСЂР° rail | right + РїСѓСЃС‚РѕРµ РїСЂРµРІСЊСЋ (РЅРµР·Р°РІРёСЃРёРјР°СЏ)
 в”‚   в””в”Ђ T3  РєР°СЂС‚РѕС‡РєРё + РІС‹Р±РѕСЂ + РїСЂРµРІСЊСЋ + CreateCard + draw_dashes
 в”‚       в””в”Ђ T4  С„РѕРєСѓСЃ в›¶
 в”њв”Ђ T5  С€Р°Рі 1: РіРѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅС‹Рµ С‡РёРїС‹ СЃР»РѕС‚РѕРІ      (РЅРµР·Р°РІРёСЃРёРјР°СЏ)
 в”‚   в””в”Ђ T6  С€Р°Рі 2: РєР»РµС‚РєРё СЃ СѓРїСЂР°РІР»РµРЅРёРµРј + В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» + вљЎ (РЅСѓР¶РµРЅ T1, T5)
 в”‚       в””в”Ђ T7  РѕРІРµСЂР»РµР№ РѕР±РІРµСЃРѕРІ                (РїРѕСЃР»Рµ T6)
 в””в”Ђ T8  СЂРµР»РёР· 4.9.0 (РІРµСЂСЃРёСЏ, AGENTS, СЃС‚РµРЅРґС‹, pack)
      в””в”Ђ T9  README: Р±РµР· РІРµСЂСЃРёРё, РѕСЃРІРµР¶РёС‚СЊ РІРѕР·РјРѕР¶РЅРѕСЃС‚Рё (Р±РµР· СЃС‚РµРЅРґРѕРІ)
```

## Global Constraints

1. **РљРѕРјРјРёС‚С‹ вЂ” С‚РѕР»СЊРєРѕ `loadouts/**`.** `.check/`, `docs/`, `.docs/`, `AGENTS.md` РЅРµ РІ РёРЅРґРµРєСЃРµ git (`git ls-files` РёС… РЅРµ РІРёРґРёС‚): СЃС‚РµРЅРґС‹ Рё С‚РµСЃС‚С‹ РїСЂР°РІРёРј Р»РѕРєР°Р»СЊРЅРѕ, РѕРЅРё РІ РєРѕРјРјРёС‚С‹ РЅРµ РІС…РѕРґСЏС‚. РќРёРєР°РєРёС… `git add -A`: РІСЃРµРіРґР° `git add <РєРѕРЅРєСЂРµС‚РЅС‹Р№ С„Р°Р№Р»>` + `git commit -m "..."` (one-liner, Р°РЅРіР»РёР№СЃРєРёР№).
2. **Р‘Р°Р·РѕРІР°СЏ Р»РёРЅРёСЏ СѓР¶Рµ Р·РµР»С‘РЅР°СЏ (РїСЂРѕРІРµСЂРµРЅРѕ РЅР° СЌС‚РѕРј РїР»Р°РЅРёСЂРѕРІР°РЅРёРё):** `check.ps1` вЂ” parse 11 СЃРєСЂРёРїС‚РѕРІ, 4 С‚РµСЃС‚Р° passed; `layout_check.py` вЂ” GONE 38 / GONE_RE 1 / PRESENT 53 / FUNCS 9 / HOOKS_GONE 4, ok; `keycheck.py` вЂ” РІСЃРµ РєР»СЋС‡Рё СЃ RU. РџСЂРѕРіРѕРЅ РїРµСЂРµРґ РЅР°С‡Р°Р»РѕРј РєР°Р¶РґРѕР№ Р·Р°РґР°С‡Рё.
3. **РљСЂР°СЃРЅС‹Р№ С€Р°Рі РєР°Р¶РґРѕР№ Р·Р°РґР°С‡Рё вЂ” СЃРЅР°С‡Р°Р»Р° СЃРїРёСЃРєРё СЃС‚РµРЅРґР°** (`layout_check.py`: GONE/PRESENT/FUNCS; Сѓ T1 вЂ” С‚РµСЃС‚ РІ `$tests`), РїСЂРѕРіРѕРЅ в†’ РѕР¶РёРґР°РµРј РєСЂР°СЃРЅС‹Р№, Р·Р°С‚РµРј РєРѕРґ в†’ Р·РµР»С‘РЅС‹Р№. РљР»СЋС‡Рё `Loc.txt` РґРѕР±Р°РІР»СЏСЋС‚СЃСЏ РїР°СЂРѕР№ (РІС‹Р·РѕРІ + RU-Р·Р°РїРёСЃСЊ) РІ РѕРґРЅРѕР№ Р·Р°РґР°С‡Рµ: keycheck РЅРµ Р±С‹РІР°РµС‚ В«РєСЂР°СЃРЅС‹Рј РїРѕ РїР»Р°РЅСѓВ», РѕРЅ Р»РѕРІРёС‚ СЂР°СЃСЃРёРЅС…СЂРѕРЅ.
4. **`.gd` вЂ” С‚Р°Р±С‹, UTF-8.** VTKUI.gd/VTKData.gd/VTKSurface.gd вЂ” CRLF, VTKLoc.gd вЂ” LF; С„Р°Р№Р»С‹ С†РµР»РёРєРѕРј РЅРµ РїРµСЂРµРїРёСЃС‹РІР°С‚СЊ. РџРµСЂРµРґ Р±РѕР»СЊС€РёРјРё СЃРїР»Р°Р№СЃР°РјРё VTKUI.gd вЂ” СЃРЅР°РїС€РѕС‚: `Copy-Item loadouts\mods\VTK\VTKUI.gd "$env:TEMP\opencode\vtk-snap-$(Get-Date -Format HHmmss).gd"`.
5. **РђРЅРЅРѕС‚Р°С†РёРё С‚РёРїРѕРІ РѕР±СЏР·Р°С‚РµР»СЊРЅС‹ С‚Р°Рј, РіРґРµ РµСЃС‚СЊ `return null`/РїСЂРёСЃРІР°РёРІР°РЅРёРµ СѓР·Р»РѕРІ** (РёРЅР°С‡Рµ Parse Error РїРѕ РІСЃРµРјСѓ С„Р°Р№Р»Сѓ): РЅРѕРІС‹Рµ `var` СЃ null вЂ” СЃ С‚РёРїРѕРј (`var _slots_flow: HFlowContainer = null`).
6. **РџСЂРѕРІРµСЂРєР° РїРѕСЃР»Рµ РєР°Р¶РґРѕР№ Р·Р°РґР°С‡Рё** (РІСЃРµ С‚СЂРё, РІ СЌС‚РѕРј РїРѕСЂСЏРґРєРµ):
   ```
   py -3 .check\layout_check.py
   py -3 .check\keycheck.py
   powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
   ```
   Р’РµСЂРґРёРєС‚ check.ps1 = exit 0 + РЅРµС‚ `SCRIPT ERROR|Parse Error|Invalid call|Failed to load script` + СЃС‚СЂРѕРєР° `tests passed`.
7. **РќРѕРІС‹Рµ RU-Р·Р°РїРёСЃРё** вЂ” РІ `VTKLoc.gd` С‚РµРј Р¶Рµ РїСЂРѕС…РѕРґРѕРј, С‡С‚Рѕ Рё `Loc.txt`; СЃС‚СЂРѕРєР° СЃ РєР°РІС‹С‡РєРѕР№ вЂ” РІ РѕРґРёРЅР°СЂРЅС‹С… РєР°РІС‹С‡РєР°С…. РЎСѓС‰РµСЃС‚РІСѓСЋС‰РёРµ РєР»СЋС‡Рё РїРµСЂРµРёСЃРїРѕР»СЊР·СѓРµРј: `'+ Create loadout'`, `'Apply'`, `'Edit'`, `' items В· '`, `' in equipment'`, `'Equipment'`, `'Gear'`, `'Empty'`, `'Set is empty'`, `'Slots'`, `'Attachments'`, `'No saved loadouts'`, `'Remove'`, `'Full magazine'`.
8. **`preload`-СЃС‡С‘С‚С‡РёРєРё Рё С‚Р°Р±Р»РёС†Р° РїРµСЂРµРёРјРµРЅРѕРІР°РЅРёР№ РІ AGENTS.md РЅРµ РјРµРЅСЏСЋС‚СЃСЏ** (РЅРѕРІС‹С… С„Р°Р№Р»РѕРІ РјРѕРґР° РЅРµ РїРѕСЏРІР»СЏРµС‚СЃСЏ; `test_spawn.gd` Р¶РёРІС‘С‚ РІ `.check/project/tests/`). РџСЂР°РІРєРё AGITH.md вЂ” С‚РѕР»СЊРєРѕ Р·Р°РґР°С‡Р° T8.
9. РРіСЂРѕРІРѕР№ РїСЂРѕРіРѕРЅ РїРѕСЃР»Рµ РєР°Р¶РґРѕР№ Р·Р°РґР°С‡Рё РЅРµ РѕР±СЏР·Р°С‚РµР»РµРЅ; **РѕР±СЏР·Р°С‚РµР»РµРЅ РїРѕСЃР»Рµ T3, T5, T7** (РІРёР·СѓР°Р»СЊРЅР°СЏ С‡Р°СЃС‚СЊ) вЂ” РїРµСЂРµРґ T8.

---

## T0. Р—Р°РєРѕРјРјРёС‚РёС‚СЊ РЅРµР·Р°РєРѕРјРјРёС‡РµРЅРЅРѕРµ

**Р¦РµР»СЊ:** СЂР°Р±РѕС‡РµРµ РґРµСЂРµРІРѕ С‡РёСЃС‚РѕРµ РґРѕ РЅР°С‡Р°Р»Р° РїРµСЂРµСЂР°Р±РѕС‚РєРё.

РЎРµР№С‡Р°СЃ `git status` РїРѕРєР°Р·С‹РІР°РµС‚ ` M loadouts/mods/VTK/VTKFeed.gd` вЂ” РЅРµР·Р°РєРѕРјРјРёС‡РµРЅРЅР°СЏ СЂР°Р±РѕС‚Р° РїСЂРѕС€Р»РѕР№ СЃРµСЃСЃРёРё (С€СЂРёС„С‚ 15в†’17, РІС‹СЃРѕС‚Р° СЃС‚СЂРѕРєРё 20в†’23, РёРєРѕРЅРєР° 14в†’16, РјР°СЃС€С‚Р°Р± РѕСЂСѓР¶РёСЏ Г—2в†’Г—4, РґРѕР±Р°РІР»РµРЅ `norm_weapon`), СѓР¶Рµ РїРѕРєСЂС‹С‚Р°СЏ `test_feed.gd`.

**Р”РµР№СЃС‚РІРёРµ:**
```
git add loadouts/mods/VTK/VTKFeed.gd
git commit -m "Enlarge kill feed icons and normalize weapon names"
```
**РџСЂРѕРІРµСЂРєР°:** `git status` РїСѓСЃС‚; `git log --oneline -3` вЂ” РЅРѕРІС‹Р№ РєРѕРјРјРёС‚ РЅР°Рґ `ef0d249`.

---

## T1. VTKData.spawn_gear вЂ” СЃРїР°РІРЅ РѕРґРЅРѕРіРѕ РїСЂРµРґРјРµС‚Р°

**Р¦РµР»СЊ:** РєРЅРѕРїРєР° вљЎ РЅР° С€Р°РіРµ 2 СЃРјРѕР¶РµС‚ СЃР»РѕР¶РёС‚СЊ РІРµСЃСЊ РЅР°Р±РѕСЂ РїСЂРµРґРјРµС‚Р° (`count` РєРѕРїРёР№) РІ РёРЅРІРµРЅС‚Р°СЂСЊ РѕРґРЅРѕР№ РєРЅРѕРїРєРѕР№, Р±РµР· СЌРєРёРїРёСЂРѕРІРєРё Рё Р±РµР· СЃРѕС…СЂР°РЅРµРЅРёСЏ СЃРµС‚Р°.

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

1. РЎРѕР·РґР°С‚СЊ `.check/project/tests/test_spawn.gd` (РєРѕРґ РЅРёР¶Рµ) вЂ” РІС‹Р·С‹РІР°РµС‚ `VTKData.spawn_gear`, РєРѕС‚РѕСЂРѕР№ РµС‰С‘ РЅРµС‚ в†’ check.ps1 РєСЂР°СЃРЅС‹Р№ (`SCRIPT ERROR` РЅР° РЅРµСЃСѓС‰РµСЃС‚РІСѓСЋС‰РµР№ С„СѓРЅРєС†РёРё).
2. Р’ `.check/check.ps1`, СЃС‚СЂРѕРєР° 80, РґРѕР±Р°РІРёС‚СЊ С‚РµСЃС‚ РІ `$tests`:
```powershell
$tests = @("res://tests/test_draft.gd", "res://tests/test_picker.gd", "res://tests/test_hooks.gd", "res://tests/test_feed.gd", "res://tests/test_spawn.gd")
```

### РљРѕРґ

`loadouts/mods/VTK/VTKData.gd`:

1. РњС‘СЂС‚РІС‹Р№ `own` РІ `apply_loadout` (СЃС‚СЂРѕРєРё 397, 409, 426) вЂ” СѓРґР°Р»РёС‚СЊ (`own.append` РЅРёРіРґРµ РЅРµ С‡РёС‚Р°РµС‚СЃСЏ), gear-С†РёРєР» (417-426) Р·Р°РјРµРЅРёС‚СЊ РЅР° РІС‹Р·РѕРІ РѕР±С‰РµРіРѕ С…РµР»РїРµСЂР°:
```gdscript
	var fitted := 0
	var skipped := 0
```
```gdscript
	var gear: Array = pack["gear"]
	for desc in gear:
		if typeof(desc) != TYPE_DICTIONARY:
			continue
		_insert_desc(interface, ig, desc)
```
(С†РёРєР» `for i in range(_instances(desc))` СЃРѕ РІСЃРµРјРё `break`/`gsd` СѓРµР·Р¶Р°РµС‚ РІ `_insert_desc` С†РµР»РёРєРѕРј)

2. Р”РІРµ РЅРѕРІС‹Рµ С„СѓРЅРєС†РёРё вЂ” РїРµСЂРµРґ `_is_magazine` (СЂР°Р·РґРµР» `# ---------- internals ----------`, СЃС‚СЂРѕРєР° 457):
```gdscript
# Р’СЃС‚Р°РІРёС‚СЊ РѕРґРёРЅ gear-РґРµСЃРєСЂРёРїС‚РѕСЂ СЃС‚РѕР»СЊРєРѕ СЂР°Р·, СЃРєРѕР»СЊРєРѕ Р·Р°РґР°РЅРѕ count. РћР±С‰Р°СЏ
# С‚РѕС‡РєР° РґР»СЏ apply_loadout Рё РєРЅРѕРїРєРё вљЎ: СЃРїР°РІРЅ РѕРґРЅРѕРіРѕ РїСЂРµРґРјРµС‚Р° РЅРµ РґРѕР»Р¶РµРЅ
# СЂР°Р·СЉРµР·Р¶Р°С‚СЊСЃСЏ РїРѕ РґРІСѓРј РєРѕРїРёСЏРј С†РёРєР»Р°. Р’РѕР·РІСЂР°С‰Р°РµС‚ С‡РёСЃР»Рѕ СЃРѕР·РґР°РЅРЅС‹С… СѓР·Р»РѕРІ.
static func _insert_desc(interface, ig, desc: Dictionary) -> int:
	var placed := 0
	for i in range(_instances(desc)):
		var gsd = _build_slot_data(desc)
		if gsd == null:
			break
		_insert(interface, ig, gsd)
		placed += 1
	return placed

# РћРґРёРЅ РїСЂРµРґРјРµС‚ СЃРЅР°СЂСЏР¶РµРЅРёСЏ РІ РёРЅРІРµРЅС‚Р°СЂСЊ С†РµР»РёРєРѕРј (count РєРѕРїРёР№), Р±РµР· СЌРєРёРїРёСЂРѕРІРєРё:
# РєРЅРѕРїРєР° вљЎ РІ РєР»РµС‚РєРµ С€Р°РіР° 2. Р‘РµР· РёРіСЂРѕРІРѕРіРѕ РґРµСЂРµРІР° РјРѕР»С‡Р° 0, Р° РЅРµ РѕС€РёР±РєР° - С‚Р°Рє
# Р¶Рµ РІРµРґС‘С‚ СЃРµР±СЏ apply_loadout, Рё headless-С‚РµСЃС‚ РЅРµ РґРѕР»Р¶РµРЅ РїР°РґР°С‚СЊ.
static func spawn_gear(desc: Dictionary) -> int:
	var root = _root_node()
	if not root:
		return 0
	var interface = root.get_node_or_null("Map/Core/UI/Interface")
	if not interface:
		print("[VTK] spawn_gear: no Interface node")
		return 0
	var loader = root.get_node_or_null("Loader")
	var ig = interface.get("inventoryGrid")
	if ig == null or not is_instance_valid(ig):
		print("[VTK] spawn_gear: no inventoryGrid")
		return 0
	var placed := _insert_desc(interface, ig, desc)
	if loader and loader.has_method("SaveCharacter"):
		loader.SaveCharacter()
	if interface.has_method("UpdateStats"):
		interface.UpdateStats(true)
	if placed > 0:
		_notify(loader, Loc.txt("Spawned: ") + str(desc.get("name", "?"))
			+ " x" + str(placed), Color.GREEN)
	return placed
```
`Loc` РІ VTKData СѓР¶Рµ РѕР±СЉСЏРІР»РµРЅ (`const Loc`), `_root_node`/`_insert`/`_build_slot_data`/`_notify` вЂ” СЃРѕСЃРµРґРё РЅРёР¶Рµ/РІС‹С€Рµ, РїРѕСЂСЏРґРѕРє РІ С„Р°Р№Р»Рµ РЅРµ РІР°Р¶РµРЅ.

3. `.check/project/tests/test_spawn.gd` (РЅРѕРІС‹Р№ С„Р°Р№Р», РїРѕ РѕР±СЂР°Р·С†Сѓ `test_feed.gd`):
```gdscript
extends SceneTree

const VTKData = preload("res://mods/VTK/VTKData.gd")

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
	t_spawn_no_game()
	t_insert_desc()
	t_instances()
	print("")
	if fails == 0:
		print("tests passed")
		quit(0)
	else:
		print("Spawn tests failed: ", fails)
		quit(1)

# Р‘РµР· РёРіСЂРѕРІРѕРіРѕ РґРµСЂРµРІР° СЃРїР°РІРЅ РјРѕР»С‡Р° РІРѕР·РІСЂР°С‰Р°РµС‚ 0, Р° РЅРµ РїР°РґР°РµС‚: headless-С‚РµСЃС‚
# РЅРµ СЃРѕРґРµСЂР¶РёС‚ Map/Core/UI/Interface.
func t_spawn_no_game() -> void:
	ck(VTKData.spawn_gear({"path": "", "name": "Test"}) == 0, "Р±РµР· Interface СЃРїР°РІРЅ РѕС‚РґР°Р» 0")
	ck(VTKData.spawn_gear({}) == 0, "РїСѓСЃС‚РѕР№ РґРµСЃРєСЂРёРїС‚РѕСЂ С‚РѕР¶Рµ 0")

# _insert_desc РЅРµ РґРѕС‚СЂР°РіРёРІР°РµС‚СЃСЏ РґРѕ interface, РїРѕРєР° РІСЃС‚Р°РІР»СЏС‚СЊ РЅРµС‡РµРіРѕ: РїСѓСЃС‚РѕР№
# РїСѓС‚СЊ РґР°С‘С‚ null РІ _build_slot_data Рё РѕР±СЂС‹РІ С†РёРєР»Р° РЅР° РїРµСЂРІРѕР№ РёС‚РµСЂР°С†РёРё.
func t_insert_desc() -> void:
	ck(VTKData._insert_desc(null, null, {"path": ""}) == 0, "РїСѓСЃС‚РѕР№ РїСѓС‚СЊ: 0 РІСЃС‚Р°РІРѕРє")
	ck(VTKData._insert_desc(null, null, {"path": "", "count": 5}) == 0,
		"Р±РёС‚С‹Р№ РїСѓС‚СЊ РѕР±СЂС‹РІР°РµС‚СЃСЏ РїРµСЂРІРѕР№ РёС‚РµСЂР°С†РёРµР№")

func t_instances() -> void:
	ck(VTKData._instances({}) == 1, "Р±РµР· count РѕРґРёРЅ РёРЅСЃС‚Р°РЅСЃ")
	ck(VTKData._instances({"count": 99}) == 32, "count РєР»Р°РјРїРёС‚СЃСЏ Рє 32")
	ck(VTKData._instances({"count": -5}) == 0, "РјРёРЅСѓСЃРѕРІРѕР№ count РЅРѕР»СЊ")
```

### Interfaces

- **Produces:** `VTKData.spawn_gear(desc: Dictionary) -> int`, `VTKData._insert_desc(interface, ig, desc) -> int`, С‚РµСЃС‚ `test_spawn.gd`.
- **Consumes:** `_root_node`, `_insert`, `_build_slot_data`, `_instances`, `_notify`, `Loc` вЂ” СЃСѓС‰РµСЃС‚РІСѓСЋС‰РёРµ.
- **Changes:** `apply_loadout` вЂ” СѓРґР°Р»С‘РЅ РјС‘СЂС‚РІС‹Р№ `own`, gear-С†РёРєР» Р·Р°РјРµРЅС‘РЅ РЅР° `_insert_desc` (РїРѕРІРµРґРµРЅРёРµ РЅРµ РјРµРЅСЏРµС‚СЃСЏ: С‚Р° Р¶Рµ РїРѕСЃР»РµРґРѕРІР°С‚РµР»СЊРЅРѕСЃС‚СЊ РІС‹Р·РѕРІРѕРІ).

### РџСЂРѕРІРµСЂРєР°

`check.ps1` Р·РµР»С‘РЅС‹Р№ (5 С‚РµСЃС‚РѕРІ), `layout_check.py`/`keycheck.py` Р±РµР· РёР·РјРµРЅРµРЅРёР№ (Р·РµР»С‘РЅС‹Рµ).

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKData.gd
git commit -m "Add VTKData.spawn_gear for one item straight to inventory"
```

---

## T2. РЎС‚СЂСѓРєС‚СѓСЂР°: СЂРµР№Р» СЃР»РµРІР°, РїСЂРµРІСЊСЋ Рё СЂРµРґР°РєС‚РѕСЂ СЃРїСЂР°РІР°

**Р¦РµР»СЊ:** РєР°СЂРєР°СЃ H3 вЂ” `_rail_box` (236px) Рё `_right_box` (`_preview_box` + `_editor_panel`) РєР°Рє sibling'Рё РІРЅСѓС‚СЂРё С‚Р°Р±Р°; СЃРїРёСЃРєРё СЃРµС‚РѕРІ РїРµСЂРµРµР·Р¶Р°СЋС‚ РІ СЂРµР№Р», СЂРµРґР°РєС‚РѕСЂ РІ РїСЂР°РІСѓСЋ РєРѕР»РѕРЅРєСѓ; РїСЂРµРІСЊСЋ-Р·Р°РіР»СѓС€РєР°. РЎРѕРґРµСЂР¶РёРјРѕРµ РєР°СЂС‚РѕС‡РµРє Рё РїСЂРµРІСЊСЋ вЂ” T3.

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

`layout_check.py`, РІ `PRESENT` РґРѕР±Р°РІРёС‚СЊ:
```python
    "_rail_box",
    "_right_box",
    "_preview_box",
    "RAIL_WIDTH := 236",
    "_refresh_preview",
```
РџСЂРѕРіРѕРЅ в†’ `MISS` РїРѕ РІСЃРµРј РїСЏС‚Рё СЃС‚СЂРѕРєР°Рј.

### РљРѕРґ

**`VTKUI.gd`, Р±Р»РѕРє var (РїРѕСЃР»Рµ СЃС‚СЂРѕРєРё 24):**
```gdscript
# ============== TAB: РЎРµС‚С‹ ==============
# Р“РёР±СЂРёРґ H3: СЃР»РµРІР° СЂРµР№Р» СЃРµС‚РѕРІ, СЃРїСЂР°РІР° РїСЂРµРІСЊСЋ (РєРѕРіРґР° СЂРµРґР°РєС‚РѕСЂ Р·Р°РєСЂС‹С‚) Рё
# СЂРµРґР°РєС‚РѕСЂ. Р РµР№Р» Рё РїСЂР°РІР°СЏ РєРѕР»РѕРЅРєР° - sibling'С‹, С‡С‚РѕР±С‹ С„РѕРєСѓСЃ-СЂРµР¶РёРј (T4)
# РїСЂСЏС‚Р°Р» С‚РѕР»СЊРєРѕ СЂРµР№Р».
const RAIL_WIDTH := 236
var _rail_box: VBoxContainer = null
var _right_box: VBoxContainer = null
var _preview_box: VBoxContainer = null
```

**`_build_loadouts_tab` (СЃС‚СЂРѕРєРё 418-442) вЂ” Р·Р°РјРµРЅРёС‚СЊ С†РµР»РёРєРѕРј:**
```gdscript
func _build_loadouts_tab(parent: VBoxContainer) -> void:
	_rail_box = VBoxContainer.new()
	_rail_box.custom_minimum_size = Vector2(RAIL_WIDTH, 0)
	_rail_box.add_theme_constant_override("separation", 6)
	parent.add_child(_rail_box)

	var list_title = Label.new()
	list_title.text = Loc.txt("Saved loadouts")
	list_title.add_theme_font_size_override("font_size", 13)
	list_title.add_theme_color_override("font_color", Color("#ddd"))
	_rail_box.add_child(list_title)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail_box.add_child(_list_container)

	_cards_grid = GridContainer.new()
	_cards_grid.columns = 1
	_cards_grid.add_theme_constant_override("h_separation", 6)
	_cards_grid.add_theme_constant_override("v_separation", 6)
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_child(_cards_grid)

	_right_box = VBoxContainer.new()
	_right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_theme_constant_override("separation", 6)
	parent.add_child(_right_box)

	_preview_box = VBoxContainer.new()
	_preview_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_child(_preview_box)

	# Р РµРґР°РєС‚РѕСЂ С‚СЏРЅРµС‚СЃСЏ РїРѕ РІРµСЂС‚РёРєР°Р»Рё, РёРЅР°С‡Рµ СЃС‚СЂР°РЅРёС†С‹ РЅРµ РґРѕР±РёСЂР°СЋС‚ РІС‹СЃРѕС‚Сѓ
	# С‚Р°Р±Р°: СЃС‡С‘С‚С‡РёРєРё EXPAND С„РѕСЂСЃРёСЂРѕРІР°Р»Рё С‚РѕР»СЊРєРѕ _page_wrap, Р° СЃР°Рј
	# _editor_panel РѕСЃС‚Р°РІР°Р»СЃСЏ СЃ С„Р»Р°РіРѕРј РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ.
	_editor_panel = VBoxContainer.new()
	_editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_child(_editor_panel)

	_build_editor()
	_refresh_preview()
```
РЈРґР°Р»РµРЅРѕ: `HSeparator` (Р±С‹РІС€Р°СЏ СЃС‚СЂРѕРєР° 436 вЂ” РјРµР¶РґСѓ СЂРµР№Р»РѕРј Рё РїСЂР°РІРѕР№ РєРѕР»РѕРЅРєРѕР№ СЂР°Р·РґРµР»РёС‚РµР»СЊ РЅРµ РЅСѓР¶РµРЅ; РІС‚РѕСЂР°СЏ РєРѕРїРёСЏ `HSeparator.new()` РІ РЅР°СЃС‚СЂРѕР№РєР°С… (2449) РЅРµ С‚СЂРѕРіР°РµРј, РїРѕСЌС‚РѕРјСѓ РІ GONE РµРіРѕ РЅРµ РґРѕР±Р°РІР»СЏРµРј).

**`_refresh_preview` вЂ” РЅРѕРІР°СЏ С„СѓРЅРєС†РёСЏ СЂСЏРґРѕРј СЃ `_refresh_all` (412):**
```gdscript
# РџСЂРµРІСЊСЋ РІС‹Р±СЂР°РЅРЅРѕРіРѕ СЃРµС‚Р° РІ РїСЂР°РІРѕР№ РєРѕР»РѕРЅРєРµ. РЎС…Р»РѕРїС‹РІР°РµС‚СЃСЏ РїСЂРё РѕС‚РєСЂС‹С‚РѕРј
# С‡РµСЂРЅРѕРІРёРєРµ: РїСЂР°РІР°СЏ РєРѕР»РѕРЅРєР° РїСЂРёРЅР°РґР»РµР¶РёС‚ СЂРµРґР°РєС‚РѕСЂСѓ. РЎРѕРґРµСЂР¶РёРјРѕРµ (СЃРѕСЃС‚Р°РІ,
# РєРЅРѕРїРєРё) РїРѕСЏРІРёС‚СЃСЏ РІ T3 - Р·РґРµСЃСЊ РєР°СЂРєР°СЃ Рё Р·Р°РіР»СѓС€РєР°.
func _refresh_preview() -> void:
	if _preview_box == null:
		return
	for child in _preview_box.get_children():
		_preview_box.remove_child(child)
		child.queue_free()
	_preview_box.visible = _draft == null
	if _draft != null:
		return
	var ph := Label.new()
	ph.text = Loc.txt("Select a set on the left")
	ph.add_theme_font_size_override("font_size", 11)
	ph.add_theme_color_override("font_color", Color("#666666"))
	_preview_box.add_child(ph)
```

**`_refresh_loadout_list` (1770-1775):** `columns = 3` в†’ `columns = 1` (СЂРµР№Р» СѓР·РєРёР№, РєР°СЂС‚РѕС‡РєРё-СЃС‚СЂРѕРєРё). Р’ РєРѕРЅРµС† С„СѓРЅРєС†РёРё (РїРѕСЃР»Рµ `_list_container.add_child(_make_create_btn())`, СЃС‚СЂРѕРєР° 1883) РґРѕР±Р°РІРёС‚СЊ `_refresh_preview()` вЂ” С…СѓРє, С‡РµСЂРµР· РєРѕС‚РѕСЂС‹Р№ T3 РїРѕР»СѓС‡РёС‚ РѕР±РЅРѕРІР»РµРЅРёРµ РїСЂРµРІСЊСЋ РѕС‚ delete/cycle/select.

**`_build_editor`, РєРѕРЅРµС† (РїРѕСЃР»Рµ 489 `_editor_panel.visible = _draft != null`):** РґРѕР±Р°РІРёС‚СЊ `_refresh_preview()` вЂ” СЃРєСЂС‹С‚РёРµ/РїРѕРєР°Р· РїСЂРµРІСЊСЋ РїСЂРё РІС…РѕРґРµ/РІС‹С…РѕРґРµ РёР· СЂРµРґР°РєС‚РѕСЂР° (`_start_new_draft`, `_edit_loadout`, `_cancel_draft` Р·РѕРІСѓС‚ `_build_editor`).

**`VTKLoc.gd`:** РІ `RU` РЅРѕРІР°СЏ Р·Р°РїРёСЃСЊ (РїРѕСЂСЏРґРѕРє РЅРµ РІР°Р¶РµРЅ, СЂСЏРґРѕРј СЃ РґСЂСѓРіРёРјРё РєР»СЋС‡Р°РјРё РїСЂРµРІСЊСЋ):
```gdscript
	'Select a set on the left': 'Р’С‹Р±РµСЂРёС‚Рµ СЃРµС‚ СЃР»РµРІР°',
```

### Interfaces

- **Produces:** `RAIL_WIDTH`, `_rail_box`, `_right_box`, `_preview_box`, `_refresh_preview()` (Р·Р°РіР»СѓС€РєР°), РєР»СЋС‡ `'Select a set on the left'`.
- **Consumes:** `_list_container`, `_cards_grid`, `_editor_panel`, `_build_editor` вЂ” РёРјРµРЅР° СЃРѕС…СЂР°РЅРµРЅС‹, РјРµРЅСЏРµС‚СЃСЏ С‚РѕР»СЊРєРѕ СЂРѕРґРёС‚РµР»СЊ.
- **Changes:** `_build_loadouts_tab` вЂ” РЅРѕРІС‹Р№ РєР°СЂРєР°СЃ; `_refresh_loadout_list` вЂ” 1 РєРѕР»РѕРЅРєР° + С…СѓРє `_refresh_preview()` РІ РєРѕРЅС†Рµ; `_build_editor` вЂ” С…СѓРє `_refresh_preview()` РІ РєРѕРЅС†Рµ; HSep РјРµР¶РґСѓ СЃРїРёСЃРєРѕРј Рё СЂРµРґР°РєС‚РѕСЂРѕРј СѓРґР°Р»С‘РЅ.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° Р·РµР»С‘РЅС‹Рµ. Р’ РёРіСЂРµ: СЃРїРёСЃРѕРє Рё В«+ РЎРѕР·РґР°С‚СЊ СЃРµС‚В» РІ Р»РµРІРѕРј СЂРµР№Р»Рµ, СЂРµРґР°РєС‚РѕСЂ СЃРїСЂР°РІР°, РїСЂРё РѕС‚СЃСѓС‚СЃС‚РІРёРё С‡РµСЂРЅРѕРІРёРєР° вЂ” Р·Р°РіР»СѓС€РєР° В«Р’С‹Р±РµСЂРёС‚Рµ СЃРµС‚ СЃР»РµРІР°В».

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "Split Sets tab into rail and preview-editor column"
```

---

## T3. РљР°СЂС‚РѕС‡РєРё СЂРµР№Р»Р°, РІС‹Р±РѕСЂ, РїСЂРµРІСЊСЋ РєРѕРЅС‚РµРЅС‚Р°, CreateCard

**Р¦РµР»СЊ:** РєР°СЂС‚РѕС‡РєР° СЂРµР№Р»Р° = РёРјСЏ + k-Р±РµР№РґР¶ + РјРµС‚Р° (РєРЅРѕРїРєРё Apply/Edit/вњ•/РєР»Р°РІРёС€Р° РїРµСЂРµРµР·Р¶Р°СЋС‚ РІ РїСЂРµРІСЊСЋ СЃРїСЂР°РІР°); РєР»РёРє РїРѕ РєР°СЂС‚РѕС‡РєРµ РІС‹РґРµР»СЏРµС‚ СЃРµС‚ Рё РїРѕРєР°Р·С‹РІР°РµС‚ РµРіРѕ СЃРѕСЃС‚Р°РІ; В«+ РЎРѕР·РґР°С‚СЊ СЃРµС‚В» вЂ” РїСѓРЅРєС‚РёСЂРЅР°СЏ РєР°СЂС‚РѕС‡РєР° `CreateCard` (С€С‚СЂРёС… СЂРёСЃСѓРµС‚ РЅРѕРІС‹Р№ `VTKSurface.draw_dashes`).

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

`layout_check.py`:
- РІ `GONE` РґРѕР±Р°РІРёС‚СЊ: `"_make_create_btn"`;
- РІ `PRESENT` РґРѕР±Р°РІРёС‚СЊ: `"_selected_set"`, `"_select_set"`, `"_fill_summary"`, `"CreateCard"`, `"draw_dashes"`.

### РљРѕРґ

**`VTKUI.gd`, var (РїРѕСЃР»Рµ `_editing_name`, СЃС‚СЂРѕРєР° 25):**
```gdscript
# РђРєС‚РёРІРЅР°СЏ РєР°СЂС‚РѕС‡РєР° СЂРµР№Р»Р°: РµС‘ СЃРѕСЃС‚Р°РІ РїРѕРєР°Р·С‹РІР°РµС‚ РїСЂРµРІСЊСЋ СЃРїСЂР°РІР°.
var _selected_set: String = ""
```

**Р’РЅСѓС‚СЂРµРЅРЅРёР№ РєР»Р°СЃСЃ `CreateCard` вЂ” РїРµСЂРµРґ `func _refresh_loadout_list` (1766):**
```gdscript
# РџСѓРЅРєС‚РёСЂРЅР°СЏ РєР°СЂС‚РѕС‡РєР° В«+ РЎРѕР·РґР°С‚СЊ СЃРµС‚В». StyleBoxFlat С€С‚СЂРёС…РѕРІ РЅРµ СѓРјРµРµС‚, Р°
# DashedBorder РЅР°С…РѕРґРёС‚СЃСЏ РІ GONE СЃС‚РµРЅРґР°, РїРѕСЌС‚РѕРјСѓ СЂР°РјРєР° СЂРёСЃСѓРµС‚СЃСЏ РІСЂСѓС‡РЅСѓСЋ.
# Loc РІРѕ РІРЅСѓС‚СЂРµРЅРЅРµРј РєР»Р°СЃСЃРµ РЅРµРґРѕСЃС‚СѓРїРµРЅ - С‚РµРєСЃС‚ РїСЂРёС…РѕРґРёС‚ Р°СЂРіСѓРјРµРЅС‚РѕРј.
class CreateCard extends Panel:
	const S := preload("res://mods/VTK/VTKSurface.gd")

	var _action: Callable

	func _init(action: Callable, label: String) -> void:
		_action = action
		custom_minimum_size = Vector2(0, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#141009")
		st.corner_radius_all = 4
		add_theme_stylebox_override("panel", st)
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 11)
		l.add_theme_color_override("font_color", Color("#8a7a6a"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		gui_input.connect(func(ev):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_action.call()
		)

	func _draw() -> void:
		S.draw_dashes(get_canvas_item(),
			Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#5f5347"))
```

**`_refresh_loadout_list` (1766-1890) вЂ” Р·Р°РјРµРЅРёС‚СЊ С†РµР»РёРєРѕРј:**
```gdscript
func _refresh_loadout_list() -> void:
	for child in _list_container.get_children():
		_list_container.remove_child(child)
		child.queue_free()
	_cards_grid = GridContainer.new()
	_cards_grid.columns = 1
	_cards_grid.add_theme_constant_override("h_separation", 6)
	_cards_grid.add_theme_constant_override("v_separation", 6)
	_cards_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.add_child(_cards_grid)

	var LD = preload("res://mods/VTK/VTKData.gd")
	var loadouts = LD.get_all()
	if loadouts.is_empty():
		var empty = Label.new()
		empty.text = Loc.txt("No saved loadouts")
		empty.add_theme_color_override("font_color", Color("#666"))
		_list_container.add_child(empty)
		var debug = Label.new()
		debug.text = Loc.txt("file: ") + str(OS.get_user_data_dir()) + "/MCM/vostok-toolkit/VTKsets.json"
		debug.add_theme_font_size_override("font_size", 8)
		debug.add_theme_color_override("font_color", Color("#444"))
		_list_container.add_child(debug)
		_list_container.add_child(CreateCard.new(_start_new_draft, Loc.txt("+ Create loadout")))
		_refresh_preview()
		return

	for ld in loadouts:
		if typeof(ld) != TYPE_DICTIONARY:
			continue
		var nm := str(ld.get("name", ""))
		var pack: Dictionary = LD.get_set(nm)
		var active := nm == _selected_set

		# РљР°СЂС‚РѕС‡РєР° С‚РѕР»СЊРєРѕ РІС‹Р±РёСЂР°РµС‚: Apply/Edit/РєР»Р°РІРёС€Р° Р¶РёРІСѓС‚ РІ РїСЂРµРІСЊСЋ СЃРїСЂР°РІР°,
		# РёРЅР°С‡Рµ РІ СЂРµР№Р»Рµ С€РёСЂРёРЅРѕР№ 236 С‡РµС‚С‹СЂРµ РєРЅРѕРїРєРё РЅРµ РїРѕРјРµС‰Р°СЋС‚СЃСЏ.
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.add_theme_stylebox_override("panel", VTKSurface.surface("normal", active, false, active, 12, 12, 11, 11))
		_attach_row_hover(card, func(hv: bool):
			return VTKSurface.surface("hover" if hv else "normal", active, false, active, 12, 12, 11, 11))
		_attach_motion(card)
		card.gui_input.connect(func(ev):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_select_set(nm)
		)

		var box = VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation", 4)
		card.add_child(box)

		var top = HBoxContainer.new()
		top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_lbl = Label.new()
		name_lbl.text = nm
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		top.add_child(name_lbl)
		var qk := int(ld.get("quick_key", 0))
		if qk > 0:
			var kb = Label.new()
			kb.text = _keycode_to_string(qk)
			kb.add_theme_font_size_override("font_size", 9)
			kb.add_theme_color_override("font_color", _gold)
			kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_child(kb)
		box.add_child(top)

		var eq_d: Dictionary = pack.get("equip", {})
		var gr_a: Array = pack.get("gear", [])
		var meta = Label.new()
		meta.text = str(eq_d.size() + gr_a.size()) + Loc.txt(" items В· ") + str(eq_d.size()) + Loc.txt(" in equipment")
		meta.add_theme_font_size_override("font_size", 10)
		meta.add_theme_color_override("font_color", Color("#666"))
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(meta)

		_cards_grid.add_child(card)

	_list_container.add_child(CreateCard.new(_start_new_draft, Loc.txt("+ Create loadout")))
	_refresh_preview()

func _select_set(nm: String) -> void:
	_selected_set = nm
	_refresh_loadout_list()
```
`_make_create_btn` (1885-1890) СѓРґР°Р»РёС‚СЊ. `mouse_filter = IGNORE` РЅР° `box`/`top` РѕР±СЏР·Р°С‚РµР»РµРЅ: РёРЅР°С‡Рµ РєРѕРЅС‚РµР№РЅРµСЂ СЃСЉРµРґР°РµС‚ РєР»РёРє, Рё `gui_input` РєР°СЂС‚РѕС‡РєРё РЅРµ СЃСЂР°Р±РѕС‚Р°РµС‚ (С‚РѕС‚ Р¶Рµ РїСЂРёС‘Рј, С‡С‚Рѕ РІ `_make_slot_row`/С€Р°РіРѕРІС‹С… РєР°СЂС‚РѕС‡РєР°С…).

**`_refresh_preview` вЂ” Р·Р°РјРµРЅРёС‚СЊ С‚РµР»Рѕ (С„СѓРЅРєС†РёСЏ РёР· T2) РЅР° РїРѕР»РЅРѕРµ:**
```gdscript
func _refresh_preview() -> void:
	if _preview_box == null:
		return
	for child in _preview_box.get_children():
		_preview_box.remove_child(child)
		child.queue_free()
	_preview_box.visible = _draft == null
	if _draft != null:
		return
	var LD = preload("res://mods/VTK/VTKData.gd")
	var pack: Dictionary = {}
	if _selected_set != "":
		pack = LD.get_set(_selected_set)
	if pack.is_empty():
		_selected_set = ""
		var ph := Label.new()
		ph.text = Loc.txt("Select a set on the left")
		ph.add_theme_font_size_override("font_size", 11)
		ph.add_theme_color_override("font_color", Color("#666666"))
		_preview_box.add_child(ph)
		return

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var nm := Label.new()
	nm.text = str(pack.get("name", _selected_set))
	nm.add_theme_font_size_override("font_size", 14)
	nm.add_theme_color_override("font_color", _gold)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nm)
	var qk := int(pack.get("quick_key", 0))
	if qk > 0:
		var kb := Label.new()
		kb.text = _keycode_to_string(qk)
		kb.add_theme_font_size_override("font_size", 10)
		kb.add_theme_color_override("font_color", _gold)
		kb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(kb)
	_preview_box.add_child(head)

	var eq_d: Dictionary = pack.get("equip", {})
	var gr_a: Array = pack.get("gear", [])
	var meta := Label.new()
	meta.text = str(eq_d.size() + gr_a.size()) + Loc.txt(" items В· ") + str(eq_d.size()) + Loc.txt(" in equipment")
	meta.add_theme_font_size_override("font_size", 10)
	meta.add_theme_color_override("font_color", Color("#666"))
	_preview_box.add_child(meta)

	# РљРЅРѕРїРєРё Р±С‹РІС€РµР№ РєР°СЂС‚РѕС‡РєРё - С‚РµРїРµСЂСЊ Р·РґРµСЃСЊ.
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 4)
	var apply_btn := Button.new()
	apply_btn.text = Loc.txt("Apply")
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	VTKSurface.style_button(apply_btn, true)
	apply_btn.pressed.connect(func(): LD.load_loadout(_selected_set))
	actions.add_child(apply_btn)
	var edit_btn := Button.new()
	edit_btn.text = Loc.txt("Edit")
	VTKSurface.style_button(edit_btn)
	edit_btn.pressed.connect(func(): _edit_loadout(_selected_set))
	actions.add_child(edit_btn)
	var qk_btn := Button.new()
	qk_btn.custom_minimum_size = Vector2(22, 20)
	qk_btn.add_theme_font_size_override("font_size", 9)
	if qk > 0:
		qk_btn.text = _keycode_to_string(qk)
		qk_btn.add_theme_color_override("font_color", _gold)
	else:
		qk_btn.text = "?"
		qk_btn.add_theme_color_override("font_color", Color("#444"))
	VTKSurface.style_button(qk_btn, qk > 0)
	qk_btn.pressed.connect(func(): _cycle_quick_key_789(_selected_set))
	actions.add_child(qk_btn)
	var del_btn := Button.new()
	del_btn.text = "вњ•"
	VTKSurface.style_button(del_btn, false, true)
	del_btn.pressed.connect(func(): _delete_loadout(_selected_set))
	actions.add_child(del_btn)
	_preview_box.add_child(actions)

	# РЎРѕСЃС‚Р°РІ - С‚РµРјРё Р¶Рµ СЃС‚СЂРѕРєР°РјРё, С‡С‚Рѕ СЃС‚СЂР°РЅРёС†Р° Done: РѕР±С‰РёР№ _fill_summary.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 8)
	var ec := VBoxContainer.new()
	ec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ec.add_theme_constant_override("separation", 1)
	var gc := VBoxContainer.new()
	gc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gc.add_theme_constant_override("separation", 1)
	cols.add_child(ec)
	cols.add_child(gc)
	_preview_box.add_child(cols)

	var d = Draft.new()
	d.load_from(pack)
	_fill_summary(d, ec, gc)
```
Lambda Р±РµСЂСѓС‚ `_selected_set` РІ РјРѕРјРµРЅС‚ РІС‹Р·РѕРІР° (СѓС‡Р°СЃС‚РѕРє РєР»Р°СЃСЃР°, РЅРµ Р·Р°С…РІР°С‚), РїРѕСЌС‚РѕРјСѓ РїРѕСЃР»Рµ СѓРґР°Р»РµРЅРёСЏ СЃРµС‚Р° РїСЂРµРІСЊСЋ СѓС…РѕРґРёС‚ РІ Р·Р°РіР»СѓС€РєСѓ С‡РµСЂРµР· С…СѓРє `_refresh_loadout_list в†’ _refresh_preview`.

**РР·РІР»РµС‡РµРЅРёРµ СЃРІРѕРґРєРё.** `_refresh_page_done` (1165-1200) СЃРѕРєСЂР°С‰Р°РµС‚СЃСЏ РґРѕ РѕС‡РёСЃС‚РєРё РєРѕР»РѕРЅРѕРє Рё РІС‹Р·РѕРІР° РЅРѕРІРѕРіРѕ РѕР±С‰РµРіРѕ С…РµР»РїРµСЂР°; `_fill_summary` вЂ” С‚РµР»Рѕ СЃС‚Р°СЂРѕР№ СЃРІРѕРґРєРё, `_draft` Р·Р°РјРµРЅС‘РЅ РЅР° Р°СЂРіСѓРјРµРЅС‚ `d`:
```gdscript
func _refresh_page_done() -> void:
	if _done_summary == null or _done_equip_col == null or _done_gear_col == null:
		return
	for col in [_done_equip_col, _done_gear_col]:
		for child in col.get_children():
			col.remove_child(child)
			child.queue_free()
	_fill_summary(_draft, _done_equip_col, _done_gear_col)

# РЎРІРѕРґРєР° СЃРѕСЃС‚Р°РІР° СЃРµС‚Р° РІ РґРІРµ РєРѕР»РѕРЅРєРё. РћР±С‰Р°СЏ РґР»СЏ СЃС‚СЂР°РЅРёС†С‹ Done Рё РїСЂРµРІСЊСЋ:
# РѕР±Рµ С‡РёС‚Р°СЋС‚ Draft, С‡С‚РѕР±С‹ РїРѕСЂСЏРґРѕРє СЃР»РѕС‚РѕРІ Рё С…РІРѕСЃС‚С‹ РѕР±РІРµСЃРѕРІ СЃРѕРІРїР°РґР°Р»Рё РІРµР·РґРµ.
func _fill_summary(d: Draft, equip_col: VBoxContainer, gear_col: VBoxContainer) -> void:
	if d == null:
		return
	equip_col.add_child(_summary_head(Loc.txt("Equipment")))
	gear_col.add_child(_summary_head(Loc.txt("Gear")))
	if d.item_count() == 0:
		equip_col.add_child(_summary_line(Loc.txt("Set is empty"), Color("#666666")))
		return
	var lists: Array = []
	for k in d.equip.keys():
		lists.append([str(k)])
	var any_eq := false
	for slot in Picker.all_slots(lists):
		var desc = d.equip.get(str(slot), {})
		if typeof(desc) != TYPE_DICTIONARY or desc.is_empty():
			continue
		any_eq = true
		equip_col.add_child(_summary_line(_equip_row_text(str(slot), desc)))
	for desc in d.gear:
		gear_col.add_child(_summary_line("В· " + str(desc.get("name", "?"))
			+ " x" + str(Draft.shown_count(desc)) + _gear_mag_tail(desc),
			Color("#a89a80")))
	if not any_eq:
		equip_col.add_child(_summary_line(Loc.txt("Empty"), Color("#666666")))
	if gear_col.get_child_count() <= 1:
		gear_col.add_child(_summary_line(Loc.txt("Empty"), Color("#666666")))
```
РљРѕРјРјРµРЅС‚Р°СЂРёР№-С€Р°РїРєСѓ 1162-1164 РїРµСЂРµРЅРµСЃС‚Рё РЅР° `_fill_summary`.

**`VTKSurface.gd` вЂ” РЅРѕРІР°СЏ СЃС‚Р°С‚РёС‡РµСЃРєР°СЏ С„СѓРЅРєС†РёСЏ (СЂСЏРґРѕРј СЃ `panel`):**
```gdscript
# РџСѓРЅРєС‚РёСЂРЅР°СЏ СЂР°РјРєР° РґР»СЏ РєР°СЂС‚РѕС‡РµРє Р±РµР· Р·Р°Р»РёРІРєРё. StyleBoxFlat С€С‚СЂРёС…РѕРІ РЅРµ СѓРјРµРµС‚,
# Р° DashedBorder РІ GONE СЃС‚РµРЅРґР° - СЂРёСЃСѓРµРј С€С‚СЂРёС…Р°РјРё С‡РµСЂРµР· CanvasItem. dash/gap
# РІ РїРёРєСЃРµР»СЏС…, width - С‚РѕР»С‰РёРЅР° Р»РёРЅРёРё.
static func draw_dashes(ci: CanvasItem, rect: Rect2, color: Color,
		dash: float = 4.0, gap: float = 4.0, width: float = 1.0) -> void:
	var x0 := rect.position.x + width * 0.5
	var y0 := rect.position.y + width * 0.5
	var x1 := rect.position.x + rect.size.x - width * 0.5
	var y1 := rect.position.y + rect.size.y - width * 0.5
	var x := x0
	while x < x1:
		var seg := minf(dash, x1 - x)
		ci.draw_line(Vector2(x, y0), Vector2(x + seg, y0), color, width)
		ci.draw_line(Vector2(x, y1), Vector2(x + seg, y1), color, width)
		x += dash + gap
	var y := y0
	while y < y1:
		var seg := minf(dash, y1 - y)
		ci.draw_line(Vector2(x0, y), Vector2(x0, y + seg), color, width)
		ci.draw_line(Vector2(x1, y), Vector2(x1, y + seg), color, width)
		y += dash + gap
```

### Interfaces

- **Produces:** `_selected_set`, `_select_set(nm)`, `_fill_summary(d, equip_col, gear_col)`, `CreateCard`, `VTKSurface.draw_dashes`.
- **Consumes:** `_start_new_draft`, `_edit_loadout`, `_delete_loadout`, `_cycle_quick_key_789`, `_keycode_to_string`, `VTKSurface.surface/style_button`, `_attach_row_hover/_attach_motion`, `_equip_row_text`/`_gear_mag_tail`/`_summary_head`/`_summary_line`, `Draft.load_from` (РїСЂРѕРІРµСЂРµРЅ `_edit_loadout`: `LD.get_set` в†’ `load_from` вЂ” С‚Р° Р¶Рµ С†РµРїРѕС‡РєР° РІ РїСЂРµРІСЊСЋ).
- **Changes:** `_refresh_loadout_list` вЂ” РЅРѕРІРѕРµ С‚РµР»Рѕ (РѕРґРЅР° РєРѕР»РѕРЅРєР°, РєР°СЂС‚РѕС‡РєР°-РІС‹Р±РѕСЂ, `CreateCard`, С…СѓРє РїСЂРµРІСЊСЋ); `_make_create_btn` СѓРґР°Р»С‘РЅ; `_refresh_preview` вЂ” РїРѕР»РЅС‹Р№ РєРѕРЅС‚РµРЅС‚; `_refresh_page_done` РґРµР»РµРіРёСЂСѓРµС‚ РІ `_fill_summary`.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° Р·РµР»С‘РЅС‹Рµ. Р’ РёРіСЂРµ: РєР»РёРє РїРѕ РєР°СЂС‚РѕС‡РєРµ вЂ” Р·РѕР»РѕС‚Р°СЏ СЂР°РјРєР° + РїСЂРµРІСЊСЋ СЃРїСЂР°РІР° (РёРјСЏ, РјРµС‚Р°, Apply/Edit/?/вњ•, СЃРІРѕРґРєР° РІ РґРІРµ РєРѕР»РѕРЅРєРё); В«+ РЎРѕР·РґР°С‚СЊ СЃРµС‚В» РїСѓРЅРєС‚РёСЂРѕРј; РїСѓСЃС‚РѕР№ СЃРїРёСЃРѕРє вЂ” Р·Р°РіР»СѓС€РєР° Рё РїСѓРЅРєС‚РёСЂРЅР°СЏ РєР°СЂС‚РѕС‡РєР°; Edit/Cancel вЂ” РїСЂРµРІСЊСЋ СЃРєСЂС‹С‚Рѕ, РїРѕСЃР»Рµ Cancel СЃРЅРѕРІР° РІРёРґРЅРѕ.

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKSurface.gd
git commit -m "Make rail cards select a set and show its preview"
```

---

## T4. Р¤РѕРєСѓСЃ в›¶

**Р¦РµР»СЊ:** РєРЅРѕРїРєР° РІ С€Р°РїРєРµ СЂРµРґР°РєС‚РѕСЂР° РїСЂСЏС‡РµС‚/РїРѕРєР°Р·С‹РІР°РµС‚ СЂРµР№Р» (СЂРµР¶РёРј РЅР° РІРµСЃСЊ СЌРєСЂР°РЅ). РЎРѕСЃС‚РѕСЏРЅРёРµ СЃРµСЃСЃРёРѕРЅРЅРѕРµ; РїСЂРё `_draft == null` СЂРµР№Р» РІРёРґРµРЅ РІСЃРµРіРґР°.

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

`layout_check.py`, РІ `PRESENT` РґРѕР±Р°РІРёС‚СЊ:
```python
    "_toggle_focus",
    "_apply_focus",
    "_focus_btn",
    "в›¶ Fullscreen",
```

### РљРѕРґ

**var (РїРѕСЃР»Рµ `_focus`-Р±Р»РёР·РєРёС… вЂ” СЂСЏРґРѕРј СЃ `_selected_set`):**
```gdscript
# Р¤РѕРєСѓСЃ-СЂРµР¶РёРј: СЂРµР№Р» СЃРµС‚РѕРІ СЃРїСЂСЏС‚Р°РЅ, СЂРµРґР°РєС‚РѕСЂ РІРѕ РІСЃСЋ С€РёСЂРёРЅСѓ. РЎРѕСЃС‚РѕСЏРЅРёРµ
# СЃРµСЃСЃРёРѕРЅРЅРѕРµ - РїРѕСЃР»Рµ РїРµСЂРµР·Р°РїСѓСЃРєР° РјРѕРґ РѕС‚РєСЂС‹РІР°РµС‚СЃСЏ СЃ СЂРµР№Р»РѕРј.
var _focus_mode: bool = false
var _focus_btn: Button = null
```

**`_build_editor`:** РІ null-СЃР±СЂРѕСЃ (466, СЂСЏРґРѕРј СЃ `_page_label = null`) РґРѕР±Р°РІРёС‚СЊ `_focus_btn = null`. Р—Р°РіРѕР»РѕРІРѕРє (468-475) Р·Р°РјРµРЅРёС‚СЊ РЅР° СЂСЏРґ:
```gdscript
	var title_row = HBoxContainer.new()
	title_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_theme_constant_override("separation", 4)
	var ed_title = Label.new()
	if _draft != null and _draft.set_name != "":
		ed_title.text = Loc.txt("Editing: ") + _draft.set_name
	else:
		ed_title.text = Loc.txt("Create new loadout")
	ed_title.add_theme_font_size_override("font_size", 12)
	ed_title.add_theme_color_override("font_color", _gold)
	ed_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(ed_title)
	_focus_btn = Button.new()
	_focus_btn.add_theme_font_size_override("font_size", 9)
	VTKSurface.style_button(_focus_btn, true)
	_focus_btn.pressed.connect(_toggle_focus)
	title_row.add_child(_focus_btn)
	_editor_panel.add_child(title_row)
```
Р’ РєРѕРЅРµС† `_build_editor` (РїРѕСЃР»Рµ `_refresh_preview()` РёР· T2) РґРѕР±Р°РІРёС‚СЊ:
```gdscript
	_update_focus_btn()
	_apply_focus()
```

**РќРѕРІС‹Рµ С„СѓРЅРєС†РёРё (СЂСЏРґРѕРј СЃ `_toggle_attachment_panel` РёР»Рё РїРѕСЃР»Рµ `_show_page`):**
```gdscript
# в›¶ РІ С€Р°РїРєРµ СЂРµРґР°РєС‚РѕСЂР°: СЂРµР№Р» СѓРµР·Р¶Р°РµС‚, РїСЂР°РІР°СЏ РєРѕР»РѕРЅРєР° Р·Р°РЅРёРјР°РµС‚ РІСЃСЋ С€РёСЂРёРЅСѓ.
func _toggle_focus() -> void:
	_focus_mode = not _focus_mode
	_update_focus_btn()
	_apply_focus()

func _update_focus_btn() -> void:
	if _focus_btn == null:
		return
	_focus_btn.text = Loc.txt("в—‚ Show sets") if _focus_mode else Loc.txt("в›¶ Fullscreen")
	_focus_btn.tooltip_text = _focus_btn.text

func _apply_focus() -> void:
	if _rail_box != null:
		_rail_box.visible = not _focus_mode
```

**`_show_page`, РІ РєРѕРЅРµС† (РїРѕСЃР»Рµ С†РёРєР»Р° 608-628):** `_apply_focus()` вЂ” СЃС‚СЂР°С…РѕРІРєР° РїСЂРё Р»СЋР±С‹С… РїРµСЂРµРєР»СЋС‡РµРЅРёСЏС… СЃС‚СЂР°РЅРёС†; РёРґРµРјРїРѕС‚РµРЅС‚РЅРѕ.

**`VTKLoc.gd`:**
```gdscript
	'в›¶ Fullscreen': 'в›¶ РќР° РІРµСЃСЊ СЌРєСЂР°РЅ',
	'в—‚ Show sets': 'в—‚ РџРѕРєР°Р·Р°С‚СЊ СЃРµС‚С‹',
```
РљР»СЋС‡Рё СЃРѕРґРµСЂР¶Р°С‚ РєР°РІС‹С‡РєРё? РќРµС‚, РЅРѕ СЃРёРјРІРѕР»С‹ в›¶/в—‚ вЂ” РѕР±С‹С‡РЅС‹Р№ Unicode, С„Р°Р№Р» UTF-8.

### Interfaces

- **Produces:** `_focus_mode`, `_focus_btn`, `_toggle_focus()`, `_update_focus_btn()`, `_apply_focus()`, РєР»СЋС‡Рё `'в›¶ Fullscreen'`, `'в—‚ Show sets'`.
- **Consumes:** `_rail_box` (T2), `_build_editor`, `_show_page`, `VTKSurface.style_button`.
- **Changes:** `_build_editor` вЂ” title-СЃС‚СЂРѕРєР° РІРјРµСЃС‚Рѕ РіРѕР»РѕРіРѕ Label + РІС‹Р·РѕРІС‹ РІ РєРѕРЅС†Рµ; `_show_page` вЂ” `_apply_focus()` РІ РєРѕРЅС†Рµ.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° Р·РµР»С‘РЅС‹Рµ. Р’ РёРіСЂРµ: в›¶ РїСЂСЏС‡РµС‚ СЂРµР№Р» (СЃРїРёСЃРѕРє Рё РїСЂРµРІСЊСЋ-Р·Р°РіР»СѓС€РєР°), РєРЅРѕРїРєР° РјРµРЅСЏРµС‚СЃСЏ РЅР° В«в—‚ Show setsВ», РїРѕРІС‚РѕСЂРЅС‹Р№ РєР»РёРє РІРѕР·РІСЂР°С‰Р°РµС‚; РѕС‚РєСЂС‹С‚РёРµ/Р·Р°РєСЂС‹С‚РёРµ СЂРµРґР°РєС‚РѕСЂР° СЃРѕС…СЂР°РЅСЏРµС‚ СЂРµР¶РёРј.

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "Add fullscreen focus toggle to the set editor"
```

---

## T5. РЁР°Рі 1: РіРѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅР°СЏ РїР°РЅРµР»СЊ С‡РёРїРѕРІ СЃР»РѕС‚РѕРІ

**Р¦РµР»СЊ:** Р»РµРІР°СЏ РєРѕР»РѕРЅРєР° СЃР»РѕС‚РѕРІ (`_page_columns` + `_side_slots_box` + СЃС‚СЂРѕРєРё) Р·Р°РјРµРЅСЏРµС‚СЃСЏ РїР°РЅРµР»СЊСЋ С‡РёРїРѕРІ С„РёРєСЃРёСЂРѕРІР°РЅРЅРѕР№ РІС‹СЃРѕС‚С‹ СЃРІРµСЂС…Сѓ СЃС‚СЂР°РЅРёС†С‹ (РјРѕРєР°Рї `.hslots`): С‡РёРї = С‚РѕС‡РєР° Р·Р°РЅСЏС‚РѕСЃС‚Рё + РёРјСЏ СЃР»РѕС‚Р° + вњ• (Сѓ Р·Р°РЅСЏС‚РѕРіРѕ), РєР»РёРє = С†РµР»СЊ (С‚РѕС‚ Р¶Рµ `_on_slot_row_input`), РїРѕРІС‚РѕСЂРЅС‹Р№ РєР»РёРє РїРѕ Р·Р°РЅСЏС‚РѕРјСѓ вЂ” РїР°РЅРµР»СЊ РѕР±РІРµСЃРѕРІ.

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

`layout_check.py`:
- РІ `GONE` РґРѕР±Р°РІРёС‚СЊ: `"_side_slots_box"`, `"_make_slot_row"`;
- РІ `PRESENT` СѓРґР°Р»РёС‚СЊ `"_make_slot_row"` Рё `"_side_slots_box"`, РґРѕР±Р°РІРёС‚СЊ:
```python
    "_slots_flow",
    "_make_slot_chip",
    "_make_mini_btn",
```
(`GONE_RE` `(?<!side_)\b_slots_box\b` РѕСЃС‚Р°С‘С‚СЃСЏ РєР°Рє СЃС‚СЂР°С…РѕРІРєР° РѕС‚ РїРµСЂРµРёРјРµРЅРѕРІР°РЅРёСЏ РѕР±СЂР°С‚РЅРѕ; `"SIDE_WIDTH := 232"` Рё `"_page_columns"` РІ PRESENT РѕСЃС‚Р°СЋС‚СЃСЏ вЂ” С€Р°Рі 2 С‡РµСЂРµР· `_page_columns` РїСЂРѕРґРѕР»Р¶Р°РµС‚ РїРѕР»СЊР·РѕРІР°С‚СЊСЃСЏ.)

### РљРѕРґ

**var (32-35):**
```gdscript
var _slots_flow: HFlowContainer = null
```
Р·Р°РјРµРЅСЏРµС‚ `var _side_slots_box: VBoxContainer = null`; `var _equip_box: HBoxContainer = null` (34) СѓРґР°Р»РёС‚СЊ вЂ” С„СѓРЅРєС†РёСЏ-РІР»Р°РґРµР»РµС† РёСЃС‡РµР·Р°РµС‚, С‡РёС‚Р°РµРјС‹С… СЃСЃС‹Р»РѕРє РЅР° `_equip_box` Р±РѕР»СЊС€Рµ РЅРµС‚ (РїСЂРѕРІРµСЂРµРЅРѕ grep'РѕРј: С‚РѕР»СЊРєРѕ decl/reset/assign/return). `_gear_box: HBoxContainer` (35) РѕСЃС‚Р°С‘С‚СЃСЏ.

**null-СЃР±СЂРѕСЃ РІ `_build_editor` (460, 464):** `_side_slots_box = null` в†’ `_slots_flow = null`; `_equip_box = null` СѓРґР°Р»РёС‚СЊ.

**`_build_page_equipment` (715-760) вЂ” Р·Р°РјРµРЅРёС‚СЊ С†РµР»РёРєРѕРј:**
```gdscript
func _build_page_equipment() -> Control:
	var v := _page_wrap()

	# Р§РёРїС‹ СЃР»РѕС‚РѕРІ - РїР°РЅРµР»СЊСЋ С„РёРєСЃРёСЂРѕРІР°РЅРЅРѕР№ РІС‹СЃРѕС‚С‹ СЃРІРµСЂС…Сѓ: С‡РµРј РЅРёР¶Рµ СЃРµС‚РєР°,
	# С‚РµРј РјРµРЅСЊС€Рµ РІРЅРёРјР°РЅРёСЏ СЃР»РѕС‚Р°Рј, Р° Р»РµРІР°СЏ РєРѕР»РѕРЅРєР° СЃСЉРµРґР°Р»Р° 232px Сѓ РїРѕР»РѕРє.
	# РџРѕСЂСЏРґРѕРє Рё С‡РёСЃР»Рѕ С‡РёРїРѕРІ РїРѕСЃС‚РѕСЏРЅРЅС‹ РѕС‚ СЃРµС‚Р° Рє СЃРµС‚Сѓ (all_slots СЃС‡РёС‚Р°РµС‚ РїРѕ
	# РєР°С‚Р°Р»РѕРіСѓ), РїРѕСЌС‚РѕРјСѓ РїР°РЅРµР»СЊ РЅРµ РїР»СЏС€РµС‚ РїРѕ РІС‹СЃРѕС‚Рµ.
	var slots_panel := PanelContainer.new()
	slots_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_panel.add_theme_stylebox_override("panel", VTKSurface.panel(true, 6))
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 4)
	slots_panel.add_child(sv)
	var slbl := Label.new()
	slbl.text = Loc.txt("Slots")
	slbl.add_theme_font_size_override("font_size", 9)
	slbl.add_theme_color_override("font_color", Color("#5f5347"))
	sv.add_child(slbl)
	_slots_flow = HFlowContainer.new()
	_slots_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slots_flow.add_theme_constant_override("h_separation", 5)
	_slots_flow.add_theme_constant_override("v_separation", 5)
	sv.add_child(_slots_flow)
	v.add_child(slots_panel)

	# РЁР°РїРєР° С†РµР»Рё: С„РёР»СЊС‚СЂС‹ РєР°С‚Р°Р»РѕРіР° РїРѕРґ РІС‹Р±СЂР°РЅРЅРѕР№ С†РµР»СЊСЋ.
	_target_bar = VBoxContainer.new()
	_target_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_bar.add_theme_constant_override("separation", 2)
	v.add_child(_target_bar)

	# РџРѕРёСЃРє Р¶РёРІС‘С‚ РЅР°Рґ СЃРµС‚РєРѕР№ Рё РѕР±РЅРѕРІР»СЏРµС‚ РµС‘ РЅР° Р»РµС‚Сѓ. text_changed, Р° РЅРµ
	# gui_input: Сѓ LineEdit gui_input РїСЂРё РїРѕС‚РµСЂРµ С„РѕРєСѓСЃР° Godot РѕР±СЂС‹РІР°РµС‚, Рё
	# РІС‚РѕСЂР°СЏ РІРєР»Р°РґРєР° СЃ РїРµСЂРІРѕРіРѕ СЂР°Р·Р° СЂРѕРЅСЏР»Р° Р±С‹ СЂРµРґР°РєС‚РѕСЂ.
	var search := LineEdit.new()
	search.placeholder_text = Loc.txt("Search items...")
	search.add_theme_color_override("font_color", Color("#ffffff"))
	search.add_theme_color_override("placeholder_color", Color("#666666"))
	search.add_theme_stylebox_override("normal", VTKSurface.panel(true, 10))
	search.add_theme_stylebox_override("focus", VTKSurface.focus_style())
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search.text_changed.connect(func(t): _set_search(t))
	v.add_child(search)

	var shelves_scroll := ScrollContainer.new()
	shelves_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shelves_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# РџРѕР», Р° РЅРµ РІС‹СЃРѕС‚Р°: EXPAND СЂР°СЃС‚СЏРіРёРІР°РµС‚ РѕР±Р»Р°СЃС‚СЊ РЅР° РІСЃС‘ СЃРІРѕР±РѕРґРЅРѕРµ РјРµСЃС‚Рѕ РѕРєРЅР°,
	# Р° РјРёРЅРёРјСѓРј РіР°СЂР°РЅС‚РёСЂСѓРµС‚, С‡С‚Рѕ РїРѕР»РєРё РѕСЃС‚Р°РЅСѓС‚СЃСЏ РІРёРґРёРјС‹РјРё РґР°Р¶Рµ С‚Р°Рј, РіРґРµ РІРЅРµС€РЅРёР№
	# РєРѕРЅС‚РµР№РЅРµСЂ РёРіСЂС‹ РѕС‚РґР°С‘С‚ СЂРѕРІРЅРѕ РјРёРЅРёРјР°Р»СЊРЅСѓСЋ РІС‹СЃРѕС‚Сѓ.
	shelves_scroll.custom_minimum_size = Vector2(0, 240)
	_shelves_box = VBoxContainer.new()
	_shelves_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shelves_box.add_theme_constant_override("separation", 6)
	shelves_scroll.add_child(_shelves_box)
	v.add_child(shelves_scroll)

	_equip_att_box = VBoxContainer.new()
	_equip_att_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_equip_att_box)
	return v
```
РЈРґР°Р»РµРЅРѕ: Р±Р»РѕРє `_side_slots_box` (755-757), `_equip_box = _page_columns(...)` (759), `return _equip_box` (760) в†’ `return v`. РџРѕСЂСЏРґРѕРє РґРµС‚РµР№: С‡РёРїС‹ в†’ С†РµР»СЊ в†’ РїРѕРёСЃРє в†’ РїРѕР»РєРё в†’ (РІСЃС‚СЂРѕРµРЅРЅС‹Р№ Р±Р»РѕРє РѕР±РІРµСЃРѕРІ РѕСЃС‚Р°С‘С‚СЃСЏ РґРѕ T7). РџСЂРѕРІРµСЂРєР° FUNCS `_build_page_equipment` (`shelves_scroll.size_flags_vertical` + `custom_minimum_size`) вЂ” СЃС‚СЂРѕРєРё РЅР° РјРµСЃС‚Рµ вњ“.

**`_refresh_slots` (1259-1280) вЂ” Р·Р°РјРµРЅРёС‚СЊ С†РµР»РёРєРѕРј:**
```gdscript
func _refresh_slots() -> void:
	if _slots_flow == null:
		return
	for child in _slots_flow.get_children():
		_slots_flow.remove_child(child)
		child.queue_free()
	if _draft == null:
		return
	# РџРѕСЂСЏРґРѕРє Р±РµСЂС‘Рј РёР· Picker.all_slots, С‡С‚РѕР±С‹ СЂСЏРґ Р±С‹Р» РѕРґРёРЅР°РєРѕРІС‹Рј РѕС‚ СЃРµС‚Р° Рє
	# СЃРµС‚Сѓ, Р° РЅРµ РІ РїРѕСЂСЏРґРєРµ РєР»СЋС‡РµР№ СЃР»РѕРІР°СЂСЏ. РЎР»РѕС‚С‹ РєРѕРїРёРј РёР· РІСЃРµС… РїСЂРµРґРјРµС‚РѕРІ
	# РєР°С‚Р°Р»РѕРіР°, Р° РЅРµ РёР· Р·Р°РЅСЏС‚С‹С… РІ СЌС‚РѕРј СЃРµС‚Рµ: РёРЅР°С‡Рµ РїСѓСЃС‚РѕР№ СЃР»РѕС‚ Р±С‹Р» Р±С‹ РІРёРґРµРЅ
	# С‚РѕР»СЊРєРѕ Сѓ С‚РѕРіРѕ СЃРµС‚Р°, РіРґРµ РµРіРѕ СѓР¶Рµ С‡С‚Рѕ-С‚Рѕ Р·Р°РЅРёРјР°РµС‚.
	var lists: Array = []
	for it in _db_items:
		if it != null:
			lists.append(it.get("slots"))
	for slot in Picker.all_slots(lists):
		var s := str(slot)
		var desc = _draft.equip.get(s, {})
		if typeof(desc) != TYPE_DICTIONARY:
			desc = {}
		_slots_flow.add_child(_make_slot_chip(s, desc))
```

**`_make_slot_row` (1285-1355) СѓРґР°Р»РёС‚СЊ, РІРјРµСЃС‚Рѕ РЅРµРіРѕ вЂ” `_make_slot_chip`:**
```gdscript
# Р§РёРї СЃР»РѕС‚Р°: С‚РѕС‡РєР° Р·Р°РЅСЏС‚РѕСЃС‚Рё, РёРјСЏ СЃР»РѕС‚Р°, СЃРЅСЏС‚РёРµ РїСЂРµРґРјРµС‚Р°. РџРѕРІС‚РѕСЂРЅС‹Р№ РєР»РёРє
# РїРѕ Р·Р°РЅСЏС‚РѕРјСѓ С‡РёРїСѓ РѕС‚РєСЂС‹РІР°РµС‚ РїР°РЅРµР»СЊ РѕР±РІРµСЃРѕРІ - РѕР±СЂР°Р±РѕС‚С‡РёРє С‚РѕС‚ Р¶Рµ, С‡С‚Рѕ Р±С‹Р»
# Сѓ СЃС‚СЂРѕРєРё: _on_slot_row_input.
func _make_slot_chip(slot: String, desc: Dictionary) -> Control:
	var occupied := not desc.is_empty()
	var active := _target_slot == slot
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.add_theme_stylebox_override("panel", _make_slot_style(active, false, not occupied))
	_attach_row_hover(chip, func(hv: bool): return _make_slot_style(active, hv, not occupied))
	_attach_motion(chip)
	chip.gui_input.connect(func(ev): _on_slot_row_input(ev, slot, desc))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(hb)
	hb.add_child(_make_dot(_gold if occupied else Color("#2a1f14")))

	var nm := Label.new()
	nm.text = Loc.txt(slot)
	nm.add_theme_font_size_override("font_size", 10)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.add_theme_color_override("font_color", Color("#d8cdbe") if occupied else Color("#4d443a"))
	if occupied:
		nm.tooltip_text = str(desc.get("name", "?"))
		var cnt := Draft.shown_count(desc)
		if cnt > 1:
			nm.tooltip_text += " x" + str(cnt)
	hb.add_child(nm)

	if occupied:
		var drop := _make_mini_btn("вњ•")
		drop.tooltip_text = Loc.txt("Remove")
		drop.pressed.connect(func(): _remove_slot(slot))
		hb.add_child(drop)
	return chip
```

**`_make_mini_btn` вЂ” РЅРѕРІР°СЏ С„СѓРЅРєС†РёСЏ (СЂСЏРґРѕРј СЃ `_make_step_btn`, 900):**
```gdscript
# РњРёРєСЂРѕ-РєРЅРѕРїРєР° 15Г—16: РєСЂРµСЃС‚РёРє С‡РёРїР° СЃР»РѕС‚Р° Рё СЂСЏРґС‹ СѓРїСЂР°РІР»РµРЅРёСЏ РєР»РµС‚РєРѕР№
# СЃРЅР°СЂСЏР¶РµРЅРёСЏ (T6). РћР±С‹С‡РЅС‹Р№ _make_step_btn (24Г—24) РІ 96px РєР»РµС‚РєРµ РЅРµ РІР»РµР·Р°РµС‚.
func _make_mini_btn(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(15, 16)
	b.add_theme_font_size_override("font_size", 8)
	VTKSurface.style_button(b, false, false, 1, 1, 2, 2)
	return b
```

**РљРѕРјРјРµРЅС‚Р°СЂРёРё:** `_on_slot_row_input` (1357-1359) вЂ” В«РІ СЃС‚СЂРѕРєРµ С€РёСЂРёРЅРѕР№ 232В» Р·Р°РјРµРЅРёС‚СЊ РЅР° В«РІ С‡РёРїРµВ»; РєРѕРјРјРµРЅС‚Р°СЂРёР№ `SIDE_WIDTH` (663-665) РїРµСЂРµРїРёСЃР°С‚СЊ: РєРѕР»РѕРЅРєР° РѕСЃС‚Р°Р»Р°СЃСЊ С‚РѕР»СЊРєРѕ Сѓ С€Р°РіР° 2, С€Р°Рі 1 РїРµСЂРµС€С‘Р» РЅР° С‡РёРїС‹.

### Interfaces

- **Produces:** `_slots_flow`, `_make_slot_chip(slot, desc)`, `_make_mini_btn(label)` (РїРѕС‚СЂРµР±СѓРµС‚СЃСЏ T6/T5).
- **Consumes:** `_on_slot_row_input`, `_make_slot_style`, `_make_dot`, `_remove_slot`, `Draft.shown_count`, `Picker.all_slots`, `VTKSurface.panel` вЂ” Р±РµР· РёР·РјРµРЅРµРЅРёР№.
- **Changes:** `_build_page_equipment` вЂ” РЅРѕРІРѕРµ С‚РµР»Рѕ (РєРѕР»РѕРЅРєР° СѓР±СЂР°РЅР°, С‡РёРїС‹ СЃРІРµСЂС…Сѓ); `_refresh_slots` вЂ” Р·Р°Р»РёРІР°РµС‚ `_slots_flow`; `_make_slot_row` СѓРґР°Р»РµРЅР°; `_equip_box` СѓРґР°Р»С‘РЅ РёР· var/null-СЃР±СЂРѕСЃР°.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° Р·РµР»С‘РЅС‹Рµ (FUNCS `_build_page_equipment` вЂ” Р·РµР»С‘РЅС‹Р№, `SIDE_WIDTH`/`_page_columns` РІ PRESENT вЂ” Р·РµР»С‘РЅС‹Рµ). Р’ РёРіСЂРµ: С‡РёРїС‹ РІ РѕРґРёРЅ-РґРІР° СЂСЏРґР° РЅР°Рґ РїРѕРёСЃРєРѕРј, Р·РѕР»РѕС‚Р°СЏ С‚РѕС‡РєР° Сѓ Р·Р°РЅСЏС‚С‹С…, вњ• СЃРЅРёРјР°РµС‚ РїСЂРµРґРјРµС‚, РєР»РёРє РІС‹Р±РёСЂР°РµС‚ С†РµР»СЊ, РІС‚РѕСЂРѕР№ РєР»РёРє РїРѕ Р·Р°РЅСЏС‚РѕРјСѓ вЂ” РїР°РЅРµР»СЊ РѕР±РІРµСЃРѕРІ, РїРѕР»РєРё СЃС‚Р°Р»Рё С€РёСЂРµ РЅР° 232px.

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "Move step 1 slots into a horizontal chip panel"
```

---

## T6. РЁР°Рі 2: РєР»РµС‚РєРё СЃ СѓРїСЂР°РІР»РµРЅРёРµРј, В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ», вљЎ

**Р¦РµР»СЊ:** С‡РёРїС‹ СЃРЅР°СЂСЏР¶РµРЅРёСЏ СЃРІРµСЂС…Сѓ СЃС‚СЂР°РЅРёС†С‹ РёСЃС‡РµР·Р°СЋС‚ вЂ” РІС‹Р±СЂР°РЅРЅРѕРµ РІРёРґРЅРѕ РЅР° РєР»РµС‚РєР°С… (Р·РѕР»РѕС‚Р°СЏ СЂР°РјРєР° + Г—N) Рё РІ СЃРІРѕРґРєРµ; РєР»РµС‚РєР° РїРѕР»СѓС‡Р°РµС‚ СЂСЏРґС‹ `Г—N + РћР±РІРµСЃС‹/mag` Рё `в€’ n + вљЎ вњ•` (РјРёРєСЂРѕ-РєРЅРѕРїРєРё); вљЎ СЃРїР°РІРЅРёС‚ РїСЂРµРґРјРµС‚ С‡РµСЂРµР· `VTKData.spawn_gear` (T1); РІ РєРѕР»РѕРЅРєРµ РєР°С‚РµРіРѕСЂРёР№ вЂ” РїСѓРЅРєС‚РёСЂРЅР°СЏ СЃС‚СЂРѕРєР°-РїРµСЂРµРєР»СЋС‡Р°С‚РµР»СЊ В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» (`ChosenRow`).

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

`layout_check.py`:
- РІ `GONE` РґРѕР±Р°РІРёС‚СЊ: `"_rebuild_gear_chips"`, `"_make_gear_chip"`, `"_gear_chips"`, `'"No gear"'`;
- РІ `PRESENT` РґРѕР±Р°РІРёС‚СЊ: `"_gear_only_selected"`, `"ChosenRow"`, `"_spawn_gear"`;
- РІ `FUNCS` РґРѕР±Р°РІРёС‚СЊ:
```python
    ("_rebuild_gear_grid", ["_gear_only_selected"],
     "С„РёР»СЊС‚СЂ В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» Р¶РёРІС‘С‚ РІ СЃРµС‚РєРµ РєР°С‚Р°Р»РѕРіР°"),
```

`VTKLoc.gd`: Р·Р°РїРёСЃСЊ `'No gear'` СѓРґР°Р»РёС‚СЊ (РєР»СЋС‡ Р±РѕР»СЊС€Рµ РЅРёРіРґРµ РЅРµ РІС‹Р·С‹РІР°РµС‚СЃСЏ).

### РљРѕРґ

**var:** РґРѕР±Р°РІРёС‚СЊ (СЂСЏРґРѕРј СЃ `_gear_facet_key`, 66):
```gdscript
# РџСѓРЅРєС‚РёСЂРЅР°СЏ СЃС‚СЂРѕРєР° В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» РІ РєРѕР»РѕРЅРєРµ РєР°С‚РµРіРѕСЂРёР№: РІ СЃРµС‚РєРµ
# РѕСЃС‚Р°СЋС‚СЃСЏ С‚РѕР»СЊРєРѕ РїСЂРµРґРјРµС‚С‹, СѓР¶Рµ Р»РµР¶Р°С‰РёРµ РІ СЃРµС‚Рµ.
var _gear_only_selected: bool = false
```
`_gear_chips` (65) СѓРґР°Р»РёС‚СЊ.

**`_reset_picker_state` (640-649):** РїРѕСЃР»Рµ `_gear_facet_key = ""` РґРѕР±Р°РІРёС‚СЊ `_gear_only_selected = false` (СЃР±СЂР°СЃС‹РІР°РµС‚СЃСЏ РІРјРµСЃС‚Рµ СЃ РѕСЃС‚Р°Р»СЊРЅС‹РјРё С„РёР»СЊС‚СЂР°РјРё РєР°С‚Р°Р»РѕРіР° РїСЂРё РєР°Р¶РґРѕРј РІС…РѕРґРµ РІ СЂРµРґР°РєС‚РѕСЂ).

**`_build_page_gear`:** СѓРґР°Р»РёС‚СЊ Р±Р»РѕРє С‡РёРїРѕРІ (765-770: РєРѕРјРјРµРЅС‚Р°СЂРёР№ + `_gear_chips = VBoxContainer... main.add_child(_gear_chips)`).

**`_refresh_page_gear` (815-818):** `_rebuild_gear_chips()` СѓРґР°Р»РёС‚СЊ; РґРѕ T7 РѕСЃС‚Р°С‘С‚СЃСЏ:
```gdscript
func _refresh_page_gear() -> void:
	_refresh_gear_catalog()
	_rebuild_att_box(_gear_att_box, _open_gear_att)
```

**РЈРґР°Р»РёС‚СЊ С†РµР»РёРєРѕРј:** `_rebuild_gear_chips` (820-839), `_make_gear_chip` (844-891) СЃ РєРѕРјРјРµРЅС‚Р°СЂРёРµРј (841-843), `_make_full_mag_btn` (917-932) вЂ” РµРіРѕ РІС‹Р·РѕРІ Р±С‹Р» С‚РѕР»СЊРєРѕ РІ С‡РёРїРµ, РІ РєР»РµС‚РєРµ (РЅРёР¶Рµ) РјР°РіР°Р·РёРЅ РїРѕР»СѓС‡Р°РµС‚ СЃРІРѕСЋ РєРЅРѕРїРєСѓ СЃ РєРѕРјРїР°РєС‚РЅС‹РјРё РїРѕР»СЏРјРё.

**`_rebuild_gear_facets` (952-968), РІ РєРѕРЅРµС† (РїРѕСЃР»Рµ С†РёРєР»Р° РїРѕ РїРѕРґРєР°С‚РµРіРѕСЂРёСЏРј):**
```gdscript
	# РџСѓРЅРєС‚РёСЂРЅР°СЏ СЃС‚СЂРѕРєР° В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» - РІ РєРѕРЅС†Рµ СЃРїРёСЃРєР° РєР°С‚РµРіРѕСЂРёР№.
	if _draft != null:
		_gear_facets_box.add_child(ChosenRow.new(_gear_only_selected,
			Loc.txt("Only selected"), func():
				_gear_only_selected = not _gear_only_selected
				_refresh_gear_catalog()))
```

**Р’РЅСѓС‚СЂРµРЅРЅРёР№ РєР»Р°СЃСЃ `ChosenRow` вЂ” РїРµСЂРµРґ `func _rebuild_gear_facets`:**
```gdscript
# РџСѓРЅРєС‚РёСЂРЅР°СЏ СЃС‚СЂРѕРєР° В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» РІ РєРѕР»РѕРЅРєРµ С„Р°СЃРµС‚РѕРІ. РљР°Рє CreateCard:
# С€С‚СЂРёС… СЂРёСЃСѓРµС‚СЃСЏ РІ _draw, Loc РїРµСЂРµРґР°С‘С‚СЃСЏ С‚РµРєСЃС‚РѕРј.
class ChosenRow extends PanelContainer:
	const S := preload("res://mods/VTK/VTKSurface.gd")

	var _on := false
	var _action: Callable

	func _init(on: bool, label: String, action: Callable) -> void:
		_on = on
		_action = action
		custom_minimum_size = Vector2(0, 26)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_STOP
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#1a1510")
		st.corner_radius_all = 4
		add_theme_stylebox_override("panel", st)
		var l := Label.new()
		l.text = ("вњ“ " if _on else "") + label
		l.add_theme_font_size_override("font_size", 10)
		l.add_theme_color_override("font_color", _gold_color() if _on else Color("#8a7a6a"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		gui_input.connect(func(ev):
			var mb := ev as InputEventMouseButton
			if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_action.call()
		)

	func _draw() -> void:
		S.draw_dashes(get_canvas_item(),
			Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("#5f5347"))

	static func _gold_color() -> Color:
		return Color("#e0b55a")
```
(Р’Рѕ РІРЅСѓС‚СЂРµРЅРЅРµРј РєР»Р°СЃСЃРµ РЅРµС‚ РґРѕСЃС‚СѓРїР° Рє `_gold` РІРЅРµС€РЅРµРіРѕ вЂ” РѕС‚СЃСЋРґР° Р»РѕРєР°Р»СЊРЅС‹Р№ С†РІРµС‚; РїСЂРё Р¶РµР»Р°РЅРёРё РєРѕРЅСЃС‚Р°РЅС‚Сѓ РјРѕР¶РЅРѕ РґСѓР±Р»РёСЂРѕРІР°С‚СЊ РєР°Рє `const GOLD := Color("#e0b55a")` РІРЅСѓС‚СЂРё РєР»Р°СЃСЃР° вЂ” РіР»Р°РІРЅРѕРµ РЅРµ Р·Р°РІРёСЃРµС‚СЊ РѕС‚ outer scope.)

**`_rebuild_gear_grid` (1067-1091):** РїРѕСЃР»Рµ С„РёР»СЊС‚СЂР° РїРѕ РїРѕРґРєР°С‚РµРіРѕСЂРёРё (1073-1079), РїРµСЂРµРґ `if found.is_empty()`:
```gdscript
	if _gear_only_selected and _draft != null:
		var picked: Array = []
		for e in found:
			var res_it = e.get("item")
			if res_it != null and _draft.has_path(str(res_it.resource_path)):
				picked.append(e)
		found = picked
```
Р РІС‹Р·РѕРІ РєР»РµС‚РєРё (1091): `_make_item_cell(res, "")` в†’ `_make_item_cell(res, "", true)`.

**`_make_item_cell` (1944-2025) вЂ” Р·Р°РјРµРЅРёС‚СЊ С†РµР»РёРєРѕРј:**
```gdscript
func _make_item_cell(item, forced_slot = null, gear := false) -> Control:
	var cell = Panel.new()
	# РљР»РµС‚РєР° СЃРЅР°СЂСЏР¶РµРЅРёСЏ РІС‹С€Рµ: РїРѕРґ РёРјРµРЅРµРј РґРІР° СЂСЏРґР° - СЃС‡С‘С‚С‡РёРє СЃ РѕР±РІРµСЃР°РјРё Рё
	# СѓРїСЂР°РІР»РµРЅРёРµ. РљР°С‚Р°Р»РѕРі С€Р°РіР° 1 РѕСЃС‚Р°С‘С‚СЃСЏ 132px.
	cell.custom_minimum_size = Vector2(96, 150 if gear else 132)
	# Р‘РµР· SIZE_EXPAND_FILL: HFlowContainer СЂР°СЃС‚СЏРіРёРІР°РµС‚ С‚Р°РєРёРµ РєР»РµС‚РєРё РЅР° РІСЃСЋ
	# С€РёСЂРёРЅСѓ РїРѕР»РѕСЃС‹, РїРѕРєР° РїСЂРµРґРјРµС‚РѕРІ РјР°Р»Рѕ (stretch РІ flow_container.cpp).
	cell.mouse_filter = Control.MOUSE_FILTER_STOP

	var normal_style := VTKSurface.surface("normal")
	var hover_style := VTKSurface.surface("hover")
	var in_set_style := VTKSurface.surface("normal", true, false, true)

	cell.add_theme_stylebox_override("panel", normal_style)
	_attach_motion(cell)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(center)
	# Panel - РЅРµ РєРѕРЅС‚РµР№РЅРµСЂ: Р±РµР· РїСЂРµСЃРµС‚Р° center РѕСЃС‚Р°С‘С‚СЃСЏ РЅСѓР»РµРІС‹Рј РїСЂСЏРјРѕСѓРіРѕР»СЊРЅРёРєРѕРј
	# РІ Р»РµРІРѕРј РІРµСЂС…РЅРµРј СѓРіР»Сѓ, Рё РёРєРѕРЅРєР° С†РµРЅС‚СЂРёСЂСѓРµС‚СЃСЏ РѕС‚РЅРѕСЃРёС‚РµР»СЊРЅРѕ СѓРіР»Р° РєР»РµС‚РєРё.
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	var tex = TextureRect.new()
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.custom_minimum_size = Vector2(84, 48)
	var icon := _item_icon(item)
	if icon:
		tex.texture = Picker.item_art(icon)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(tex)

	var name_lbl = Label.new()
	name_lbl.text = item.name
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color("#aaa"))
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.max_lines_visible = 2
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	var path_now: String = item.resource_path
	var already := _draft != null and _draft.has_path(path_now)
	if already and not gear:
		var cur_slot := _draft.equip_slot_of(path_now)
		if cur_slot == "":
			var n := int(_draft.amount_of(path_now))
			if n > 1:
				var cnt = Label.new()
				cnt.text = "Г—" + str(n)
				cnt.add_theme_font_size_override("font_size", 8)
				cnt.add_theme_color_override("font_color", _gold)
				cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(cnt)
		cell.add_theme_stylebox_override("panel", in_set_style)

	if gear and _draft != null:
		var gi := _draft.gear_index_of(path_now)
		if gi >= 0:
			cell.add_theme_stylebox_override("panel", in_set_style)
			var desc_g: Dictionary = _draft.gear[gi]
			var cnt_g := Draft.shown_count(desc_g)

			# Р СЏРґ Рђ: СЃС‡С‘С‚С‡РёРє Рё РѕР±РІРµСЃС‹. РЈ РѕР±РѕР№РјС‹ - С‚СѓРјР±Р»РµСЂ РїРѕР»РЅРѕР№ РѕР±РѕР№РјС‹,
			# Сѓ РѕСЃС‚Р°Р»СЊРЅС‹С… СЃ РїР°РЅРµР»СЊСЋ - РєРЅРѕРїРєР° rnd (РѕС‚РєСЂС‹РІР°РµС‚ РѕРІРµСЂР»РµР№, T7).
			var crow := HBoxContainer.new()
			crow.add_theme_constant_override("separation", 3)
			crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var xl := Label.new()
			xl.text = "Г—" + str(cnt_g)
			xl.add_theme_font_size_override("font_size", 8)
			xl.add_theme_color_override("font_color", _gold)
			xl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			xl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			xl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			crow.add_child(xl)
			if _is_magazine(path_now):
				var mag_btn := _make_full_mag_btn(path_now, desc_g, true)
				crow.add_child(mag_btn)
			elif Picker.has_panel(_item_info(path_now)):
				crow.add_child(_make_att_btn(desc_g))
			vbox.add_child(crow)

			# Р СЏРґ Р‘: РјРёРЅСѓСЃ, СЃС‡С‘С‚С‡РёРє, РїР»СЋСЃ, СЃРїР°РІРЅ, СѓРґР°Р»РµРЅРёРµ. Р’СЃРµ РјРёРєСЂРѕ-
			# РєРЅРѕРїРєРё 15Г—16, вљЎ Р·РѕР»РѕС‚С‹Рј - СЌС‚Рѕ РґРµР№СЃС‚РІРёРµ, Р° РЅРµ СЃРѕСЃС‚РѕСЏРЅРёРµ.
			var brow := HBoxContainer.new()
			brow.add_theme_constant_override("separation", 3)
			brow.alignment = BoxContainer.ALIGNMENT_CENTER
			brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var minus := _make_mini_btn("в€’")
			minus.pressed.connect(func(): _bump_gear(path_now, -1.0))
			brow.add_child(minus)
			var cl := Label.new()
			cl.text = str(cnt_g)
			cl.add_theme_font_size_override("font_size", 10)
			cl.custom_minimum_size = Vector2(16, 0)
			cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			brow.add_child(cl)
			var plus := _make_mini_btn("+")
			plus.pressed.connect(func(): _bump_gear(path_now, 1.0))
			brow.add_child(plus)
			var spawn := _make_mini_btn("вљЎ")
			spawn.tooltip_text = Loc.txt("Spawn into inventory")
			spawn.add_theme_color_override("font_color", _gold)
			spawn.pressed.connect(func(): _spawn_gear(path_now))
			brow.add_child(spawn)
			var drop := _make_mini_btn("вњ•")
			drop.tooltip_text = Loc.txt("Remove")
			drop.pressed.connect(func(): _remove_gear(path_now))
			brow.add_child(drop)
			vbox.add_child(brow)

	cell.tooltip_text = item.name

	var it = item
	# РЁР°Рі 2 Р·РѕРІС‘С‚ РєР»РµС‚РєСѓ СЃ РїСѓСЃС‚РѕР№ С†РµР»СЊСЋ СЏРІРЅРѕ, РёРЅР°С‡Рµ С†РµР»СЊ С€Р°РіР° 1 РїРµСЂРµРµС…Р°Р»Р° Р±С‹
	# РЅР° С€Р°Рі 2 РІРјРµСЃС‚Рµ СЃ РєР»РµС‚РєРѕР№. РљР»РёРє РїРѕ РїСѓСЃС‚РѕР№ gear-РєР»РµС‚РєРµ РґРѕР±Р°РІР»СЏРµС‚ РїСЂРµРґРјРµС‚
	# С‚РµРј Р¶Рµ _place_into (Draft.add).
	var slot := _target_slot if forced_slot == null else str(forced_slot)
	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_place_into(it, slot)
	)
	cell.mouse_entered.connect(func():
		var base_style := in_set_style if already else hover_style
		cell.add_theme_stylebox_override("panel", base_style)
	)
	cell.mouse_exited.connect(func():
		cell.add_theme_stylebox_override("panel", normal_style)
	)
	return cell
```
РљРЅРѕРїРєРё вЂ” `MOUSE_FILTER_STOP` (РїРѕ СѓРјРѕР»С‡Р°РЅРёСЋ), РїРѕСЌС‚РѕРјСѓ РєР»РёРє РїРѕ РЅРёРј РЅРµ РґРѕР»РµС‚Р°РµС‚ РґРѕ `gui_input` РєР»РµС‚РєРё.

**`_make_full_mag_btn` вЂ” РІРµСЂРЅСѓС‚СЊ СЃ РєРѕРјРїР°РєС‚РЅС‹Рј СЂРµР¶РёРјРѕРј (РІРјРµСЃС‚Рѕ СѓРґР°Р»РµРЅРёСЏ):**
```gdscript
# compact = true: РїРѕР»СЏ 2/2 РІРјРµСЃС‚Рѕ 8/8 Рё С€СЂРёС„С‚ 8 - РґР»СЏ СЂСЏРґРѕРІ РєР»РµС‚РєРё С€Р°РіР° 2,
# РіРґРµ РЅР° РІСЃСЋ С€РёСЂРёРЅСѓ 96px РїСЂРёС…РѕРґРёС‚СЃСЏ РµС‰С‘ Рё СЃС‡С‘С‚С‡РёРє.
func _make_full_mag_btn(path: String, desc: Dictionary, compact := false) -> Button:
	var on := Draft.is_full(desc)
	var b := Button.new()
	b.text = Loc.txt("Full magazine") if on else Loc.txt("Empty")
	b.add_theme_font_size_override("font_size", 8 if compact else 9)
	b.add_theme_color_override("font_color", _gold if on else Color("#777777"))
	if compact:
		VTKSurface.style_button(b, on, false, 2, 2, 2, 2)
	else:
		VTKSurface.style_button(b, on, false, 8, 8, 4, 4)
	b.pressed.connect(func():
		if _draft == null:
			return
		# РЎРѕСЃС‚РѕСЏРЅРёРµ Р±РµСЂС‘Рј СЃ Р°РєС‚СѓР°Р»СЊРЅРѕРіРѕ descriptor'Р°, Р° РЅРµ СЃ Р·Р°С…РІР°С‡РµРЅРЅРѕРіРѕ
		# desc: РїРѕСЃР»Рµ РїРµСЂРµСЃР±РѕСЂРєРё РєР»РµС‚РѕРє РѕРЅ СѓР¶Рµ РјРѕР¶РµС‚ Р±С‹С‚СЊ РЅРµ С‚РµРј РѕР±СЉРµРєС‚РѕРј.
		_draft.set_full_mag(path, not Draft.is_full(_draft.descriptor_of(path)))
		_refresh_pages()
	)
	return b
```

**`_spawn_gear` вЂ” РЅРѕРІР°СЏ С„СѓРЅРєС†РёСЏ (СЂСЏРґРѕРј СЃ `_bump_gear`, 1911):**
```gdscript
# вљЎ РІ РєР»РµС‚РєРµ: РІРµСЃСЊ РЅР°Р±РѕСЂ РїСЂРµРґРјРµС‚Р° (count РєРѕРїРёР№) РІ РёРЅРІРµРЅС‚Р°СЂСЊ, Р±РµР·
# СЌРєРёРїРёСЂРѕРІРєРё Рё Р±РµР· СЃРѕС…СЂР°РЅРµРЅРёСЏ - С‚Р°Рє РјРѕР¶РЅРѕ РїСЂРѕРІРµСЂРёС‚СЊ РїСЂРµРґРјРµС‚ РЅР° РјРµСЃС‚Рµ.
func _spawn_gear(path_now: String) -> void:
	if _draft == null:
		return
	var desc := _draft.descriptor_of(path_now)
	if desc.is_empty():
		return
	var LD = preload("res://mods/VTK/VTKData.gd")
	LD.spawn_gear(desc)
```

**`VTKLoc.gd`:** СѓРґР°Р»РёС‚СЊ `'No gear'`; РґРѕР±Р°РІРёС‚СЊ:
```gdscript
	'Only selected': 'РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹Рµ',
	'Spawn into inventory': 'Р’ РёРЅРІРµРЅС‚Р°СЂСЊ',
```

### Interfaces

- **Produces:** `_gear_only_selected`, `ChosenRow`, `_spawn_gear(path)`, РєР»РµС‚РєР°-СЂРµР¶РёРј `gear` (`_make_item_cell(item, forced_slot, gear)`), `_make_full_mag_btn(..., compact)`.
- **Consumes:** `VTKData.spawn_gear` (T1), `_make_mini_btn`/`_bump_gear`/`_remove_gear`/`_make_att_btn`/`_is_magazine`/`_item_info`, `Draft.gear_index_of`/`shown_count`, `_refresh_gear_catalog`, `Picker.has_panel`, `VTKSurface.draw_dashes` (T3, С‡РµСЂРµР· ChosenRow).
- **Changes:** `_build_page_gear` вЂ” Р±Р»РѕРє С‡РёРїРѕРІ СѓРґР°Р»С‘РЅ; `_refresh_page_gear` вЂ” Р±РµР· `_rebuild_gear_chips`; `_rebuild_gear_chips`/`_make_gear_chip` СѓРґР°Р»РµРЅС‹; `_make_item_cell` вЂ” РїР°СЂР°РјРµС‚СЂ `gear` + РґРІР° СЂСЏРґР° СѓРїСЂР°РІР»РµРЅРёСЏ; `_rebuild_gear_grid` вЂ” С„РёР»СЊС‚СЂ В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» Рё `gear=true`; `_make_full_mag_btn` вЂ” РїР°СЂР°РјРµС‚СЂ `compact`; `_reset_picker_state` вЂ” СЃР±СЂРѕСЃ С„РёР»СЊС‚СЂР°; var `_gear_chips` СѓРґР°Р»С‘РЅ.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° Р·РµР»С‘РЅС‹Рµ (РЅРѕРІР°СЏ Р·Р°РїРёСЃСЊ FUNCS `_rebuild_gear_grid` вЂ” Р·РµР»С‘РЅР°СЏ). Р’ РёРіСЂРµ: С‡РёРїРѕРІ РЅРµС‚; РІС‹Р±СЂР°РЅРЅР°СЏ РєР»РµС‚РєР° Р·РѕР»РѕС‚Р°СЏ, `Г—N`, СЂСЏРґ `в€’ n + вљЎ вњ•` СЂР°Р±РѕС‚Р°РµС‚ (в€’/+ РјРµРЅСЏСЋС‚ СЃС‡С‘С‚С‡РёРє, вњ• СѓР±РёСЂР°РµС‚, вљЎ РїРµС‡Р°С‚Р°РµС‚ В«Р—Р°СЃРїР°РІРЅРµРЅРѕ: вЂ¦ xNВ»); В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» С„РёР»СЊС‚СЂСѓРµС‚ СЃРµС‚РєСѓ; РїРѕРёСЃРє/С„Р°СЃРµС‚С‹ РЅРµ СЃР±СЂР°СЃС‹РІР°СЋС‚ С„РёР»СЊС‚СЂ.

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKUI.gd loadouts/mods/VTK/VTKLoc.gd
git commit -m "Replace gear chips with in-cell controls and only-selected filter"
```

---

## T7. РћРІРµСЂР»РµР№ РѕР±РІРµСЃРѕРІ

**Р¦РµР»СЊ:** РїР°РЅРµР»СЊ РѕР±РІРµСЃРѕРІ (Рё РјР°РіР°Р·РёРЅР°) РѕС‚РєСЂС‹РІР°РµС‚СЃСЏ РїРѕРІРµСЂС… РІСЃРµР№ РІРєР»Р°РґРєРё вЂ” `_att_overlay` РЅР° `_panel` СЃ Р·Р°С‚РµРјРЅРµРЅРёРµРј, РІРјРµСЃС‚Рѕ РІСЃС‚СЂРѕРµРЅРЅС‹С… `_equip_att_box`/`_gear_att_box`. РљР»РёРє РїРѕ Р·Р°С‚РµРјРЅРµРЅРёСЋ РёР»Рё вњ• Р·Р°РєСЂС‹РІР°РµС‚.

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

`layout_check.py`:
- РІ `GONE` РґРѕР±Р°РІРёС‚СЊ: `"_rebuild_att_box"`, `"_equip_att_box"`, `"_gear_att_box"`;
- РёР· `PRESENT` СѓРґР°Р»РёС‚СЊ `"_rebuild_att_box"`, `"_equip_att_box"`, `"_gear_att_box"`; РґРѕР±Р°РІРёС‚СЊ:
```python
    "_att_overlay",
    "_close_att_overlay",
    "_refresh_att_overlay",
```

### РљРѕРґ

**var (75-76 Р·Р°РјРµРЅРёС‚СЊ):**
```gdscript
# РћРІРµСЂР»РµР№ РѕР±РІРµСЃРѕРІ РїРѕРІРµСЂС… РІСЃРµР№ РІРєР»Р°РґРєРё: Рё РІ С„РѕРєСѓСЃ-СЂРµР¶РёРјРµ, Рё РїСЂРё СѓР·РєРѕРј РѕРєРЅРµ
# РїР°РЅРµР»СЊ РїРѕРґ РєР°С‚Р°Р»РѕРіРѕРј РІСЃС‘ СЂР°РІРЅРѕ Р±С‹Р»Р° Р±С‹ РЅРµ РІРёРґРЅР°. РўРµР»Рѕ - РїРѕРґР»РѕР¶РєР° РґР»СЏ
# РїР°РЅРµР»Рё РїСЂРµРґРјРµС‚Р°, С€Р°РїРєР° СЃ вњ• СЂРёСЃСѓРµС‚СЃСЏ РїСЂРё СЃР±РѕСЂРєРµ.
var _att_overlay: Control = null
var _att_overlay_body: VBoxContainer = null
```
`_equip_att_box`/`_gear_att_box` РёР· var СѓРґР°Р»РёС‚СЊ; РІ null-СЃР±СЂРѕСЃРµ `_build_editor` (462-463) РѕР±Рµ СЃС‚СЂРѕРєРё СѓРґР°Р»РёС‚СЊ. РљРѕРјРјРµРЅС‚Р°СЂРёР№ 36-39 (`_open_equip_att`/`_open_gear_att`) СѓР±СЂР°С‚СЊ/СЃРѕРєСЂР°С‚РёС‚СЊ РґРѕ В«РєР°РєРѕР№ РїР°РЅРµР»СЊСЋ Р·Р°РЅСЏС‚ РєР°Р¶РґС‹Р№ С€Р°РіВ» вЂ” СЃР°РјРё РїРµСЂРµРјРµРЅРЅС‹Рµ РѕСЃС‚Р°СЋС‚СЃСЏ.

**РЎР±РѕСЂРєР° РѕРІРµСЂР»РµСЏ вЂ” РІ `_build_loadouts_tab`, РїРѕСЃР»Рµ `_build_editor()`:**
```gdscript
	# РћРІРµСЂР»РµР№ Р¶РёРІС‘С‚ РЅР° _panel Рё РґРѕР±Р°РІР»СЏРµС‚СЃСЏ РїРѕСЃР»Рµ _scroll, С‡С‚РѕР±С‹ СЂРёСЃРѕРІР°С‚СЊСЃСЏ
	# РїРѕРІРµСЂС… РІРєР»Р°РґРєРё. Р­РєСЂР°РЅРЅС‹Рµ РєРѕРѕСЂРґРёРЅР°С‚С‹ Р·РµСЂРєР°Р»СЏС‚ _scroll (4,72)/(792,800).
	_att_overlay = Control.new()
	_att_overlay.position = Vector2(4, 72)
	_att_overlay.size = Vector2(792, 800)
	_att_overlay.visible = false
	_att_overlay.clip_contents = true
	var dim := Panel.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0, 0, 0, 0.55)
	dim.add_theme_stylebox_override("panel", ds)
	dim.gui_input.connect(func(ev):
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_close_att_overlay()
	)
	_att_overlay.add_child(dim)

	var card := PanelContainer.new()
	card.position = Vector2(56, 24)
	card.size = Vector2(680, 752)
	card.add_theme_stylebox_override("panel", VTKSurface.panel(false, 14))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	card.add_child(cv)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var title := Label.new()
	title.text = Loc.txt("Attachments")
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", _gold)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "вњ•"
	VTKSurface.style_button(close_btn, false, true)
	close_btn.pressed.connect(_close_att_overlay)
	head.add_child(close_btn)
	cv.add_child(head)

	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_att_overlay_body = VBoxContainer.new()
	_att_overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_att_overlay_body)
	cv.add_child(sc)
	_panel.add_child(_att_overlay)
```

**РќРѕРІС‹Рµ С„СѓРЅРєС†РёРё (СЂСЏРґРѕРј СЃ `_toggle_attachment_panel`):**
```gdscript
# РћРІРµСЂР»РµР№ СЂРµРЅРґРµСЂРёС‚ РїР°РЅРµР»СЊ С‚РµРєСѓС‰РµР№ СЃС‚СЂР°РЅРёС†С‹: РїСѓС‚СЊ СЃРІРѕСЏ Сѓ Р­РєРёРїРёСЂРѕРІРєРё Рё
# РЎРЅР°СЂСЏР¶РµРЅРёСЏ; РїСЂРё РїСѓСЃС‚РѕРј РїСѓС‚Рё РёР»Рё Р·Р°РєСЂС‹С‚РѕРј С‡РµСЂРЅРѕРІРёРєРµ - РїСЂСЏС‡РµС‚СЃСЏ.
func _refresh_att_overlay() -> void:
	if _att_overlay == null or _att_overlay_body == null:
		return
	for child in _att_overlay_body.get_children():
		_att_overlay_body.remove_child(child)
		child.queue_free()
	var path := _open_gear_att if _page == 1 else _open_equip_att
	if _draft == null or path == "":
		_att_overlay.visible = false
		return
	var panel := _build_att_panel(path)
	if panel == null:
		_att_overlay.visible = false
		return
	_att_overlay_body.add_child(panel)
	_att_overlay.visible = true

func _close_att_overlay() -> void:
	_open_equip_att = ""
	_open_gear_att = ""
	_refresh_draft_ui()
```
(`_refresh_draft_ui в†’ _refresh_pages в†’ _refresh_att_overlay` РїСЂСЏС‡РµС‚ РѕРІРµСЂР»РµР№ вЂ” РѕРґРёРЅ РёСЃС‚РѕС‡РЅРёРє РёСЃС‚РёРЅС‹.)

**РћР±РІСЏР·РєР°:**
- `_refresh_pages` (1248-1251): РґРѕР±Р°РІРёС‚СЊ `_refresh_att_overlay()` РїРѕСЃР»Рµ `_refresh_page_done()`;
- `_show_page`, РІ РєРѕРЅРµС†: `_refresh_att_overlay()` вЂ” РїСЂРё СЃРјРµРЅРµ С€Р°РіР° Р·Р°РєСЂС‹РІР°РµС‚СЃСЏ С‡СѓР¶Р°СЏ СЃС‚СЂР°РЅРёС†Р°;
- `_switch_tab` (394): РїСЂРё СѓС…РѕРґРµ СЃ РІРєР»Р°РґРєРё В«РЎРµС‚С‹В» вЂ” `if _att_overlay != null: _att_overlay.visible = false`; РїСЂРё РІС…РѕРґРµ РЅР° РЅРµС‘ вЂ” `_refresh_att_overlay()` (РІРµСЂРЅСѓС‚СЊ РѕС‚РєСЂС‹С‚СѓСЋ РїР°РЅРµР»СЊ РїРѕСЃР»Рµ РІРѕР·РІСЂР°С‚Р°). РЈСЃР»РѕРІРёРµ РїРѕ `name == Loc.txt("Sets")`.

**РЈРґР°Р»РёС‚СЊ:**
- `_rebuild_att_box` (2174-2184) Рё РѕР±Р° РІС‹Р·РѕРІР°: `_refresh_page_equipment` (1257), `_refresh_page_gear` (818);
- Р±Р»РѕРєРё `_equip_att_box = VBoxContainer.new()...` РІ `_build_page_equipment` (РїРѕСЃР»РµРґРЅРёРµ 3 СЃС‚СЂРѕРєРё РґРѕ `return v`) Рё `_gear_att_box = ...` РІ `_build_page_gear` (804-806);
- РєРѕРјРјРµРЅС‚Р°СЂРёР№ 2170-2173 РїСЂРѕ В«РїР°РЅРµР»СЊ РІ РїСЂР°РІРѕР№ РєРѕР»РѕРЅРєРµВ» (РІРјРµСЃС‚Рµ СЃ С„СѓРЅРєС†РёРµР№);
- РІ `_build_att_panel` (2188-2241) вЂ” Р±Р»РѕРє `head` (2209-2213, В«AttachmentsВ»): Р·Р°РіРѕР»РѕРІРѕРє С‚РµРїРµСЂСЊ РІ С€Р°РїРєРµ РѕРІРµСЂР»РµСЏ; `owner_lbl` (РёРјСЏ РїСЂРµРґРјРµС‚Р°) РѕСЃС‚Р°С‘С‚СЃСЏ.

**`_refresh_page_gear` РїРѕСЃР»Рµ T6+T7:**
```gdscript
func _refresh_page_gear() -> void:
	_refresh_gear_catalog()
```

### Interfaces

- **Produces:** `_att_overlay`, `_att_overlay_body`, `_refresh_att_overlay()`, `_close_att_overlay()`.
- **Consumes:** `_build_att_panel(path)` (РІРєР»СЋС‡Р°СЏ РјР°СЂС€СЂСѓС‚РёР·Р°С†РёСЋ `_is_magazine в†’ _build_mag_panel`), `_open_equip_att`/`_open_gear_att`, `_toggle_attachment_panel` (Р±РµР· РёР·РјРµРЅРµРЅРёР№ вЂ” РѕРЅ С‚РѕР»СЊРєРѕ РјРµРЅСЏРµС‚ РїСѓС‚СЊ), `_refresh_pages`/`_show_page`/`_switch_tab`, `_panel`, `_scroll` (РєРѕРѕСЂРґРёРЅР°С‚С‹), `VTKSurface.panel(false, 14)`.
- **Changes:** СѓР±СЂР°РЅС‹ `_equip_att_box`/`_gear_att_box` (var, null-СЃР±СЂРѕСЃ, СЃР±РѕСЂРєР°, РІС‹Р·РѕРІС‹) Рё `_rebuild_att_box`; `_build_att_panel` Р±РµР· СЃРѕР±СЃС‚РІРµРЅРЅРѕРіРѕ В«AttachmentsВ»-Р·Р°РіРѕР»РѕРІРєР°; `_refresh_pages`/`_show_page`/`_switch_tab` вЂ” С…СѓРєРё РѕРІРµСЂР»РµСЏ.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° Р·РµР»С‘РЅС‹Рµ. Р’ РёРіСЂРµ: rnd-РєРЅРѕРїРєР° РЅР° РєР»РµС‚РєРµ (С€Р°Рі 2), РїРѕРІС‚РѕСЂРЅС‹Р№ РєР»РёРє РїРѕ С‡РёРїСѓ (С€Р°Рі 1), Р°РІС‚Рѕ-РѕС‚РєСЂС‹С‚РёРµ РїРѕСЃР»Рµ СЂР°Р·РјРµС‰РµРЅРёСЏ (`_after_place`) вЂ” Р·Р°С‚РµРјРЅРµРЅРёРµ + РїР°РЅРµР»СЊ РїРѕ С†РµРЅС‚СЂСѓ; РєР»РёРє РјРёРјРѕ / вњ• / Esc-РїРµСЂРµРєР»СЋС‡РµРЅРёРµ С‚Р°Р±Р° вЂ” Р·Р°РєСЂС‹РІР°СЋС‚; РјР°РіР°Р·РёРЅ РѕС‚РєСЂС‹РІР°РµС‚СЃСЏ С‚СѓРґР° Р¶Рµ СЃ С‚СѓРјР±Р»РµСЂРѕРј; РІ С„РѕРєСѓСЃ-СЂРµР¶РёРјРµ РїР°РЅРµР»СЊ РІРёРґРЅР°.

### РљРѕРјРјРёС‚

```
git add loadouts/mods/VTK/VTKUI.gd
git commit -m "Move attachment panels into a fullscreen overlay"
```

---

## T8. Р РµР»РёР· 4.9.0

**Р¦РµР»СЊ:** РІРµСЂСЃРёСЏ, AGENTS.md, РїРѕР»РЅС‹Р№ РїСЂРѕРіРѕРЅ СЃС‚РµРЅРґРѕРІ, СЃР±РѕСЂРєР° Рё РґРѕСЃС‚Р°РІРєР°.

### Р”РµР№СЃС‚РІРёСЏ

1. **`loadouts/mod.txt`** (РѕРґРЅР° СЃС‚СЂРѕРєР°): `version="4.8.3"` в†’ `version="4.9.0"`.
2. **`AGENTS.md`** (РЅРµ РєРѕРјРјРёС‚РёС‚СЃСЏ):
   - РџСЂРѕРІРµСЂРєР° в†’ РїСѓРЅРєС‚ РїСЂРѕ С‚РµСЃС‚С‹: СЃРїРёСЃРѕРє РїРѕРїРѕР»РЅРёС‚СЊ `test_feed.gd`, `test_spawn.gd`;
   - РђРЅРЅРѕС‚Р°С†РёРё: В«`_equip_box` Рё `_gear_box` РѕР±СЉСЏРІР»РµРЅС‹ РєР°Рє `HBoxContainer`В» в†’ В«`_gear_box: HBoxContainer`; `_equip_box` СѓРґР°Р»С‘РЅ (С€Р°Рі 1 Р±РµР· РєРѕР»РѕРЅРѕРє), `_slots_flow: HFlowContainer`, `_done_summary` вЂ” `HBoxContainer`В»;
   - РџРµСЂРµСЃС‡РёС‚Р°С‚СЊ СЃС‡С‘С‚С‡РёРє `preload` РІ С‚Р°Р±Р»РёС†Рµ: `Select-String -SimpleMatch 'preload(' loadouts\mods\VTK\*.gd` (РѕР¶РёРґР°РЅРёРµ: Р±РµР· РёР·РјРµРЅРµРЅРёР№ вЂ” РЅРѕРІС‹С… С„Р°Р№Р»РѕРІ РјРѕРґР° РЅРµС‚);
   - Р”РѕР±Р°РІРёС‚СЊ РєРѕСЂРѕС‚РєСѓСЋ Р·Р°РјРµС‚РєСѓ: РїР°РЅРµР»СЊ РѕР±РІРµСЃРѕРІ вЂ” РѕРІРµСЂР»РµР№ `_att_overlay` РЅР° `_panel` (РєРѕРѕСЂРґРёРЅР°С‚С‹ Р·РµСЂРєР°Р»СЏС‚ `_scroll`), `_rebuild_att_box` СѓРґР°Р»С‘РЅ; СЃРїР°РІРЅ РѕРґРЅРѕРіРѕ РїСЂРµРґРјРµС‚Р° вЂ” `VTKData.spawn_gear`.
3. **РЎС‚РµРЅРґС‹ вЂ” РІСЃРµ С‡РµС‚С‹СЂРµ, РІРєР»СЋС‡Р°СЏ encoding:**
   ```
   py -3 .check\layout_check.py
   py -3 .check\keycheck.py
   powershell -NoProfile -ExecutionPolicy Bypass -File .check\check.ps1
   py -3 .check\encoding_check.py
   ```
4. **РРіСЂРѕРІРѕР№ РїСЂРѕРіРѕРЅ** (РѕР±СЏР·Р°С‚РµР»РµРЅ): РїРѕР»РЅС‹Р№ РѕР±С…РѕРґ РІСЃРµС… С‚СЂС‘С… С€Р°РіРѕРІ СЂРµРґР°РєС‚РѕСЂР°, С„РѕРєСѓСЃР°, РїСЂРµРІСЊСЋ, РѕРІРµСЂР»РµСЏ вЂ” РїРѕ СЃС†РµРЅР°СЂРёСЋ РёР· T3/T5/T7.
5. **РЎР±РѕСЂРєР° Рё РґРѕСЃС‚Р°РІРєР°:**
   ```
   powershell -ExecutionPolicy Bypass -File pack.ps1
   Copy-Item Loadouts.vmz "D:\SteamLibrary\steamapps\common\Road to Vostok\mods\Loadouts.vmz" -Force
   ```
6. **РљРѕРјРјРёС‚:**
   ```
   git add loadouts/mod.txt
   git commit -m "Bump mod version to 4.10.0"
   ```

### Interfaces

- **Produces:** РІРµСЂСЃРёСЏ 4.9.0 РІ `mod.txt` (MCM С‡РёС‚Р°РµС‚ РµС‘ РёР· С„Р°Р№Р»Р° РІ СЂР°РЅС‚Р°Р№РјРµ вЂ” РІ GDScript РЅРёС‡РµРіРѕ РЅРµ РґСѓР±Р»РёСЂСѓРµС‚СЃСЏ), Р°РєС‚СѓР°Р»СЊРЅС‹Р№ AGENTS.md.
- **Consumes:** РІСЃРµ РїСЂРµРґС‹РґСѓС‰РёРµ Р·Р°РґР°С‡Рё.
- **Changes:** С‚РѕР»СЊРєРѕ `loadouts/mod.txt` РїРѕРїР°РґР°РµС‚ РІ РєРѕРјРјРёС‚.

---

## T9. README: РѕСЃРІРµР¶РёС‚СЊ РІРѕР·РјРѕР¶РЅРѕСЃС‚Рё

**Р¦РµР»СЊ:** СѓР±СЂР°С‚СЊ РјРµР»РѕС‡СЊ (РІРµСЂСЃРёСЋ) РёР· README Рё РѕС‚СЂР°Р·РёС‚СЊ РёР·РјРµРЅРµРЅРёСЏ 4.9.0 РѕРґРЅРѕР№ СЃС‚СЂРѕРєРѕР№ РЅР° СЂР°Р·РґРµР» вЂ” Р±РµР· РІРЅСѓС‚СЂСЏРЅРєРё РІРєР»Р°РґРєРё.

**Р РµС€РµРЅРёСЏ СЋР·РµСЂР°:** РІРµСЂСЃРёСЋ РёР· README СѓР±СЂР°С‚СЊ СЃРѕРІСЃРµРј (РѕРЅР° Р¶РёРІС‘С‚ РІ `mod.txt` Рё Releases); РІРЅСѓС‚СЂРµРЅРЅСЏСЏ СЃС‚СЂСѓРєС‚СѓСЂР° H3 (СЂРµР№Р»/РїСЂРµРІСЊСЋ/С„РѕРєСѓСЃ) РІ README РЅРµ РѕРїРёСЃС‹РІР°РµС‚СЃСЏ вЂ” С‡РёС‚Р°С‚РµР»СЋ РІР°Р¶РµРЅ С„СѓРЅРєС†РёРѕРЅР°Р», РЅРµ СѓСЃС‚СЂРѕР№СЃС‚РІРѕ.

### РљСЂР°СЃРЅС‹Р№ С€Р°Рі

РќРµС‚ (README РЅРµ РєРѕРґ, СЃС‚РµРЅРґС‹ РЅРµ СѓС‡Р°СЃС‚РІСѓСЋС‚).

### РљРѕРґ

`README.md`:

1. **РЁР°РїРєР°** вЂ” СѓР±СЂР°С‚СЊ РІРµСЂСЃРёСЋ, РѕСЃС‚Р°РІРёС‚СЊ Р·Р°РіСЂСѓР·С‡РёРє Рё СЏР·С‹Рє:
```markdown
**Р—Р°РіСЂСѓР·С‡РёРє:** Metro Mod Loader 3.4.2 В· **РЇР·С‹Рє:** RU / EN
```
2. **РўР°Р±Р»РёС†Р° В«Р’РѕР·РјРѕР¶РЅРѕСЃС‚РёВ»** вЂ” РґРІРµ СЃС‚СЂРѕРєРё:
```markdown
| **РЎРµС‚С‹** | РЎРѕС…СЂР°РЅРёС‚СЊ СЃРµС‚ СЌРєРёРїРёСЂРѕРІРєРё/РёРЅРІРµРЅС‚Р°СЂСЏ, РїСЂРёРјРµРЅРёС‚СЊ РєР»Р°РІРёС€Р°РјРё **7 / 8 / 9**, СЃРїР°РІРЅРёС‚СЊ РїСЂРµРґРјРµС‚ РІ РёРЅРІРµРЅС‚Р°СЂСЊ Р±РµР· СЌРєРёРїРёСЂРѕРІРєРё |
| **РЎС‡С‘С‚С‡РёРє СѓР±РёР№СЃС‚РІ** | РЎС‡С‘С‚С‡РёРє РЅР° HUD + Kill Feed СЃ РёРєРѕРЅРєР°РјРё |
```
3. РћСЃС‚Р°Р»СЊРЅРѕРµ Р±РµР· РёР·РјРµРЅРµРЅРёР№ (СѓСЃС‚Р°РЅРѕРІРєР°, РёСЃРїРѕР»СЊР·РѕРІР°РЅРёРµ, СЃР±РѕСЂРєР°, СЃС‚СЂСѓРєС‚СѓСЂР°, СЃРѕРІРјРµСЃС‚РёРјРѕСЃС‚СЊ, Р»РёС†РµРЅР·РёСЏ).

### Interfaces

- **Produces:** README Р±РµР· РІРµСЂСЃРёРё, Р°РєС‚СѓР°Р»СЊРЅР°СЏ СЃС‚СЂРѕРєР° В«РЎРµС‚С‹В», Kill Feed РІ СЃС‚СЂРѕРєРµ СЃС‡С‘С‚С‡РёРєР°.
- **Consumes:** С„СѓРЅРєС†РёРѕРЅР°Р» 4.9.0 РёР· T1-T7.
- **Changes:** `README.md` С‚РѕР»СЊРєРѕ.

### РџСЂРѕРІРµСЂРєР°

РўСЂРё СЃС‚РµРЅРґР° РЅРµ РЅСѓР¶РЅС‹ (С„Р°Р№Р» РЅРµ РІ `loadouts/`). РџСЂРѕРІРµСЂРєР° вЂ” РІРёР·СѓР°Р»СЊРЅР°СЏ: Markdown СЂРµРЅРґРµСЂРёС‚СЃСЏ, С‚Р°Р±Р»РёС†Р° РёР· РґРІСѓС… РєРѕР»РѕРЅРѕРє С†РµР»Р°.

### РљРѕРјРјРёС‚

```
git add README.md
git commit -m "Refresh README features and drop version line"
```

---

## Self-review (РїРµСЂРµРґ РїРѕРєР°Р·РѕРј СЋР·РµСЂСѓ)

- [ ] РљР°Р¶РґР°СЏ Р·Р°РґР°С‡Р° РёРјРµРµС‚ РєСЂР°СЃРЅС‹Р№ С€Р°Рі (СЃРїРёСЃРєРё СЃС‚РµРЅРґР° РёР»Рё С‚РµСЃС‚), Р·РµР»С‘РЅС‹Р№ (РєРѕРґ) Рё СЂРѕРІРЅРѕ РѕРґРёРЅ РєРѕРјРјРёС‚ СЃ С„Р°Р№Р»Р°РјРё С‚РѕР»СЊРєРѕ РёР· `loadouts/**`.
- [ ] РќРµС‚ РїСЂРѕС‚РёРІРѕСЂРµС‡РёР№ СЃРѕ СЃРїРµРєРѕР№: РєРЅРѕРїРєРё Apply/Edit/вњ•/qk вЂ” РІ РїСЂРµРІСЊСЋ (В§3), СЂРµР№Р» 236px Р±РµР· РєРЅРѕРїРѕРє (В§3), С‡РёРїС‹ СЃР»РѕС‚РѕРІ РіРѕСЂРёР·РѕРЅС‚Р°Р»СЊРЅРѕ (В§2), G2-СЂСЏРґС‹ Рё В«РўРѕР»СЊРєРѕ РІС‹Р±СЂР°РЅРЅС‹РµВ» (В§6), РѕРІРµСЂР»РµР№ РѕР±РІРµСЃРѕРІ (В§5), в›¶ РІ С€Р°РїРєРµ СЂРµРґР°РєС‚РѕСЂР° (В§5, СЂРµС€РµРЅРёРµ РїРѕ СЂР°Р·РІРёР»РєРµ вЂ” РѕРґРЅР° РєРЅРѕРїРєР°), С„РѕРєСѓСЃ СЃРµСЃСЃРёРѕРЅРЅС‹Р№ (В§5).
- [ ] РћС‚РєР»РѕРЅС‘РЅРЅРѕРµ РёР· СЃРїРµРєРё РЅРµ РїРѕСЏРІР»СЏРµС‚СЃСЏ: В«в†ђ Рљ РїСЂРѕСЃРјРѕС‚СЂСѓВ», СЃР»РѕС‚-С†РµР»СЊ С€Р°РіР° 1, ESC-Р·Р°РєСЂС‹С‚РёРµ РѕРІРµСЂР»РµСЏ вЂ” РЅРµ РІ РїР»Р°РЅРµ.
- [ ] Р’СЃРµ РЅРѕРІС‹Рµ `Loc.txt`-РєР»СЋС‡Рё РёРјРµСЋС‚ RU-Р·Р°РїРёСЃРё РІ С‚РѕРј Р¶Рµ СЃРїРёСЃРєРµ Р·Р°РґР°С‡; СѓРґР°Р»С‘РЅ `'No gear'`.
- [ ] РЎРїРёСЃРєРё `layout_check.py` СЃРѕРіР»Р°СЃРѕРІР°РЅС‹: РЅРё РѕРґРёРЅ СЃРёРјРІРѕР» РЅРµ РѕРґРЅРѕРІСЂРµРјРµРЅРЅРѕ РІ GONE Рё PRESENT; `_page_columns`/`SIDE_WIDTH` РѕСЃС‚Р°Р»РёСЃСЊ (С€Р°Рі 2); `HSeparator` РЅРµ РІ GONE (РІС‚РѕСЂР°СЏ РєРѕРїРёСЏ РІ РЅР°СЃС‚СЂРѕР№РєР°С…).
- [ ] FUNCS РїРѕСЃР»Рµ РїСЂР°РІРѕРє: `_page_wrap`, `_page_columns`, `_build_page_equipment` (РїРѕР»РєРё), `_build_page_gear`, `_rebuild_gear_grid` (T6), `_build_ui` вЂ” РІСЃРµ С‚РµР»Р° СЃРѕРґРµСЂР¶Р°С‚ РЅСѓР¶РЅС‹Рµ СЃС‚СЂРѕРєРё.
- [ ] РўРёРїС‹: `_slots_flow: HFlowContainer`, `_att_overlay: Control`, `_focus_btn: Button`, `_rail_box/_right_box/_preview_box: VBoxContainer` вЂ” null-СЃР±СЂРѕСЃС‹ СЃРёРЅС…СЂРѕРЅРёР·РёСЂРѕРІР°РЅС‹ СЃ СѓРґР°Р»С‘РЅРЅС‹РјРё var.
- [ ] РџРѕСЂСЏРґРѕРє Р·Р°РґР°С‡ СѓРІР°Р¶Р°РµС‚ Р·Р°РІРёСЃРёРјРѕСЃС‚Рё: T1в†’T6 (spawn_gear), T5в†’T6 (_make_mini_btn), T6в†’T7 (РєР»РµС‚РєРё РґРѕ РѕРІРµСЂР»РµСЏ), T2в†’T3в†’T4 (СЂРµР№Р» в†’ РїСЂРµРІСЊСЋ в†’ С„РѕРєСѓСЃ).
- [ ] AGENTS.md РїСЂР°РІРёС‚СЃСЏ РІ T8, Р° РЅРµ СЂР°Р·РјР°Р·Р°РЅ РїРѕ Р·Р°РґР°С‡Р°Рј.
- [ ] T9: РІ README РЅРµС‚ РІРµСЂСЃРёРё, СЃС‚СЂРѕРєР° В«РЎРµС‚С‹В» СѓРїРѕРјРёРЅР°РµС‚ С‚РѕР»СЊРєРѕ СЃРїР°РІРЅ (РІРЅСѓС‚СЂСЏРЅРєР° H3 РЅРµ СЂР°СЃРєСЂС‹С‚Р°), Kill Feed РІ СЃС‚СЂРѕРєРµ СЃС‡С‘С‚С‡РёРєР°.
