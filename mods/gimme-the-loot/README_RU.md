# **Gimme the Loot**

**Версия:** 0.7.2  
**Идентификатор:** `gimme-the-loot`  
**Автор:** CaptiveAI

**Gimme the Loot** добавляет в *Road to Vostok* на каждый предмет собственный **рarity tier**, который живёт на самом предмете (сохраняется, переезжает с карты на карту), плюс пассивные аффиксы, реально влияющие на геймплей (не просто тултипы).

## Что делает

- **Common** — синяя рамка, 1 аффикс  
- **Rare** — фиолетовая рамка, 2 аффикса  
- **Legendary** — золотая рамка, 3 аффикса  

Предметы из контейнеров, на трупах и лежащие на земле получают тиры и пассивы; military / elite контейнеры сдвигают шансы вверх.

## Установка

1. Скопируйте `GimmeTheLoot.vmz` в папку `mods` игры.
2. Mod Configuration Menu не нужен, но опционален.

## Что менится в игре

**Одежда (на персонаже)**
- Carry capacity
- Insulation
- Sprint speed
- Более медленный drain stamina/hunger/thirst/sanity
- Regen, в т.ч. Low HP
- max_hp
- Dnearetection range ИИ (Noise)
- Perks-like Extra Loot (шанс получить лишний лут)
- Protection (helmet/armor plate)

**Оружие**
- Damage
- Recoil
- Low-HP damage
- Wear (ускоренный износ)

## Настройки MCM

### 01. Display
- Подсветка ячеек
- Блок аффиксов в тултипе
- Палитра Rare/Legendary

### 02. Balance
- Множитель частоты редких тиров 0.5–2.0×
- Контекстный hint для контейнеров

### 03. Debug (только dev‑режим / файл `user://rtl_dev`)
- Debug mode
- Force tier
- Re-roll hovered item
- Log rolls

## Совместимость

⚠ **Не рекомендуется использовать вместе с Evolve или ItemClarity.**  
Моды перехватывают одни seam'ы (character-clamp, sensor, UpdateStats, PlateCheck/HelmetCheck); резолв через `priority=-1` может отобрать замену у другого мода — получатся нулевые/no-op passive.

## Примечания

- Редкость предмета **не пропадает** при подборе/сохранении/смене карты.
- Базовые статы предметов **не меняются**, RTL просто накладывает аффиксы.
- Не ломает сейвы.
- Тултип и цвет ramka match tier.

## Сборка из репозитория

```powershell
powershell -ExecutionPolicy Bypass -File pack.ps1 -Mod gimme-the-loot
```

## История изменений
См. `CHANGELOG.md`.

## Техническая заметка для bug report
- Лог мода: `%APPDATA%\Road to Vostok\MCM\gimme-the-loot\rtl.log`
- Для dev: в debug-сборке (или при файле `rtl_dev`) появляется `03. Debug` в MCM.  
PY