extends Node
## Слоты сохранений (3 шт.) + "последний" слот для кнопки Продолжить.

signal game_saved(slot: int)

const SLOT_COUNT := 3
const META_PATH := "user://last_slot.cfg"

func slot_path(slot: int) -> String:
	return "user://save_%d.json" % slot

func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))

func has_any_save() -> bool:
	for i in range(SLOT_COUNT):
		if has_save(i):
			return true
	return false

func get_last_slot() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(META_PATH) != OK:
		return -1
	var s: int = cfg.get_value("meta", "last_slot", -1)
	return s if has_save(s) else -1

func _set_last_slot(slot: int) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "last_slot", slot)
	cfg.save(META_PATH)

func read_slot(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f := FileAccess.open(slot_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func save_to_slot(slot: int) -> void:
	var data := GameState.to_dict()
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось сохранить в слот %d" % slot)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	_set_last_slot(slot)
	game_saved.emit(slot)

func delete_slot(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(slot_path(slot)))

func load_slot(slot: int) -> bool:
	var d := read_slot(slot)
	if d.is_empty():
		return false
	GameState.from_dict(d)
	_set_last_slot(slot)
	return true

## Слот, в который сохраняем "текущую" игру (автосохранение).
var active_slot := 0

func autosave() -> void:
	save_to_slot(active_slot)

func first_free_slot() -> int:
	for i in range(SLOT_COUNT):
		if not has_save(i):
			return i
	return 0
