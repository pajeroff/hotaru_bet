extends Node
## Система сохранений: до 12 именованных слотов (user://saves/*.json), «последнее» для кнопки Продолжить,
## автосохранение, отслеживание времени с последнего сохранения.

signal game_saved(slot_id: String)
signal saves_changed

const SAVE_DIR := "user://saves"
const META_PATH := "user://last_save.cfg"
const MAX_SLOTS := 12
const WARN_AFTER_SEC := 120.0

var active_slot := ""          # id текущего сохранения (имя файла без .json)
var active_name := ""          # отображаемое имя
var _last_save_time := -1.0    # Time.get_ticks_msec()/1000 момента последнего сохранения (или старта игры)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))

# ---------- утилиты ----------
func _path(slot_id: String) -> String:
	return "%s/%s.json" % [SAVE_DIR, slot_id]

func _new_id() -> String:
	return "save_%d_%04d" % [Time.get_unix_time_from_system(), randi() % 10000]

func mark_session_start() -> void:
	_last_save_time = Time.get_ticks_msec() / 1000.0

func seconds_since_save() -> float:
	if _last_save_time < 0.0:
		return INF
	return Time.get_ticks_msec() / 1000.0 - _last_save_time

func needs_save_warning() -> bool:
	return GameState.running and seconds_since_save() > WARN_AFTER_SEC

# ---------- список ----------
func list_saves() -> Array:
	## Возвращает массив словарей метаданных, отсортированный по дате (новые первыми).
	var result: Array = []
	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			var id := f.trim_suffix(".json")
			var d := read_save(id)
			if not d.is_empty():
				var meta: Dictionary = d.get("meta", {})
				meta["id"] = id
				result.append(meta)
		f = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a, b): return float(a.get("saved_unix", 0)) > float(b.get("saved_unix", 0)))
	return result

func has_any_save() -> bool:
	return not list_saves().is_empty()

func read_save(slot_id: String) -> Dictionary:
	if slot_id == "" or not FileAccess.file_exists(_path(slot_id)):
		return {}
	var f := FileAccess.open(_path(slot_id), FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

func get_last_slot() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(META_PATH) != OK:
		return ""
	var s: String = str(cfg.get_value("meta", "last_slot", ""))
	return s if FileAccess.file_exists(_path(s)) else ""

func _set_last_slot(slot_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "last_slot", slot_id)
	cfg.save(META_PATH)

# ---------- запись ----------
func save_game(slot_id: String, save_name: String) -> String:
	## Сохраняет текущую игру. Пустой slot_id — создать новый файл. Возвращает id.
	if slot_id == "":
		slot_id = _new_id()
	var state := GameState.to_dict()
	var d := {
		"version": 2,
		"meta": {
			"name": save_name.strip_edges() if save_name.strip_edges() != "" else tr("SAVE_DEFAULT_NAME"),
			"saved_at": Time.get_datetime_string_from_system(false, true),
			"saved_unix": Time.get_unix_time_from_system(),
			"day": state.get("day", 1),
			"time_of_day": state.get("time_of_day", 7.0),
			"weather": state.get("weather", "clear"),
			"temple_level": state.get("temple_level", 0),
			"caught": state.get("total_caught", 0),
			"jar_count": (state.get("jar", []) as Array).size(),
		},
		"state": state,
	}
	var f := FileAccess.open(_path(slot_id), FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось записать сохранение %s" % slot_id)
		return ""
	f.store_string(JSON.stringify(d, "\t"))
	f.close()
	active_slot = slot_id
	active_name = str(d["meta"]["name"])
	_set_last_slot(slot_id)
	_last_save_time = Time.get_ticks_msec() / 1000.0
	game_saved.emit(slot_id)
	saves_changed.emit()
	return slot_id

func quick_save() -> bool:
	## Сохранить в активный слот (если есть). Возвращает false, если слота нет — нужно спросить имя.
	if active_slot == "":
		return false
	save_game(active_slot, active_name)
	return true

func autosave() -> void:
	if active_slot != "":
		save_game(active_slot, active_name)

func delete_save(slot_id: String) -> void:
	if FileAccess.file_exists(_path(slot_id)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_path(slot_id)))
	if active_slot == slot_id:
		active_slot = ""
		active_name = ""
	saves_changed.emit()

func rename_save(slot_id: String, new_name: String) -> void:
	var d := read_save(slot_id)
	if d.is_empty():
		return
	d["meta"]["name"] = new_name.strip_edges()
	var f := FileAccess.open(_path(slot_id), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))
	saves_changed.emit()

# ---------- загрузка ----------
func load_game(slot_id: String) -> bool:
	var d := read_save(slot_id)
	if d.is_empty():
		return false
	var state: Dictionary = d.get("state", d) # совместимость со старым форматом
	GameState.from_dict(state)
	active_slot = slot_id
	active_name = str(d.get("meta", {}).get("name", ""))
	_set_last_slot(slot_id)
	mark_session_start()
	return true

func start_new_session() -> void:
	active_slot = ""
	active_name = ""
	mark_session_start()

static func phase_for(t: float) -> String:
	if t < 5.0: return "night"
	if t < 7.0: return "dawn"
	if t < 11.0: return "morning"
	if t < 17.0: return "day"
	if t < 19.0: return "sunset"
	if t < 21.5: return "evening"
	return "night"
