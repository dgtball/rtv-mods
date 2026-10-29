# -*- coding: utf-8 -*-
r"""Проверка раскладки picker по всем модулям mods/vostok-toolkit/mods/VTK/*.gd.

Стенд .check ловит парсинг, макет - дизайн. Ни один из них не знает, что кнопка
"+ Добавить" не должна вернуться, а боковая колонка - должна. Здесь ровно эта
проверка: символы, которых быть не должно, и символы, которые должны быть.

Сканируются все модули VTK, а не только VTKUI.gd: после декомпозиции монолита
символы живут в разных файлах, и жёсткая привязка к одному файлу ослепила бы
стенд. GONE/GONE_RE проверяются по каждому модулю отдельно (вернувшийся символ -
провал в любом из них), PRESENT - хотя бы в одном, FUNCS - по телу функции в
том модуле, где она теперь определена.

Списки пополняются вместе с задачами плана: каждая задача добавляет свои.

Использование: python .check\layout_check.py
"""
import glob
import io
import os
import re
import sys

MODULES_GLOB = str(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "mods", "vostok-toolkit", "mods", "VTK", "*.gd"))

GONE = [
    "_make_target_chip",
    "_make_equip_block",
    "_gear_grid_open",
    "+ Add",
    "- Add",
    "_toggle_gear_picker",
    "_gear_picker",
    "_make_gear_shelf",
    "_gear_shelves",
    "_make_gear_block",
    '"[x] "',
    '"[ ] "',
    "_type_colors",
    "_cat_color",
    "func _make_att_toggle(",
    "_chrome_stat",
    "_set_stat",
    "_rail_tab",
    "_clock_label",
    "_clock_text",
    "_stat_msg",
    "_make_dot_texture",
    "mcm_ref",
    "mcm_box",
    "box_icon",
    "hintline",
    "Fine settings (noise, thermal palette, UI hotkey) live in MCM.",
    "All mod keys are registered there automatically.",
    "Toggle state is stored in ui_toggles.json and survives restarts.",
    "DashedBorder",
    "_make_dark_style",
    "Draft.slot_label",
    '"Target: "',
    "cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL",
    "_target_subcategories",
    "_open_att_path",
    "_dark_border",
    "_add_depth",
    "_make_create_btn",
    "parent.add_child(_rail_box)",
    "parent.add_child(_right_box)",
    "_cycle_quick_key_789",
    "_clear_draft",
    "clear_btn",
    "_equip_box",
    "_slots_flow",
    "_make_slot_chip",
    "_side_slots_box",
    "_make_slot_row",
    "_rebuild_gear_chips",
    "_make_gear_chip",
    "_gear_chips",
    '"No gear"',
    "_rebuild_att_box",
    "_equip_att_box",
    "_gear_att_box",
    "_toggle_focus",
    "_apply_focus",
    "_focus_btn",
    "_focus_mode",
    "⛶ Fullscreen",
    "Vector2(800, 880)",
    "Vector2(792, 30)",
    "Vector2(792, 800)",
    "⚡",
    "_summary_head",
    "_gear_mag_tail",
    "_fill_summary",
    "_make_weapon_cell",
    "_make_body_zone",
    "BodySilhouette",
    "EQ_CELL_H",
    "EQ_WEAP_H",
    "EQ_SMALL_H",
    # Фоновая сетка 1×1 удалена в 4.10.2: слоты рисуются прямоугольниками, а не
    # поверх ряда мелких ячеек. Цвет заливки фона - маркер возврата слоя.
    "#171410",
    # Телепорт 4.11.2: переключатель Карты/Убежища/Торговцы заменён на три равные
    # колонки-карточки. Эти символы - маркеры возврата переключателя.
    "_tp_switch",
    "_make_tp_section_row",
    "_make_tp_section_style",
    "_tp_section_btns",
    "_current_tp_section",
    "_tp_head",
    "_tp_count",
    # Стена инвентаря 4.12.1: чипы 1×1 без рамки. Рамка чипа - маркер возврата,
    # как и прежняя укладка по реальным размерам (_gear_cell_size, row_h).
    'VTKSurface.surface("normal"))',
    "row_h := 1",
    "_gear_cell_size",
    "grid 8 columns",
    # Превью 4.13: кнопка удаления в колонке Управление называется текстом
    # «Удалить», а не крестиком из старой карточки.
    'del_btn.text = "✕"',
    # Кнопки Сохранить/Отмена 4.13: в Done они пересоздаются в колонке
    # Управление, а не висят строкой под карточкой. Оба прежних блока
    # (превью и Done) удалены - строка `actions` возвращаться не должна.
    "var actions := HBoxContainer.new()",
    # 4.13.4: кнопка хоткея в колонке управления не мельче соседних
    'qk_btn.add_theme_font_size_override("font_size", 9)',
    # 4.13.4: подпись счётчика под карточкой Done удалена, имя и хоткей переехали
    # в колонку управления - их строки под карточкой и старые метки возвращать
    # нельзя.
    "_done_meta",
    'Loc.txt("Loadout")',
    'Loc.txt(" items")',
    'Loc.txt("Name:")',
    'Loc.txt("Hotkey:")',
    # 4.13.7: язык переехал в MCM, переключатель ушёл из вкладки - возвращать
    # его функции и ключи локали нельзя.
    "_make_lang_row",
    "_make_seg_btn_style",
    "_on_lang_button",
    "_lang_btns",
    'Loc.txt("Interface language")',
    'Loc.txt("Switch between English and Russian")',
    'Loc.txt("Interface")',
    # 4.13.7: вкладка «Настройки» удалена, её тумблер и json-хранилище тоже —
    # возврат любого из этих символов = откат плана.
    "_build_settings_tab",
    "_make_settings_header",
    "_make_toggle_row",
    "_kc_toggle",
    "_save_toggles",
    "_restore_toggles",
    "_save_mcm_bool",
    "TOGGLE_CFG",
    "ui_toggles.json",
    'Loc.txt("Settings")',
    "_kc_btn",
    "_kc_active",
    "_spawn_gear",
    "Spawn into inventory",
    "spawn_gear(",
]

GONE_RE = [
    (r"(?<!side_)\b_slots_box\b", "_slots_box без префикса side_"),
]

# Фолбек-панель смерти убрана в 4.8.3: панель с кнопками Restart / Main Menu /
# Quit, которая появлялась через 20 секунд ожидания ванильной "Load Game".
# Символы жили в VTKHooks.gd, вне VTKUI - поэтому список отдельный от GONE;
# с 4.17.12 оба сканируют все модули, но список оставлен ради явной группировки
# и счётчика HOOKS_GONE в отчёте.
HOOKS_GONE = [
    "_build_fallback_panel",
    "_on_menu_pressed",
    "_on_quit_pressed",
    "_death_restart_btn",
]

PRESENT = [
    "_page_columns",
    "class RefreshScope:",
    "func refresh(",
    "SIDE_WIDTH := 232",
    "_on_slot_row_input",
    "_make_dot",
    "_target_bar",
    "_make_facet_row",
    "_on_facet_input",
    "_set_gear_facet",
    "_refresh_gear_catalog",
    "_gear_facets_box",
    "_gear_grid",
    "gear_facet_key",
    "Picker.facets_of",
    "_done_preview",
    "_build_set_preview",
    "_make_grid_columns",
    "target_cat",
    "target_sub",
    "_reset_target_filters",
    "_make_filter_chip",
    "_target_filter_items",
    "Picker.subcategory_of",
    "gear_sub_key",
    "gear_subs_collapsed",
    "_gear_subfacets",
    "_set_gear_sub",
    "Picker.order_subcategories",
    "_make_att_cell",
    "attachment_resource",
    "has_attachment",
    "last_placed",
    "VTKSurface.surface",
    "VTKSurface.panel",
    "VTKSurface.style_button",
    "Picker.item_art",
    "_validate_target_filters",
    "_target_cats",
    "_target_subs",
    "open_equip_att",
    "open_gear_att",
    "kill_counter_enabled",
    "kill_feed_enabled",
    "04. KillFeed",
    "func _apply_hud(",
    "func _ensure_hud(",
    "VTKFeed.gd",
    "_rail_box",
    "_right_box",
    "_preview_box",
    "RAIL_WIDTH :=",
    "_refresh_preview",
    "_selected_set",
    "_select_set",
    "CreateCard",
    "draw_dashes",
    "_begin_bind",
    "_bind_target",
    "_pending_qk",
    "set_quick_key_unique",
    "_make_mini_btn",
    "_equip_grid_box",
    "_equip_cell_style",
    "_make_equip_cell",
    "_make_equip_grid",
    "_make_equip_preview",
    "Picker.equip_layout",
    "EQUIP_GRID",
    "EQ_COL_W := 447",
    "EQ_CELL := 70",
    "INVEN_CELL := 70",
    "_rotates_icon",
    "_apply_qk_btn",
    "_done_bind_btn",
    "Assign key",
    "gear_only_selected",
    "ChosenRow",
    "_att_overlay",
    "_close_att_overlay",
    "_refresh_att_overlay",
    "_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
    "_make_inventory_wall",
    "_equip_styles",
    "_inven_bg_style",
    "_make_inventory_panel",
    "INVEN_COLS",
    "INVEN_ROWS",
    "_make_tp_column",
    "var rail := HBoxContainer.new()",
    "_make_control_column",
    'Loc.txt("Delete")',
    "28 if level else 31",
    "rail_sep",
    "Dropdown",
    '"language"',
]

# Проверки внутри тела функции. Простое вхождение строки тут не годится:
# "size_flags_vertical = Control.SIZE_EXPAND_FILL" встречается в файле
# десяток раз и само по себе ничего не гарантирует. Схлопывание полок в
# ноль как раз и вышло из того, что флаг стоял не везде, где нужен, поэтому
# проверять надо конкретную функцию.
# С 4.8.4 клетка снаряжения: под именем три ряда (счётчик с обвесами, крупные
# «− n +», кнопка «В инвентарь»), ✕ — красный в правом верхнем углу. Стенд
# держит кнопку спавна и угол через FUNCS по телу _make_item_cell, а откат
# иконки-спавна ловит GONE «⚡».
FUNCS = [
    ("_page_wrap", ["size_flags_vertical = Control.SIZE_EXPAND_FILL"],
     "обёртка страницы обязана тянуться по вертикали"),
    ("_page_columns", [
        "size_flags_vertical = Control.SIZE_EXPAND_FILL",
        "mv.size_flags_vertical = Control.SIZE_EXPAND_FILL",
    ], "колонки страницы обязаны тянуться по вертикали"),
    ("_build_page_equipment", [
        "shelves_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL",
        "shelves_scroll.custom_minimum_size",
    ], "у полок с предметами есть и растягивание, и пол по высоте"),
    ("_build_page_gear", [
        "_gear_grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL",
    ], "каталог снаряжения тянется по вертикали"),
    ("_rebuild_gear_grid", ["gear_only_selected"],
     "фильтр «Только выбранные» живёт в сетке каталога"),
    ("_items_for_target", ["Picker.category_allowed"],
     "слоты оружия получают отфильтрованный список"),
    ("_build_ui", [
        "_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL",
        "vb.size_flags_vertical = Control.SIZE_EXPAND_FILL",
    ], "цепочка табов обязана тянуться от скролла до таба"),
    ("_build_teleport_tab", [
        "_make_tp_column",
        "Control.SIZE_EXPAND_FILL",
    ], "телепорт: три равные колонки-карточки"),
    ("_make_tp_column", [
        "Control.SIZE_EXPAND_FILL",
    ], "колонки телепорта делят ширину поровну"),
    ("_set_search", ["_search_debounce.start()"],
     "живой поиск дебаунсится перед пересборкой"),
    ("_apply_search", ["_validate_target_filters()"],
     "применение поиска валидирует фильтры до пересборки сетки"),
    ("_build_loadouts_tab", [
        "row.add_child(rail_panel)",
        "rail_panel.add_child(_rail_box)",
        "row.add_child(_right_box)",
    ], "рейл (в подложке) и правая колонка лежат в HBox-ряду, а не в вертикальном табе"),
    ("_make_item_cell", [
        "PRESET_TOP_RIGHT",
    ], "✕ в правом верхнем углу клетки снаряжения"),
    ("_make_equip_preview", ["MarginContainer", "EQ_COL_W"],
     "превью экипировки: сетка в отступе 6px, колонка EQ_COL_W"),
    ("_make_equip_cell", [
        "_on_slot_row_input",
        "Picker.item_art",
        "_rotates_icon",
    ], "клетка сетки кликабельна, показывает иконку и крутит стволы дулом вверх"),
    ("_build_set_preview", [
        "_make_equip_preview(eq)",
        "_make_inventory_panel(gear)",
        "if fill else Control.SIZE_SHRINK_BEGIN",
    ], "превью: три колонки экипировка|инвентарь|управление, Done по содержимому"),
    ("_refresh_slots", [
        "_make_equip_grid",
    ], "укладка берётся из кэша _build_equip_layout и строится _make_equip_grid"),
    ("_build_equip_layout", [
        "Picker.equip_layout",
        "Picker.all_slots",
    ], "чистая раскладка Picker считается один раз в кэш"),
    ("_make_inventory_wall", [
        "INVEN_ROWS",
        "Control.SIZE_SHRINK_BEGIN",
    ], "стена: всегда 8+ рядов, квадратная, не тянется"),
    ("_wall_item", [
        "_art_texture_rect",
    ], "чип инвентаря рисует иконку через общий билдер"),
    ("_art_texture_rect", [
        "Picker.item_art",
    ], "общий TextureRect клеток: кроп иконки через Picker"),
    ("_refresh_preview", [
        "_make_control_column(Loc.txt(\"Controls\")",
        "Loc.txt(\"Delete\")",
        "head_sep",
    ], "превью: кнопки в колонке Управление, удаление текстом, разделитель шапки"),
    ("_build_page_done", [
        "_build_set_preview({}, [], false,",
        "_name_input",
    ], "Done: каркас трёх колонок, имя и хоткей — в колонке управления"),
    ("_entry", ['"name":', 'it.get("name"'],
     "запись каталога несёт name — шаг 2 фильтрует поиск по нему"),
]


def esc(s):
    return s.encode("ascii", "backslashreplace").decode("ascii")


def modules():
    """Тексты модулей VTK: [(имя файла, текст), ...]."""
    out = []
    for path in sorted(glob.glob(MODULES_GLOB)):
        out.append((os.path.basename(path),
                    io.open(path, encoding="utf-8").read()))
    return out


def func_bodies(mods, name):
    """Все тела функции name: [(имя файла, тело), ...].

    Больше одного файла - уже пахнет копией, оставшейся в монолите после выноса.
    """
    pat = re.compile(r"^func %s\(.*?^(?=^func |\Z)" % re.escape(name),
                     re.S | re.M)
    out = []
    for fname, src in mods:
        m = pat.search(src)
        if m:
            out.append((fname, m.group(0)))
    return out


def main():
    mods = modules()
    bad = 0
    for s in GONE:
        hits = [f for f, src in mods if s in src]
        if hits:
            bad += 1
            print("  GONE    %-34s встречается в %s"
                  % (esc(s), ", ".join(hits)))
    for pattern, what in GONE_RE:
        hits = [f for f, src in mods if re.search(pattern, src)]
        if hits:
            bad += 1
            print("  GONE-RE %-34s встречается в %s"
                  % (esc(what), ", ".join(hits)))
    for s in PRESENT:
        if not any(s in src for _, src in mods):
            bad += 1
            print("  MISS    %-34s не найдено" % esc(s))
    for name, needed, what in FUNCS:
        bodies = func_bodies(mods, name)
        if not bodies:
            bad += 1
            print("  NOFUNC  %-34s функция не найдена" % esc(name))
            continue
        if len(bodies) > 1:
            bad += 1
            print("  DUP     %-34s определена в %s"
                  % (esc(name), ", ".join(f for f, _ in bodies)))
        for s in needed:
            if not any(s in body for _, body in bodies):
                bad += 1
                print("  FUNC    %-34s нет %s (%s)"
                      % (esc(name), esc(s), esc(what)))
    for s in HOOKS_GONE:
        hits = [f for f, src in mods if s in src]
        if hits:
            bad += 1
            print("  HOOKS-GONE %-31s встречается в %s"
                  % (esc(s), ", ".join(hits)))

    print("GONE: %d, GONE_RE: %d, PRESENT: %d, FUNCS: %d, HOOKS_GONE: %d"
          % (len(GONE), len(GONE_RE), len(PRESENT), len(FUNCS), len(HOOKS_GONE)))
    if bad:
        print("RESULT: раскладка разошлась с планом: %d" % bad)
        sys.exit(1)
    print("RESULT: символы раскладки на месте")


main()
