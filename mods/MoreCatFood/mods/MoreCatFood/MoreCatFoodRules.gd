extends RefCounted

const FOOD_PATHS: Array[String] = [
	"res://Items/Consumables/Canned_Meatballs/Canned_Meatballs.tres",
	"res://Items/Consumables/Cooked_Fish_Soup/Cooked_Fish_Soup.tres",
	"res://Items/Consumables/Cooked_Meatballs/Cooked_Meatballs.tres",
	"res://Items/Consumables/Beer/Beer.tres",
]

const BEER_PATH := "res://Items/Consumables/Beer/Beer.tres"

# OIIA настройки
const BPM := 150.0
const BEAT_INTERVAL := 60.0 / BPM          # 0.4 сек
const TRACK_PATH := "res://mods/MoreCatFood/oiia_track.ogg"
const SPIN_SPEED := 18.0                   # постоянная скорость вращения (рад/сек примерно)
const BEAT_IMPULSE_DEG := 90.0             # дополнительный поворот на каждый бит

# Хореография
const CLONE_SPACING := 1.2                 # сторона квадрата из четырёх котов, метры
const CLONE_ANGLE_STEP_DEG := 90.0         # стартовый разворот каждого следующего кота
const CLONE_HIDE_AT := 32.5                # оригинал в центре пропадает
const CLONE_REVEAL_AT := 33.0              # и появляется уже в углу вместе с копиями
const LIFT_HEIGHT := 0.32
const LIFT_TIME := 1.0                     # подъём на 0.32 м за первую секунду

# Кривая скорости
const SPIN_BASE_FACTOR := 0.8
const SPIN_FULL_START := 22.0
const SPIN_SLOW_START := 27.0
const SPIN_BOX_START := 30.0
const SPIN_SLOW_FACTOR := 0.2
const SPIN_BOX_END := 32.0
const SPIN_FAST_END := 35.0
const SPIN_FAST_FACTOR := 2.0
const MERGE_START := 58.0
const MERGE_END := 60.0

# Состояния Cat.gd
const STATE_SIT_START := 27.0
const STATE_IDLE_START := 33.0
const STATE_CYCLE_STEP := 5.0
const STATE_IDLE := 0
const STATE_SIT := 1

# Вспышки
const FLASH_DECAY := 12.0

# Летающие банки
const BEER_SCENE_PATH := "res://Items/Consumables/Beer/Beer.tscn"
const BEER_COUNT := 7
const BEER_RADIUS := 0.85
const BEER_RADIUS_SWING := 0.12
const BEER_HEIGHT := 0.55
const BEER_HEIGHT_SWING := 0.18
const BEER_CAN_SCALE := 3.0

# Хаос и динамика
const CHAOS_START := 33.0
const CHAOS_RAMP := 2.0
const CHAOS_LIFT_CENTER := 0.42
const CHAOS_LIFT_AMP := 0.10
const CHAOS_SIDE := 0.22
const ORBIT_PULSE := 1.15
const SCALE_WAVE_AMP := 0.10
const SCALE_WAVE_FREQ := 8.0
const SCALE_WAVE_STAGGER := 0.12

# Множитель непрерывного вращения по секундам забега.
static func spin_factor(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < LIFT_TIME:
		return lerpf(0.0, SPIN_BASE_FACTOR, smooth01(t / LIFT_TIME))
	if t < SPIN_FULL_START:
		return SPIN_BASE_FACTOR
	if t < SPIN_SLOW_START:
		return 1.0
	if t < SPIN_BOX_START:
		return lerpf(1.0, SPIN_SLOW_FACTOR, smooth01((t - SPIN_SLOW_START) / (SPIN_BOX_START - SPIN_SLOW_START)))
	if t < SPIN_BOX_END:
		return lerpf(SPIN_SLOW_FACTOR, 0.0, smooth01((t - SPIN_BOX_START) / (SPIN_BOX_END - SPIN_BOX_START)))
	if t < CLONE_REVEAL_AT:
		return 0.0
	if t < SPIN_FAST_END:
		return lerpf(1.0, SPIN_FAST_FACTOR, smooth01((t - CLONE_REVEAL_AT) / (SPIN_FAST_END - CLONE_REVEAL_AT)))
	if t < MERGE_START:
		return SPIN_FAST_FACTOR
	if t < MERGE_END:
		return lerpf(SPIN_FAST_FACTOR, 0.0, smooth01((t - MERGE_START) / (MERGE_END - MERGE_START)))
	return 0.0

# Высота подъёма: 0→0.32 за первую секунду, в коробку на 30–32 с,
# снова 0.32 после появления четвёрки.
static func lift_at(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < LIFT_TIME:
		return LIFT_HEIGHT * smooth01(t / LIFT_TIME)
	if t < SPIN_BOX_START:
		return LIFT_HEIGHT
	if t < SPIN_BOX_END:
		return LIFT_HEIGHT * (1.0 - smooth01((t - SPIN_BOX_START) / (SPIN_BOX_END - SPIN_BOX_START)))
	if t < CLONE_REVEAL_AT:
		return 0.0
	return LIFT_HEIGHT

# -1 означает «не трогать» — до 27 с состоянием владеет ваниль.
static func cat_state_at(t: float) -> int:
	if t < STATE_SIT_START:
		return -1
	if t < STATE_IDLE_START:
		return STATE_SIT
	var n := int(floor((t - STATE_IDLE_START) / STATE_CYCLE_STEP))
	if n % 2 == 0:
		return STATE_IDLE
	return STATE_SIT

static func state_anim(state: int) -> String:
	return "Cat_Idle" if state == STATE_IDLE else "Cat_Sit"

static func smooth01(k: float) -> float:
	var x := clampf(k, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func is_beer_path(path: String) -> bool:
	return path == BEER_PATH

# Насколько сильный хаос в данный момент: 0 до 33 с, 1 на 35–58 с,
# плавный спад к нулю на слиянии 58–60 с.
static func chaos_amount(t: float) -> float:
	if t < CHAOS_START:
		return 0.0
	var rise := smooth01((t - CHAOS_START) / CHAOS_RAMP)
	var merge := smooth01((t - MERGE_START) / (MERGE_END - MERGE_START))
	return rise * (1.0 - clampf(merge, 0.0, 1.0))

# Разная частота и фаза по индексу кота; y в пределах ±0.10 от центра 0.42.
static func chaos_offset(index: int, t: float) -> Vector3:
	var phase := float(index) * 2.39996323
	return Vector3(
		sin(t * TAU * 1.3 + phase) * CHAOS_SIDE,
		sin(t * TAU * 1.7 + phase * 0.7) * CHAOS_LIFT_AMP,
		sin(t * TAU * 0.9 + phase * 1.7) * CHAOS_SIDE
	)

# Единый источник высоты для _process и _on_beat.
static func cat_height(t: float, index: int) -> float:
	return lerpf(lift_at(t), CHAOS_LIFT_CENTER + chaos_offset(index, t).y, chaos_amount(t))

# Дыхание квадрата на бите, сходит на нет при слиянии.
static func orbit_scale(flash: float, merge: float) -> float:
	return 1.0 + (ORBIT_PULSE - 1.0) * clampf(flash, 0.0, 1.0) * (1.0 - clampf(merge, 0.0, 1.0))

# Волна масштаба: каждый следующий кот отстаёт на 0.12 с.
static func scale_wave(t: float, index: int) -> float:
	return 1.0 + SCALE_WAVE_AMP * sin((t - float(index) * SCALE_WAVE_STAGGER) * SCALE_WAVE_FREQ)
