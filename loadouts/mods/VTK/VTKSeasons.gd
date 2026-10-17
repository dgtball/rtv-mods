extends RefCounted
## Чистая логика динамических сезонов: цикл по дням, отображение на ванильные сезоны.
## Ни load(), ни путей внутрь игры: на вход обычные числа,
## поэтому модуль покрыт headless-тестом test_seasons.gd.

const SEASONS := ["spring", "summer", "autumn", "winter"]
const DEFAULT_START_OFFSET := 1

# Палитры тона - лёгкий срез подхода SES: перекраска общих материалов
# растительности и воздуха по сезону. Зимы в растительности нет: зимой тон
# снимается и работает ванильный снег. Цвета - множители к базовому тону
# материала (1,1,1 = без изменений).
const SEASON_TREE_TINT := {
	"spring": Color(0.85, 0.92, 0.76),
	"summer": Color(0.80, 0.88, 0.76),
	"autumn": Color(1.25, 0.95, 0.50),
}
const SEASON_GRASS_TINT := {
	"spring": Color(0.95, 1.10, 0.75),
	"summer": Color(0.95, 1.05, 0.80),
	"autumn": Color(1.15, 0.95, 0.55),
}
const SEASON_AIR_TINT := {
	"spring": Color(1.05, 1.00, 0.95),
	"summer": Color(1.00, 1.00, 0.92),
	"autumn": Color(1.10, 0.85, 0.55),
	"winter": Color(0.95, 1.05, 1.30),
}


static func start_offset_for(choice: String) -> int:
	var key := choice.strip_edges().to_lower()
	if key == "random":
		return randi() % SEASONS.size()
	var i := SEASONS.find(key)
	return i if i >= 0 else DEFAULT_START_OFFSET

static func resolve_index(day: int, cycle_days: int, start_offset: int) -> int:
	var cycle := cycle_days
	if cycle < 1:
		cycle = 1
	var block := (day - 1) / cycle
	return posmod(block + start_offset, SEASONS.size())

static func vanilla_season(index: int) -> int:
	return 2 if index == 3 else 1

static func is_winter(index: int) -> bool:
	return index == 3

# Растительность тонируется только у не-зимних сезонов, зимой тон снимается.
static func uses_tint(index: int) -> bool:
	return index != 3

static func _name_of(index: int) -> String:
	if index < 0 or index >= SEASONS.size():
		return ""
	return SEASONS[index]

static func tree_tint(index: int) -> Color:
	return SEASON_TREE_TINT.get(_name_of(index), Color(1, 1, 1, 1))

static func grass_tint(index: int) -> Color:
	return SEASON_GRASS_TINT.get(_name_of(index), Color(1, 1, 1, 1))

static func air_tint(index: int) -> Color:
	return SEASON_AIR_TINT.get(_name_of(index), Color(1, 1, 1, 1))
