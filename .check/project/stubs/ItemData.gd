extends RefCounted
# Заглушка игрового предмета для test_items.gd: VTKItemStore читает каталог через
# get()/name/resource_path, поэтому здесь ровно эти поля. class_name не нужен -
# тест грузит файл через preload и на кэш классов не завязан (в отличие от
# SlotData, который модули создают по имени).

var name := ""
var resource_path := ""
var type := ""
var subtype := ""
var slots: Array = []
