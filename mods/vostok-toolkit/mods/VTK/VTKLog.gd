extends RefCounted
## Единая точка отладочного вывода мода.
## По умолчанию выключена: print() в релизе - это шум в консоли и логе игры,
## а также утечка внутренних путей. Включается галочкой "Debug log" в MCM.

static var enabled := false
static var _warned: Dictionary = {}

static func log(msg) -> void:
	if enabled:
		print(msg)

## Безусловная ошибка. Пути, где отказала запись данных игрока, обязаны
## оставить след в обычном логе: log() молчит без галочки Debug log, а
## потеря сета не должна зависеть от настройки. push_error вырезается в
## release-сборке Godot, поэтому печатаем и им, и print().
## Имя функции - error, а не fail: push_error печатает бэктрейс с именем
## вызванной функции, а стенд .check валит прогон на любой подстроке FAIL
## (match в PowerShell регистронезависимый). Сообщения тоже не должны
## содержать слово failed - ни в коде, ни в тексте.
static func error(msg: String) -> void:
	push_error("[VTK] " + msg)
	print("[VTK] " + msg)

## Единый fail-closed резолв привязок внутрь игры: о промахе сообщаем один
## раз на путь (V11), чтобы обновление игры не превращалось в молчание.
static func warn_once(path: String, msg: String = "") -> void:
	if not enabled:
		return
	if _warned.has(path):
		return
	_warned[path] = true
	print("[VTK][WARN] " + (msg if msg != "" else ("missing: " + path)))
