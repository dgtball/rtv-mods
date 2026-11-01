extends RefCounted

## Общие части HUD-виджетов счётчика убийств и ленты: подложка-плашка,
## чтение убежища из gameData и каденция тика 0.5 с. Обе копии уже расходились
## молча (порядок _reseed в §4.4 аудита), поэтому правила живут здесь.
## Плашка и убежище - static без состояния; тик - класс Ticker, у каждого
## виджета свой экземпляр. Ни load(), ни путей внутрь игры, поэтому покрыто
## headless-тестом test_feed.gd (t_hud_shared).

# Чёрная подложка 0.45: без неё светлый HUD на солнце съедает надпись.
const PLATE_ALPHA := 0.45
const PLATE_PAD_X := 6.0
const TICK_SEC := 0.5

static func plaque_style(top: float = 0.0, bottom: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, PLATE_ALPHA)
	sb.content_margin_left = PLATE_PAD_X
	sb.content_margin_right = PLATE_PAD_X
	sb.content_margin_top = top
	sb.content_margin_bottom = bottom
	return sb

# Цепочка Interface -> gameData -> shelter. Принимает и живой узел, и словарь:
# headless-тест подставляет {"gameData": {"shelter": true}}.
static func in_shelter(iface) -> bool:
	if iface == null:
		return false
	var gd = iface.get("gameData")
	if gd == null:
		return false
	return bool(gd.get("shelter"))

# Read gameData.shelter не каждый кадр, а раз в 0.5 с: тик выше кадровой
# частоты. Остаток переносится, поэтому каденция не зависит от FPS.
class Ticker extends RefCounted:
	var accum: float = 0.0
	var interval: float = TICK_SEC

	func _init(step_sec: float = TICK_SEC) -> void:
		interval = step_sec

	func step(delta: float) -> bool:
		accum += delta
		if accum < interval:
			return false
		accum = 0.0
		return true
