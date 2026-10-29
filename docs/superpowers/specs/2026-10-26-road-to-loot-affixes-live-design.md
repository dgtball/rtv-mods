# Road To Loot 0.3.0 — аффиксы как живые статы (спека)

Дата: 2026-10-26 · ред. 2 · Мод: Road To Loot (`RTL`, отдельный самодостаточный) · База: 0.2.25
Статус: утверждена — §17 закрыт, план работ — `writing-plans` на срез 0.3.0 (T1–T4, T7–T8).

Ред. 1 лежит в `%TEMP%\opencode\rtl-spec-r1.md`. Всё, что ниже, проверено по ванильному
коду из `%APPDATA%\Road to Vostok\modloader_hooks\vanilla\Scripts\`, по `modloader.gd`
и по Evolve; ссылки `file:line` — на эти копии.

## 0. Журнал ред. 2

| # | Было в ред. 1 | Стало в ред. 2 | Почему |
|---|---|---|---|
| 1 | `max_hp` через replace `character-clamp`, «8 клампов» | аффикс снят (D5 отозвано) | replace-слот забирает Evolve, а ваниль клампит **10** полей, не 8 |
| 2 | §9 перечислял хуки без арностей, часть с «non-void?» | §12: таблица арностей по каждому колбэку | несовпадение арности — молчаливый no-op, не падение |
| 3 | плитка «носит свой ролл через `nested`» | ролл плитки живёт на `SlotData` рига, ключ — индекс `nested` | `nested` — `Array[ItemData]`, SlotData плитки выбрасывается при `Combine` |
| 4 | FIFO `_pending_rolls` по кадрам | синхронная передача по `itemData.get_instance_id()` | `Remove` уже отдаёт `nestedIndex` и `_result`, `Create()` идёт в том же стеке |
| 5 | три пути переноса | пять (`Combine`, `CombineSwap`, `Remove/ContextRemove`, `Storage`, `Initialize/Display`) | `CombineSwap` (Interface.gd:2009) в спеке отсутствовал |
| 6 | ключи сайдкара `kind\|file\|n` | `uid` в мете `SlotData`, сайдкар по `uid` | позиционные ключи перекидывают ролл между одинаковыми предметами |
| 7 | «мета не сериализуется» (подразумевалось) | мета сериализуется (проверено), в сейв идёт **только** `rtl_uid` | `ResourceSaver`/`ResourceLoader` вернули `metadata/*` без потерь |
| 8 | `protection` гейтился по `itemData.protection > 0` | гейт по типу (`Helmet`/`Armor`) | у рига `protection` не читает никто |
| 9 | износ восстанавливался дробью `delta*x/(1+x)`, «3 знака» | износ **отменяется целиком** с вероятностью `x` | в ванили `condition` всегда целое, тултип печатает `int()` |
| 10 | `noise`: «на `1+x`» в D12/§5.2 и `/(1-x)` в §15 | только `/(1-x)` | `Sensor` сравнивает расстояние с 20/5 |
| 11 | `fire_rate`: pre-скейл `data.fireRate` **и** post по `self.fireRate` | один механизм: post `self.fireRate /= (1+x)` | два механизма дают двойной скейл на авто |
| 12 | `sprint`: `sprintSpeed *= (1+x)` каждый кадр | абсолютное значение от базы + watchdog | относительная мутация в per-frame `lerp` даёт геометрическую утечку |
| 13 | `insulation +%` прибавлялся к ёмкости как пункты | `bonus = base_insulation * x` | 40% на куртке с базой 50 давало 90 пунктов вместо 20 |
| 14 | §9: «без `[hooks]` слой молча отключится» | литеральные `.hook("...")` тоже попадают в wrap-surface | провал только у имени, собранного в рантайме |
| 15 | §9 «23 hooks», §5.2/§15 расходились по составу | один список (§9, §12) | два источника правды |
| 16 | D10/D11 про телепорт и NVG | удалены | это Vostok Toolkit, к RTL отношения не имеют |
| 17 | «все 12 `.gd`», тесты в `%TEMP%\opencode\rtl_test` | 9 + 4 новых = 13, тесты в `.check` | в `$tests` стенда RTL не был зарегистрирован вовсе |

## 1. Намерение

Аффикс, который игрок видит в тултипе, должен работать. Сейчас редкость, рамка ячейки и
строка пассивок — косметика: они читаются из `RTLStore` при отрисовке и никуда больше не
попадают. Задача 0.3.0 — превратить их в статы, не сломав сейв и не подравшись с Evolve.

## 2. Цели

- Ролл применяется только пока предмет **надет** (equipment-слот). В рюкзаке, контейнере,
  на витрине и в торговле — не применяется, но **отображается**.
- Статы не пишутся в `Character.tres`, общие ресурсы игры (`ItemData`, `WeaponData`) не
  мутируются постоянно.
- Каждый аффикс наблюдаем: в debug-режиме строка лога на применение (§9.9).
- Конфликт replace-слота больше не актуален (`max_hp` снят, replace-хуков в моде нет), но
  остаётся провал self-check арностей (§12.3): тогда статы этой группы **не выпадают** —
  `RTLApply.dead_stats()` уходит в `build_affixes(..., blocked, rng)` — и в лог пишется одна
  строка. Хуже молчаливого нуля: цифра в тултипе без эффекта.

## 3. Не-цели

- Не трогаем редкость и рамку ячейки — они уже работают (D1).
- Не чиним баланс ванильных пушек и брони; аффиксы только множат существующее.
- Не переводим мод на русский в этом релизе (см. §16).
- Не добавляем аффиксы торговцам, задачам, хранилищам.
- Не переопределяем скрипты игры целиком (`[script_extend]`/override). История 0.2.25 —
  ровно про это: оверрайд `Item.gd` испортил типизированный массив инвентаря в сейве.

## 4. Ограничения

- **Evolve установлен** и загружается раньше RTL (10 < 21). Он владеет replace-слотами
  `character-clamp`, `character-overweight`, `sensor-playerheardetection`, а также держит
  `character-*-pre/post` на `-999`/`999` и permanently правит `controller.walkSpeed`,
  `controller.sprintSpeed`, `data.horizontalRecoil/verticalRecoil/kick`.
- **Владение replace-слотом — first-come**: `hook()` (modloader.gd:14515) возвращает `-1`,
  если слот занят живым владельцем; приоритет при этом не смотрится вообще. Планировать
  «возьмём слот по приоритету» нельзя.
- **pre/post работают вокруг чужого replace**: сгенерированная обёртка делает
  `_dispatch("<base>-pre")` → replace (если владелец есть, с `skip_super`) →
  `_dispatch("<base>-post")` → `-callback`. Значит D12 (мутация при чужом replace)
  рабочая, а `character-clamp-post` существует.
- **Ранние `return` внутри тела не мешают**: `FireEvent` выходит на `fireTimer`/`Malfunction`,
  но post всё равно вызывается. На этом стоит вся оконная схема.
- **Значения — брошенные числа**, не множители: ребаланс пула не переписывает старые
  предметы.
- В `mod.txt` версия одна (`version`), `pack.ps1` сам пишет `mods/RoadToLoot/version.txt`
  и правит README.

## 5. Решения

| # | Решение | Статус |
|---|---|---|
| D1 | Редкость — по экземпляру | принято, в коде 0.2.x |
| D2 | Роллы не пишутся в `Character.tres`; источник истины — сайдкар. В сейв попадает только `rtl_uid` (мета) | уточнено ред. 2 |
| D3 | `user://roadtoloot_moddata.json`, `{v:4, items:{uid:{t, a, p}}}`; v2/v3 читаются, пишется v4 | изменено ред. 2 |
| D4 | Статы только на надетом; отображение — везде | принято |
| D5 | ~~`max_hp` через replace `character-clamp`~~ | **снято в ред. 2**, см. §9.7 |
| D6 | `protection` `+1` на плитке и шлеме, гейт по типу; ролл живёт на `SlotData` рига. Плитка катает **только** `protection`, не весь clothing-пул | изменено ред. 2, подтверждено |
| D7 | `condition` — один аффикс на оружие и одежду, срабатывает вероятностной отменой износа | изменено ред. 2 |
| D8 | Цвет аффикса в тултипе — по тиру предмета | принято |
| D9 | Применимость по базовым полям и типу (§6) | принято |
| D10 | (телепорт) | удалено, не про RTL |
| D11 | (NVG) | удалено, не про RTL |
| D12 | `noise` без replace: временный сдвиг `gameData.playerPosition` в `/(1−x)`, восстановление в post + watchdog | изменено ред. 2 |
| D13 | Мутации оружейных полей — только в синхронном окне pre→post, всегда с восстановлением | принято |
| D14 | Тултип: маппинг в ванильные строки, остальное — свои строки в том же стиле | принято |
| D15 | Фильтры применимости — в `RTLRoll.build_affixes(category, tier, itemData, blocked, rng)`, `rng` последним | принято |
| D16 | `low_hp_regen` — flat HP/s ниже 30% HP | принято |
| D17 | `rtl_uid` в мете `SlotData` — стабильная идентичность предмета | новое |
| D18 | Мета переносится в проверенных швах (`Initialize`, `Display`, `Storage`); `slotdata-update-post` **отложен на 0.4.0** (§7.3) | новое, подтверждено |
| D19 | `condition` в ванили всегда целое; дробных значений мод не создаёт | новое |
| D20 | Self-check арностей колбэков на старте | новое |
| D21 | Приоритеты хуков: 100/1000/2000; `999` запрещён (тай-брейка нет) | новое |
| D22 | MCM-флаг `live_stats` — мастер-выключатель статов (тултип живёт отдельно) | новое |
| D23 | Пул гейтится по релизу (`RTLPool.ACTIVE_RELEASE`): в 0.3.0 выпадают только статы, у которых есть аппликатор; остальные включаются в 0.4.0 | новое |

## 6. Пул аффиксов

`RTLPool.gd`. Удалены `sway`, `penetration`, `durability` (последний слился в `condition`),
`max_hp` (D5). Всего 17 записей.

| category | stat | unit | обы | rare | leg | needs |
|---|---|---|---|---|---|---|
| weapon | `damage` | pct | 5–15 | 10–20 | 15–30 | damage>0 |
| weapon | `recoil` | pct | 8–15 | 12–22 | 18–30 | damage>0 |
| weapon | `fire_rate` | pct | 5–10 | 8–14 | 10–20 | damage>0 |
| weapon | `low_hp_damage` | pct | 15–25 | 25–35 | 35–50 | damage>0 |
| weapon | `condition` | pct | 5–12 | 12–25 | 20–50 | damage>0 |
| clothing | `regen` | hp/s | 0.01–0.02 | 0.02–0.05 | 0.04–0.08 | — |
| clothing | `low_hp_regen` | hp/s | 0.03 | 0.05 | 0.08 | — |
| clothing | `carry` | kg | 2–5 | 5–8 | 8–10 | capacity>0 |
| clothing | `stamina_drain` | pct | 8–15 | 12–22 | 18–30 | — |
| clothing | `insulation` | pct | 10–20 | 20–30 | 30–40 | insulation>0 |
| clothing | `noise` | pct | 10–20 | 15–30 | 20–40 | — |
| clothing | `sprint` | pct | 3–6 | 5–9 | 8–12 | — |
| clothing | `protection` | flat | — | +1 | +1 | type Helmet/Armor |
| clothing | `thirst_drain` | pct | 8–15 | 12–22 | 18–30 | — |
| clothing | `hunger_drain` | pct | 8–15 | 12–22 | 18–30 | — |
| clothing | `sanity_drain` | pct | 8–15 | 12–22 | 18–30 | — |
| clothing | `condition` | pct | 5–12 | 12–25 | 20–50 | — |

`pct` — доля от базы (0.05…0.50), не готовое число. `unit` нужен для форматирования
(§11) и для клэмпа суммы при агрегации.

**Гейт по релизу (D23).** У каждой записи пула есть `release`: 1 — выпадает в 0.3.0,
2 — только в 0.4.0. `RTLPool.ACTIVE_RELEASE` отбрасывает записи с `release > ACTIVE_RELEASE`
в `entries()`, `affix_ids()` и `build_affixes()`. Без гейта 0.3.0 показывала бы в тултипе
цифры, которые не работают, — ровно то, что релиз должен прекратить.

| release | статы |
|---|---|
| 1 (0.3.0) | `regen`, `low_hp_regen`, `carry`, `stamina_drain`, `insulation`, `thirst_drain`, `hunger_drain`, `sanity_drain` |
| 2 (0.4.0) | `damage`, `recoil`, `fire_rate`, `low_hp_damage`, `condition` (weapon), `noise`, `sprint`, `protection`, `condition` (clothing) |

Тираж и рамка редкости от гейта не зависят: у ствола в 0.3.0 тир катится, аффиксов просто
ноль — так же, как сейчас, когда пул не покрывает тир. Старые роллы 0.2.25 (`max_hp`, `sway`,
`penetration`, `durability`, `low_hp_regen` с `unit = mult`) остаются в сайдкаре, показываются
через фолбэк форматтера и **не применяются** — `RTLStats` складывает только известные статы.

Плитка (`nested`) катает **только строку `protection`** — плитка остаётся плиткой, а не
второй курткой. Технически полный clothing-пул возможен (ролл живёт на риге), но это
балансовое решение, а не техническое; менять его — отдельный разговор.

## 7. Идентичность и сайдкар

### 7.1 Проблема

Мета `SlotData` **не переживает** `SlotData.Update()` (проверено: `Update` копирует
`itemData, nested, storage, condition, amount, position, mode, zoom, chamber, casing, state`
и всё). При этом `Update()` вызывают `Item.Initialize` (Item.gd:45), `Item.Display`
(Item.gd:72) и `LootContainer.Storage` (LootContainer.gd:188). А `ContextRemove`
(Interface.gd:2465) и `CombineSwap` (Interface.gd:2011) собирают `SlotData.new()` вообще
без `Update()`.

Значит ролл живёт на транзиентной копии и должен каждый раз переноситься заново. Ключи
`kind|file|n` из 0.2.25 строятся по порядку детей грида: два одинаковых АК в рюкзаке,
вытащили второй — у первого теперь ролл второго. Сейчас это косметика; с живыми статами
это реролл предмета перетасовкой инвентаря.

### 7.2 Решение: `rtl_uid`

- При первом присвоении ролла предмет получает `rtl_uid` (случайный 64-бит, строка hex).
- Мета `SlotData` **сериализуется**: проба `ResourceSaver.save` → `ResourceLoader.load`
  вернула `metadata/rtl_*` без потерь, в `get_property_list()` они видны как
  `metadata/<key>`. Поэтому `rtl_uid` переживает сейв сам, без сайдкара.
- Сайдкар ключуется по `uid`: `{v:4, items:{uid:{t, a, p}}}`. `p` — ролл плитки (D6).
- Миграция: `v2`/`v3` читаются; запись без `uid` получает его на загрузке и связывается по
  старому позиционному ключу **один раз**; следующий `SaveCharacter` пишет уже `v4`.
- `rtl_uid` — единственное, что мод кладёт в сейв. Это не ролл, геймплейной ценности не
  несёт; D2 в части «роллы не в `Character.tres`» не нарушается (подтверждено, §17 п.3).

### 7.3 Перенос меты

Проверенные швы (все на скриптах, которые мод уже оборачивает, все синхронные):

| шов | что делает |
|---|---|
| `item-initialize-post(source, data)` | копировать `rtl_*` из `data` (источник) в `_caller.slotData` |
| `item-display-post(source, data, showReturns)` | то же для витрин/контейнеров |
| `lootcontainer-storage-post(containerGrid)` | `containerGrid.get_children()[i]` → `_caller.storage[i]` (Storage обходит грид в том же порядке) |

`slotdata-update-post(slotData)` (обёртка на `res://Scripts/SlotData.gd`) закрыл бы все три
одним движением, но это **обёртка базового скрипта, который держит типизированные массивы
инвентаря** — ровно тот класс изменений, что дал порчу сейва в 0.2.25. Поэтому решение
ред. 2: в 0.3.0 её **нет**, живём на трёх швах выше; включаем в 0.4.0 (T9) только после
save/load на 0.3.0, и три шва остаются как страховка. В этом же причина не полагаться на
неё: любой мод, который *оверрайдит* `res://Scripts/SlotData.gd` (в экосистеме такой
паттерн есть — см. комментарий в `.check/check.ps1`), снимет обёртку вместе с хуком.

### 7.4 Файл

В 0.2.25 запись была простой (`tmp` → `_replace`, без резерва): битый файл молча
игнорировался, и роллы терялись вместе с ним. В 0.3.0 файл держит уже геймплейные статы,
поэтому I/O переезжает в `RTLSidecar.gd` и получает страховку:

- `write` → `save` → `.bak` (копия предыдущей версии) → `.tmp` → `_replace`; на Windows
  rename поверх файла может упасть — тогда цель удаляется и rename повторяется.
- `read`: нечитаемый основной переносится в `roadtoloot_moddata.json.corrupt-<unixtime>`
  (байты сохраняются для разбора) и грузится `.bak`.
- Формат: `{v:4, items:{uid:{t, a, p}}}`; `v2`/`v3` читаются позиционными ключами,
  запись всегда `v4`.
- Путь — аргумент с дефолтом (`user://roadtoloot_moddata.json`), чтобы headless-тест писал
  в свой файл и не трогал пользовательский.

## 8. Агрегация (`RTLStats`)

Новый `RTLStats.gd` — `RefCounted` со статическими функциями (как `RTLRoll`), без `load()`
и путей внутрь игры, покрыт headless-тестом.

```
clothing_totals(slots: Array) -> Dictionary
  slots: [{slot_name: String, slot_data: SlotData, item_data: ItemData}]
  -> {stat: float}                                  # суммы, не множители

weapon_totals(slot_data: SlotData) -> Dictionary
  -> {stat: float}                                  # роллы одного ствола
```

- **Две функции, а не `snapshot`.** Оружие нельзя суммировать: надето и `Primary`, и
  `Secondary`, а `FireEvent` приходит от конкретного рига. Сумма по обоим стволам дала бы
  двойной `damage`. Окно §9.3 берёт `weapon_totals(_caller.slotData)`.
- В `clothing` идут роллы всех надетых слотов **плюс** ролл плитки из `Store.plate_rolls`
  рига, если индекс ещё в `nested`.
- Плитка и шлем уже попадают в `clothing` своими слотами, отдельного ключа `plate` нет.
- `insulation` складывается не пунктами: `total += item_data.insulation * value` (§9.2).
- Неизвестные статы (легаси `max_hp`/`sway`/… из сайдкара 0.2.25) в суммы не попадают:
  `match` по известному списку, всё прочее игнорируется.
- Кеша нет: слотов не больше семи, пересчёт дешевле любой инвалидации и не даёт устаревшей
  суммы в кадре снятия предмета.
- Сумма `pct` клампится при применении, не при агрегации: `min(sum, 0.8)` для дренажей и
  `min(sum, 0.9)` для `noise` (там деление на `1−x`).

## 9. Аппликаторы (`RTLApply`)

`RTLApply.gd` — владелец хуков, `RefCounted` с `_host` (`RTLBoot`), создаётся в `_ready`.
Общий приём: **pre запоминает, post восстанавливает**; ничего не остаётся изменённым между
кадрами. Все post-хуки — на `2000`, чтобы идти после Evolve (999). Тай-брейка при равных
приоритетах нет, поэтому `999` занят Evolve и повторять его нельзя (D21).

### 9.1 Дренажи: `energy`, `hydration`, `mental`, `stamina`

| аффикс | хуки |
|---|---|
| `hunger_drain` | `character-energy-pre/post` (delta) |
| `thirst_drain` | `character-hydration-pre/post` (delta) |
| `sanity_drain` | `character-mental-pre/post` (delta) |
| `stamina_drain` | `character-stamina-pre/post` (delta) |

```
pre(delta):  _before = {field: gameData.<field>}
post(delta): drained = _before.field - gameData.<field>
             if drained <= 0: return                      # реген-ветку не трогаем
             if gameData.<field> <= 0: return             # порог уже сработал
             gameData.<field> = _before.field - drained * (1.0 - x)
```

- `Stamina` (Character.gd:142) обрабатывает `bodyStamina` **и** `armStamina` в одном вызове —
  оба поля восстанавливать отдельно.
- Восстановление **не переводит значение через ноль**: если после ванильного дренажа поле
  `<= 0`, флаг (`Starvation`/`Dehydration`/`Insanity`/`Frostbite`) уже выставлен, и
  «воскрешать» значение нельзя — иначе флаг дёргается каждый кадр.
- `gameData.isDead` → выходить.

### 9.1b `regen` и `low_hp_regen` — `character-health-post(delta)`

`Character.Health` (Character.gd:39) только снимает HP за флаги и не лечит вовсе — ни
естественного регена, ни пассивки. Поэтому оба стата добавляются пост-хуком:

```
post(delta): if gameData.isDead: return
             var healed = regen * delta
             if gameData.health < 30.0: healed += low_hp_regen * delta
             if healed <= 0.0: return
             gameData.health += healed
```

- `low_hp_regen` — плоские HP/с ниже 30 HP (D16); это доля от 100, а не от максимума, потому
  что `max_hp` в пуле больше нет.
- Порог проверяется по `health` **до** прибавки: иначе на 29.9 HP прибавка в кадре сама себя
  выключала бы и реген дёргался бы.
- `Clamp()` идёт последним в том же `_physics_process` (Character.gd:35), поэтому `health`
  не уйдёт выше 100 между кадрами; свой `min()` всё равно ставим — post не должен зависеть
  от порядка ванильных вызовов.

### 9.2 `carry` и `insulation` — `interface-updatestats-post(updateLabels)`

Это корутина (`Interface.gd:500` — `await get_tree().physics_frame`), поэтому **post
приходит на кадр позже вызова**, а `pre` — в том же кадре. Пару pre/post здесь использовать
нельзя ни для чего.

Флаг перегруза считается **до** блока лейблов и вне `if updateLabels` (Interface.gd:534).
Поэтому после прибавки ёмкости его надо пересчитать, иначе `carry` остаётся косметикой:

```
interface.currentInventoryCapacity += carry_flat
if updateLabels:
    interface.inventoryWeightPercentage = currentInventoryWeight / currentInventoryCapacity
    interface.inventoryCapacity.text  = str("%.1f" % currentInventoryCapacity)
    interface.inventoryWeight.modulate = RED / YELLOW / GREEN (>1 / >=0.5 / else)
    interface.equipmentCapacity.text  = str(int(round(currentInventoryCapacity))) + "kg"
# всегда, вне updateLabels:
if currentInventoryWeight > currentInventoryCapacity:
    if !gameData.overweight: interface.character.Overweight(true)
else:
    interface.character.Overweight(false)
```

`insulation` — доля от **собственной** базы предмета, не пункты:

```
eq_bonus = sum(item.insulation * x)               # x — доля аффикса
eq_total = interface.currentEquipmentInsulation + eq_bonus
interface.character.insulation = clampf(1.0 - eq_total / 100.0, 0.0, 1.0)
if updateLabels:
    interface.equipmentInsulation.text = str(int(round(eq_total)))
    modulate: eq_total <= 25 -> RED, <= 50 -> YELLOW, else GREEN
```

Guard: `is_instance_valid(interface.character)` — post на кадр позже, сцена могла смениться.
`character.insulation` читается `Character.Temperature` (Character.gd:110) каждый кадр.

### 9.3 Оружейное окно: `weaponrig-fireevent-pre/post`

Одно окно на четыре аффикса, потому что всё читается внутри тела синхронно:
`Raycast` → `ApplyDamage(data.damage)` (WeaponRig.gd:509), `recoil.ApplyRecoil()`
(:426) читает `data.verticalRecoil/horizontalRecoil/kick` в момент вызова, износ —
:440-442.

```
pre():  if _win.has(rig_id): return                      # реентерабельность
        if data == null: return
        _win[rig_id] = {dmg, hr, vr, kick, cond: slotData.condition}
        data.damage = int(round(data.damage * (1 + dx)))   # dx = damage (+low_hp_damage)
        data.horizontalRecoil *= (1 - rx)
        data.verticalRecoil   *= (1 - rx)
        data.kick             *= (1 - rx)
post(): w = _win.erase(rig_id); if w == null: return
        restore all five fields
        if slotData.condition < w.cond and slotData.condition > 0 and randf() < cx:
            slotData.condition = w.cond                    # отмена износа целиком
```

- `dx = damage + low_hp_damage` при `gameData.health < 30`.
- `data.damage` — целое; после умножения приводить к `int` (`round`), иначе тултип покажет
  дробное там, где ваниль печатает `int(itemData.damage)`.
- Износ отменяется **до** нуля: `condition == 0` — это уже случившийся `PlayArmorBreak()`
  (для рига) или оружие, которое нельзя чинить; воскрешать нельзя (D19).
- `Malfunction()`/`fireTimer` дают ранний выход из тела — окно всё равно закрывается.

### 9.4 `fire_rate` — `weaponrig-fireinput-post`

`FireInput` (WeaponRig.gd:379) выставляет интервал сам: полуавтомат
`fireImpulse = 0.1; fireRate = 0.1`, авто `fireRate = data.fireRate`. Поэтому **один**
механизм, без pre:

```
post(): if x <= 0 or self.fireRate <= 0: return
        self.fireRate = self.fireRate / (1 + x)
```

`data.fireRate` не трогаем вообще — иначе на авто получается двойной скейл (§0 п.11).
`FireEvent` сравнивает `fireTimer < fireRate`, так что интервал действует и на следующие
выстрелы.

### 9.5 `noise` — `sensor-playerheardetection-pre/post`

`Sensor.PlayerHearDetection` (Sensor.gd:312) сравнивает расстояние с литералами:

```
playerDistance = global_position.distance_to(gameData.playerPosition)
if (playerDistance < 20 && isRunning) || (playerDistance < 5 && isWalking): Threat(...)
```

Значит «тише на x» = эффективное расстояние **больше**:

```
pre():  if x <= 0: return
        _pp = {v: gameData.playerPosition, frame: Engine.get_physics_frames()}
        gameData.playerPosition = global_position + (gameData.playerPosition - global_position) / (1.0 - x)
post(): if _pp.is_empty(): return
        gameData.playerPosition = _pp.v
        _pp = {}
```

- `x` клампится `<= 0.9` (деление на ноль).
- Evolve заменяет функцию (`skip_super`), но читает **тот же** `gameData.playerPosition` —
  композиция корректная.
- `playerPosition` читают также `AI.gd:472`, `AISpawner.gd:244/279`, `BTR.gd:343/379`,
  `Helicopter.gd:141/183/189/286`, `FishPool.gd:40`, `Trader.gd:87/192`. Утечка искажает
  `look_at` вертолёта и дистанцию торговца до конца кадра (`Controller.gd:137` перезапишет
  на следующем). Поэтому — watchdog в `_process`: если `_pp` непуст и кадр сменился,
  восстановить.

### 9.6 `sprint` — `controller-movementstates-pre/post`

`MovementStates` (Controller.gd:180) делает `currentSpeed = lerp(currentSpeed, sprintSpeed, ...)`,
то есть буст виден через `currentSpeed` с разгоном, а на снятии затухает, а не щёлкает.

```
pre():  if x <= 0: return
        if _sprint.frame == Engine.get_physics_frames() - 1: base = _sprint.base
        else: base = sprintSpeed                       # поле чистое, обновляем базу
        _sprint = {base: base, frame: ..., value: base * (1 + x)}
        sprintSpeed = _sprint.value
post(): if _sprint.is_empty(): return
        sprintSpeed = _sprint.base
```

Относительная мутация (`*=`) запрещена: при утечке post значение компаундится каждый кадр.
Evolve permanently пишет `sprintSpeed` из своих атрибутов — база берётся из поля, поэтому
композиция сохраняется.

### 9.7 ~~`max_hp`~~ — снято

Причины:

1. `character-clamp` принадлежит Evolve (first-come). Свой replace получить нельзя, пока
   Evolve установлен; `_max_hp_supported` был бы `false` навсегда.
2. Если слот всё-таки достанется, переписать надо **десять** `clampf` (Character.gd:191:
   `health, energy, hydration, mental, temperature, cat, bodyStamina, armStamina, oxygen,
   reputation`), а спека ред. 1 переписывала один. Пропущенные девять перестают
   клампиться молча — это порча статов, а не косметика.
3. Поднять потолок health пост-хуком нельзя: значение выше 100 стирается следующим
   `Clamp()` в том же кадре.

Если аффикс понадобится позже — отдельная фича: replace + все десять клампов + жёсткий гейт
на старте (не получили слот → `max_hp` запрещён в пуле, одна запись в лог с именем
владельца из `get_replace_owner("character-clamp")`).

### 9.8 `protection` — `interface-platecheck-pre/post`, `interface-helmetcheck-pre/post`

Ваниль читает `protection` только у **вложенной плитки** (`PlateCheck`, Interface.gd:2825:
`for itemData in slotData.nested`) и у **шлема** (`HelmetCheck`, :2883:
`slotData.itemData.protection`). У рига `itemData.protection` не читает никто — поэтому гейт
по `protection > 0` дал бы ригу мёртвый аффикс, а гейт по типу — нет (D6).

```
pre(penetration):  for каждый itemData-цель с bonus:
                     _prot[itemData.get_instance_id()] = itemData.protection
                     itemData.protection += bonus
post(penetration, _result): restore; return null          # _result пропускаем как есть
```

`+1` намеренно, а не проценты: `PlateCheck` сравнивает `protection` с `penetration` через
`<`/`==`/`>`, и +1 переводит попадание из «пробил» в «сдержал». Восстанавливать
обязательно — `ItemData` общий на все экземпляры файла; окно синхронное, но любой другой
читатель внутри него увидит завышенное значение.

Износ одежды идёт **в этом же окне**, а не в §9.3: `PlateCheck` уменьшает `condition`
**рига** (см. цикл выше), а `HelmetCheck` — шлема. `pre` запоминает `condition` этих
`SlotData`, `post` с вероятностью `x` возвращает прежнее значение (та же `undo_wear`, что и
для оружия). §9.3 покрывает только оружие: там свой `SlotData` и свой путь износа.

### 9.9 Наблюдаемость

`RTLConfig.debug_live_stats` (или `debug_enabled`): одна строка на применение, не на кадр:

```
[rtl] damage 40 -> 48 (x=0.20) rig=Primary
[rtl] carry +5 -> capacity 15.0 -> 20.0 (overweight=false)
[rtl] noise x=0.25, dist push applied (sensor=Nomad_04)
```

Без этого «работает / не работает» проверяется на глаз, а тихий no-op от арности не виден
вообще.

## 10. Плитка и шлем: переносы

`nested` — `Array[ItemData]` (Item.gd:130: `slotData.nested.append(itemDragged.slotData.itemData)`).
SlotData плитки при установке **выбрасывается**. Отсюда модель:

> Ролл плитки хранится на `SlotData` **рига** (`rtl_plate` = `{index: {file, t, a}}`),
> транзиентный `SlotData` плитки служит только транспортом «внутрь» и «наружу».

Пять путей, все синхронные:

| путь | где | что делает мод |
|---|---|---|
| установка | `item-combine-post(itemDragged)` | ролл из `itemDragged.slotData`; индекс = `nested.size()-1` (Combine всегда `append`) |
| замена | `item-combineswap-post(itemDragged)` | `_result` = вынутый `ItemData`; ролл — по индексу из `rtl_plate`, затем pending |
| изъятие | `item-remove-post(nestedIndex)` | `_result` — вынутый `ItemData`; ролл по `nestedIndex`, затем pending |
| возврат в грид | следствие `ContextRemove` (Interface.gd:2460 → :2485) | `Create()` строит предмет в том же стеке → потребляется в `item-initialize-post` |
| сохранение контейнера | `lootcontainer-storage-post(containerGrid)` | перенос `rtl_*` в `storage[i]` |

**Pending — не FIFO по кадрам.** Ключ — `itemData.get_instance_id()`, значение — ролл.
Кладётся в `_pending[id]`, потребляется следующим `item-initialize-post`, у которого
`data.itemData` совпал по id; остаток чистится в конце кадра. FIFO из ред. 1 не нужен:
`Item.Remove` уже отдаёт `nestedIndex` и `_result` (ред. 1 сама это заметила в §9, но
оставила очередь).

`ContextRemove` для `Armor` отдельно переносит `condition` (Interface.gd:2471:
`newSlotData.condition = contextItem.slotData.condition; contextItem.slotData.condition = 100.0`) —
мод туда не лезет.

## 11. Тултип (`RTLDisplay`)

### 11.1 Правила

- Строка `Passive - <Tier>` убирается. Аффиксы живут внутри `Elements`.
- **Маппинг** в ванильную строку — добавляем цветной сиблинг, текст ванили не меняем
  (значение в строке остаётся базовым, модификатор читается рядом):

| stat | строка | текст |
|---|---|---|
| `damage` | `Damage` | ` +20%` |
| `condition` | `Condition` | ` −40% wear` |
| `carry` | `Capacity` | ` +5kg` |
| `insulation` | `Insulation` | ` +15%` |
| `protection` | `Protection` | ` +1` |
| остальные | своя | `Fire rate +12%`, `Noise −25%`, … |

- Форматирование текста — **чистая функция** `RTLText.format_affix(stat, value, locale)`:
  тестируется headless, не требует сцены.
- Цвет — тир предмета (D8): `{1: (0.45,0.7,1.0), 2: (0.8,0.55,1.0), 3: (1.0,0.82,0.3)}`.

### 11.2 Идемпотентность

`Tooltip.Update` (Tooltip.gd:95) начинается с `Reset()`, который скрывает **фиксированный**
список строк и не знает про наши узлы. Поэтому:

- Свои строки в `Elements` нужно снимать/скрывать на каждой смене предмета (по
  `item.get_instance_id()`), иначе они висят на следующем предмете без аффиксов.
- Вложенный в ванильную строку лейбл переживает `Reset()` (скрывается только строка) —
  его нельзя оставлять без проверки владельца: следующий предмет с той же строкой покажет
  чужой модификатор.
- Строка `Condition` получает `modulate` от ванили (Tooltip.gd:124-126) — вложенному
  лейблу цвет копировать.
- `Tooltip.Update` в конце ставит `panel.size = Vector2(256, 0)` и
  `interface.tooltipOffset = panel.size.y / 2.0` (:271-272) — то есть `tooltipOffset`
  **всегда 0**, это ванильная особенность, а не баг, который надо компенсировать. Наш
  post-хук идёт после: `Elements` — контейнер, высота пересчитается на следующем layout-
  проходе в том же кадре. Повторять эти две строки не нужно; если в игре всё же окажется
  обрезка — вернуться к пункту с дампом, а не гадать.
- Стиль своей строки — `duplicate()` живой ванильной строки; отступ значения
  `get_combined_minimum_size().x + 2`.
- **Неизвестно** (проверить дампом в лог до вёрстки): сколько детей у строки кроме
  `get_child(0)` и как называется value-label в клонах. Тултип правит только
  `get_child(0)`, поэтому вставлять надо так, чтобы это оставалось верным.

## 12. Хуки, арности, приоритеты

### 12.1 Таблица

`post` для void-метода получает ровно аргументы метода; для non-void — `args + [_result]`.
Цена ошибки разная, и это проверено по `modloader.gd`:

- `_dispatch` (pre-хуки и `-post` у void, :14730) делает `cb.callv(args)` — при несовпадении
  арности в Godot 4.6.3 это **молчаливый no-op**: ни вызова, ни ошибки. Именно этот класс
  ловит self-check §12.3.
- `_dispatch_post` (`-post` у non-void, :14745) сверяет `get_argument_count()`; при
  несовпадении уходит в legacy-ветку `cb.callv(args)` и пишет warning в лог modloader'а один
  раз на колбэк. Хук сработает, но `_result` не получит и не изменит — для `PlateCheck` это
  значит «модификатор не применился, ошибки нет».

Поэтому арность — часть контракта, а таблица ниже — единственный источник правды.

| хук | сигнатура в ванили | арность post | приоритет |
|---|---|---|---|
| `character-health-post` | void `Health(delta)` | 1 | 2000 |
| `character-energy-pre` / `-post` | void `Energy(delta)` | 1 / 1 | 2000 |
| `character-hydration-pre` / `-post` | void `Hydration(delta)` | 1 / 1 | 2000 |
| `character-mental-pre` / `-post` | void `Mental(delta)` | 1 / 1 | 2000 |
| `character-stamina-pre` / `-post` | void `Stamina(delta)` | 1 / 1 | 2000 |
| `interface-updatestats-post` | void `UpdateStats(updateLabels)` | 1 | 1000 |
| `weaponrig-fireinput-post` | void `FireInput()` | 0 | 2000 |
| `weaponrig-fireevent-pre` / `-post` | void `FireEvent()` | 0 / 0 | 2000 |
| `sensor-playerheardetection-pre` / `-post` | void `PlayerHearDetection()` | 0 / 0 | 2000 |
| `controller-movementstates-pre` / `-post` | void `MovementStates(delta)` | 1 / 1 | 2000 |
| `interface-platecheck-pre` / `-post` | **bool** `PlateCheck(penetration)` | 2 / 2 | 2000 |
| `interface-helmetcheck-pre` / `-post` | **bool** `HelmetCheck(penetration)` | 2 / 2 | 2000 |
| `tooltip-update-post` | void `Update(item)` | 1 | 100 |
| `tooltip-info-post` | void `Info(hoverInfo)` | 1 | 100 |
| `item-initialize-post` | void `Initialize(source, data)` | 2 | 100 |
| `item-display-post` | void `Display(source, data, showReturns)` | 3 | 100 |
| `item-combine-post` | void `Combine(itemDragged)` | 1 | 100 |
| `item-combineswap-post` | **ItemData** `CombineSwap(itemDragged)` | 2 | 100 |
| `item-remove-post` | **ItemData** `Remove(nestedIndex)` | 2 | 100 |
| `lootcontainer-createloot-post` | void `CreateLoot(item)` | 1 | 100 |
| `lootcontainer-ailoot-post` | **SlotData** `AILoot()` | 1 | 100 |
| `lootcontainer-storage-post` | void `Storage(containerGrid)` | 1 | 100 |
| `loader-savecharacter-post` | void `SaveCharacter()` | 0 | 100 |
| `loader-loadcharacter-post` | void `LoadCharacter()` | 0 | 100 |
| `loader-newgame-post` | void `NewGame(difficulty, season)` | 2 | 100 |

Не нужны (были в ред. 1): `character-overweight` (это сеттер флага, влиять не на что),
`character-temperature` (`insulation` работает через `character.insulation`, §9.2),
`interface-contextremove-post` (передача уже покрыта `item-remove-post` +
`item-initialize-post`), `weaponrig-ready-pre` (до `slotData` бесполезен).

### 12.2 `[hooks]`

```
[hooks]
res://Scripts/LootContainer.gd = CreateLoot, AILoot, Storage
res://Scripts/Item.gd = Initialize, Display, Combine, CombineSwap, Remove
res://Scripts/Loader.gd = SaveCharacter, LoadCharacter, NewGame
res://Scripts/Tooltip.gd = Update, Info
res://Scripts/Character.gd = Health, Energy, Hydration, Mental, Stamina
res://Scripts/Interface.gd = UpdateStats, PlateCheck, HelmetCheck
res://Scripts/WeaponRig.gd = FireInput, FireEvent
res://Scripts/Sensor.gd = PlayerHearDetection
res://Scripts/Controller.gd = MovementStates
```

Декларация нужна не потому, что «иначе не обернётся»: литеральные `.hook("...")` в
исходниках мода тоже попадают в wrap-surface (скан). Провал — только у имени, **собранного
в рантайме** (`"character-" + name`). Правило простое: имена хуков — литералы, декларация —
для явности и для случая, когда обёртка нужна до регистрации.

**Состав по релизам.** В 0.3.0 объявляются только хуки T2/T4: `LootContainer` —
`CreateLoot, AILoot, Storage`; `Item` — `Initialize, Display`; `Loader` — три; `Tooltip` —
два; `Character` — `Health, Energy, Hydration, Mental, Stamina`; `Interface` — `UpdateStats`.
`Combine/CombineSwap/Remove`, `WeaponRig`, `Sensor`, `Controller`, `PlateCheck`/`HelmetCheck`
добавляются в 0.4.0 вместе со своими задачами (T5/T6) — не раньше, иначе мод оборачивает
методы, для которых у него нет колбэков.

### 12.3 Self-check (D20)

В `_ready` после регистрации:

```
expected = {"character-health-post": 1, "weaponrig-fireevent-pre": 0, "interface-platecheck-post": 2, ...}
for hook in expected:
    if cb.get_argument_count() != expected[hook]:
        log_error(...) ; disable_group(group)
```

Это единственная защита от всего класса молчаливых no-op: `--check-only` и headless-тесты
арность не видят. Тест `test_rtl_arity.gd` держит ту же таблицу и падает, если код и
ожидания разъехались.

## 13. Тесты

Стенд `.check/check.ps1` копирует только VTK, ThermalVTK и LooterShooter; RTL там нет.
Добавить (по образцу блока LooterShooter):

1. копирование `standalone mods\RoadToLoot\mods\RoadToLoot\*.gd` → `proj\mods\RoadToLoot`;
2. цикл `--check-only` по `res://mods/RoadToLoot/<file>.gd`;
3. записи в `$tests` (список явный, отсутствие файла — `throw`).

Чистые модули (headless, без сцены):

| тест | что держит |
|---|---|
| `test_rtl_pool.gd` | состав пула, отсутствие `sway`/`penetration`/`durability`/`max_hp`, гейт `ACTIVE_RELEASE`, `validate()` без проблем |
| `test_rtl_roll.gd` | фильтры `needs` (damage/capacity/insulation/armor), `blocked`, веса, все тиры, `rng` последним |
| `test_rtl_stats.gd` | `clothing_totals`/`weapon_totals`, плитка как часть `clothing`, `insulation` от базы предмета, легаси-статы игнорируются |
| `test_rtl_text.gd` | `format_delta`/`format_line` для всех 17 статов, легаси-фолбэк |
| `test_rtl_sidecar.gd` | `write`/`read`, `.bak`, `corrupt-<ts>`, v2/v3/v4, roundtrip с `p` |
| `test_rtl_store.gd` | `uid` стабилен, `copy_meta`, `plate`-операции на риге |
| `test_rtl_arity.gd` | таблица §12.1 против колбэков `RTLApply` |

В 0.4.0 добавятся `test_rtl_wear.gd` (`undo_wear(before, after, chance, roll)`, граница 0) и
`test_rtl_transfer.gd` (пять путей переноса ролла плитки).

UI-часть (тултип, вставка строк) headless не проверяется: `Tooltip` требует дерева и
`Interface`. Ручной чек-лист в §15.1.

Тесты лежат в `.check/project/tests/` — каталог под `.gitignore` целиком, поэтому в коммит
попадает только код мода и документы. Новый тест добавляется в `$tests` вручную: список
явный, и отсутствующий файл там — `throw`, то есть тест обязан существовать до того, как
его имя появится в списке (порядок задач в §15 это учитывает).

## 14. Риски

| # | риск | проверка / смягчение |
|---|---|---|
| R1 | обёртка `res://Scripts/SlotData.gd` ломает типизированные массивы сейва (след 0.2.25) | по умолчанию **не** включать; три проверенных шва (§7.3); включать только после save/load |
| R2 | тихая ошибка арности отключает группу аффиксов | self-check §12.3 + `test_rtl_arity.gd` |
| R3 | утечка `playerPosition`/`sprintSpeed`/`data.*` при пропущенном post | watchdog по кадру + абсолютные значения от базы (не `*=`) |
| R4 | Evolve владеет replace-слотами `sensor-playerheardetection`, `character-clamp`, `character-overweight` | pre/post вокруг чужого replace работает; `max_hp` снят |
| R5 | Evolve permanently правит `data.horizontalRecoil/verticalRecoil/kick` | окно восстанавливает ровно то, что прочитало; база остаётся Evolve-овской |
| R6 | `condition` стал дробным и `<= 0` не наступает | D19 + отмена износа целиком, дроби не создаются |
| R7 | ролл плитки теряется при `CombineSwap` | путь добавлен в §10; pending по `itemData` id |
| R8 | `interface-updatestats-post` приходит на кадр позже, сцена могла смениться | `is_instance_valid` на `interface.character` |
| R9 | тултип растёт при каждом `Update` (раз в 10 кадров) | идемпотентность по `instance_id` + чистка своих узлов при смене предмета |
| R10 | два мода правят `character.insulation` в одном post | RTL идёт на 1000, после Evolve (999); пишет от `currentEquipmentInsulation` |
| R11 | `damage` у дробовика идёт через 6 × `Raycast` | одно окно на `FireEvent`, 6 чтений внутри — нормально |
| R12 | нож (`KnifeRig`) не покрыт | вне объёма §16 |

## 15. План работ

Релиз разбит на два прохода: 0.3.0 — всё, что не трогает оружейный кадр и плитку;
0.4.0 — оружейное окно, `noise`, `sprint`, плитка и `slotdata-update-post`. Причина
простая: пятнадцать аффиксов и двадцать хуков в одном проходе невозможно проверить вручную
за один заход, а ручной чек-лист (§15.1) — единственная проверка для UI и для утечек
состояния между кадрами.

### 0.3.0

**T1 Чистый слой** — `RTLStats`, `RTLText`, правки `RTLPool`/`RTLRoll` (D5/D9/D15/D23),
`test_rtl_pool`/`_roll`/`_stats`/`_text`.

**T2 Идентичность** — `rtl_uid`, сайдкар v4, миграция v3, `item-initialize-post` +
`item-display-post` + `lootcontainer-storage-post`, `test_rtl_sidecar`.

**T3 Тултип** — перестройка `RTLDisplay.apply_tooltip` по §11, палитра по тиру, дамп
структуры строки в лог, ручная проверка «тултип не растёт».

**T4 Аппликаторы, волна 1** — `RTLApply` + self-check арностей + дренажи (§9.1) +
`carry`/`insulation` (§9.2). Лог §9.9, флаг `live_stats` в MCM.

**T7 Регистрация в стенде** — `.check/check.ps1`: копирование, `--check-only`, `$tests`.
Идёт до T8, иначе релиз собирается без прогона.

**T8 Релиз 0.3.0** — `mod.txt` 0.3.0, CHANGELOG, `pack.ps1`, установка в игру, чек-лист
§15.1.

### 0.4.0

**T5 Аппликаторы, волна 2** — оружейное окно (§9.3, §9.4), `noise` (§9.5), `sprint` (§9.6).

**T6 Плитка** — `protection` (§9.8) + переносы (§10) + `rtl_plate` в сайдкаре v4.

**T9 `slotdata-update-post`** — включить обёртку `res://Scripts/SlotData.gd` (D18) и снять
ручные швы §7.3, только после save/load на 0.3.0. Если сейв поедет — остаются три шва,
фича не теряется.

### 15.1 Ручной чек-лист 0.3.0

Для T8 и для приёмки T2–T4:

1. Ролл надетого предмета виден в статах (дренаж, ёмкость, тепло).
2. Ролл в рюкзаке **не** применяется, но строка в тултипе есть.
3. Save → load: роллы на месте и в рюкзаке, и в контейнере.
4. Снял/надел предмет — статы вернулись к базе и применились заново.
5. Два одинаковых предмета в рюкзаке: перестановка не переносит ролл.
6. Тултип открыт 10+ секунд — не растёт и не показывает чужой модификатор.
7. Перегруз: `carry` меняет и `capacity`, и флаг `overweight`.
8. Смерть/рестарт: статы не остаются применёнными, лог без `SCRIPT ERROR`.

## 16. Вне объёма

- 0.4.0: оружейное окно (T5), `noise`/`sprint`, плитка и `protection` (T6),
  `slotdata-update-post` (T9). Спека их описывает целиком, но 0.3.0 их не включает.
- Почему так: оружейное окно — единственное место, где мод мутирует общие ресурсы игры
  (`WeaponData`), и его отладка не должна смешиваться с отладкой дренажей и идентичности.
- `max_hp` (см. §9.7), нож (`KnifeRig`), мультиплеер.
- Постоянная мутация `ItemData`/`WeaponData` — отвергнута (D13).
- Торговцы, задачи, хранилища, убежища.
- Локализация RU (отдельная фаза); тексты аффиксов пока английские, как и остальной UI мода.
- Совместимость с `LootHighlight`/`LooterShooter` — отдельная проверка, если установлены.

## 17. Решения, закрытые перед планом

| # | Вопрос | Решение |
|---|---|---|
| 1 | `max_hp` (D5) | снят из пула совсем; вернуть только отдельной фичей с replace + десять клампов + гейт (§9.7) |
| 2 | `protection` (D6) | `+1` на rare/legendary, гейт по типу (`Helmet`/`Armor`) |
| 3 | `rtl_uid` в сейве (D2) | да; роллы по-прежнему только в сайдкаре |
| 4 | Износ (D7) | отмена декремента целиком с вероятностью `x`, счётчик остаётся целым |
| 5 | Пул плитки | **только `protection`**, не весь clothing (§6) |
| 6 | `slotdata-update-post` (D18) | отложен на 0.4.0 (T9); 0.3.0 живёт на трёх швах §7.3 |
| 7 | Разбиение релиза | 0.3.0 = T1–T4 + T7–T8; 0.4.0 = T5, T6, T9 (§15) |

Открытых вопросов, блокирующих план, нет. Всё, что осталось непроверенным, — это не
решения, а факты, которые добываются прогоном: структура детей ванильной строки тултипа
(§11.2) и поведение `Tooltip.Info`. Оба пункта закрываются в T3 до вёрстки.
