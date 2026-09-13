extends Node
## Инвентарь: 20 ячеек рюкзака + 5 ячеек быстрого доступа; активный предмет отображается в руке персонажа.

signal changed
signal active_changed(item_id: String)

const BAG_SIZE := 20
const HOTBAR_SIZE := 5

## Каталог предметов: имя (ключ локализации), иконка, тип (tool/consumable/misc), описание.
const ITEMS := {
	"lantern": {"name": "IT_lantern", "icon": "res://assets/items/lantern.png", "kind": "tool", "desc": "ITD_lantern"},
	"net": {"name": "IT_net", "icon": "res://assets/items/net.png", "kind": "tool", "desc": "ITD_net"},
	"jar": {"name": "IT_jar", "icon": "res://assets/items/jar.png", "kind": "tool", "desc": "ITD_jar"},
	"bell": {"name": "IT_bell", "icon": "res://assets/items/bell.png", "kind": "tool", "desc": "ITD_bell"},
	"crystal": {"name": "IT_crystal", "icon": "res://assets/items/crystal.png", "kind": "misc", "desc": "ITD_crystal"},
	"snack": {"name": "IT_snack", "icon": "res://assets/items/snack.png", "kind": "consumable", "desc": "ITD_snack"},
	"flute": {"name": "IT_flute", "icon": "res://assets/items/flute.png", "kind": "tool", "desc": "ITD_flute"},
	"map": {"name": "IT_map", "icon": "res://assets/items/map.png", "kind": "misc", "desc": "ITD_map"},
}

var bag: Array = []       # Array[String] ("" — пусто)
var hotbar: Array = []    # Array[String], HOTBAR_SIZE
var active_slot := 0
var _icons := {}

func _ready() -> void:
	reset()

func reset() -> void:
	bag.clear()
	hotbar.clear()
	for i in range(BAG_SIZE):
		bag.append("")
	for i in range(HOTBAR_SIZE):
		hotbar.append("")
	hotbar[0] = "lantern"
	hotbar[1] = "net"
	hotbar[2] = "jar"
	bag[0] = "bell"
	bag[1] = "flute"
	bag[2] = "snack"
	bag[3] = "map"
	active_slot = 0
	changed.emit()
	active_changed.emit(active_item())

func icon(item_id: String) -> Texture2D:
	if item_id == "" or not ITEMS.has(item_id):
		return null
	if not _icons.has(item_id):
		var path: String = ITEMS[item_id]["icon"]
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		else:
			var img := Image.new()
			if img.load(path) == OK:
				tex = ImageTexture.create_from_image(img)
		_icons[item_id] = tex
	return _icons[item_id]

func active_item() -> String:
	return str(hotbar[active_slot]) if active_slot >= 0 and active_slot < hotbar.size() else ""

func set_active(slot: int) -> void:
	slot = clampi(slot, 0, HOTBAR_SIZE - 1)
	if slot == active_slot:
		return
	active_slot = slot
	changed.emit()
	active_changed.emit(active_item())

func has_item(item_id: String) -> bool:
	return bag.has(item_id) or hotbar.has(item_id)

func add_item(item_id: String) -> bool:
	for i in range(HOTBAR_SIZE):
		if hotbar[i] == "":
			hotbar[i] = item_id
			changed.emit()
			return true
	for i in range(BAG_SIZE):
		if bag[i] == "":
			bag[i] = item_id
			changed.emit()
			return true
	return false

## Обмен содержимого двух ячеек. Контейнер: "bag" или "hotbar".
func swap(c1: String, i1: int, c2: String, i2: int) -> void:
	var a1: Array = bag if c1 == "bag" else hotbar
	var a2: Array = bag if c2 == "bag" else hotbar
	if i1 < 0 or i2 < 0 or i1 >= a1.size() or i2 >= a2.size():
		return
	var tmp = a1[i1]
	a1[i1] = a2[i2]
	a2[i2] = tmp
	changed.emit()
	active_changed.emit(active_item())

func to_dict() -> Dictionary:
	return {"bag": bag.duplicate(), "hotbar": hotbar.duplicate(), "active": active_slot}

func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		reset()
		return
	bag = (d.get("bag", []) as Array).duplicate()
	hotbar = (d.get("hotbar", []) as Array).duplicate()
	while bag.size() < BAG_SIZE:
		bag.append("")
	while hotbar.size() < HOTBAR_SIZE:
		hotbar.append("")
	active_slot = clampi(int(d.get("active", 0)), 0, HOTBAR_SIZE - 1)
	changed.emit()
	active_changed.emit(active_item())
