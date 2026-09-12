extends Node
## Состояние текущей игры: время, погода, банка, храм.

signal phase_changed(phase: String)
signal weather_changed(weather: String)
signal jar_changed
signal temple_changed(level: int)
signal firefly_caught(data: Dictionary)
signal firefly_released(data: Dictionary)
signal day_changed(day: int)

const DAY_LENGTH_SEC := 20.0 * 60.0 # 20 реальных минут = 24 игровых часа
const JAR_SLOTS := 4
const PHASES := ["dawn", "morning", "day", "sunset", "evening", "night"]
const WEATHERS := ["clear", "fog", "rain", "storm", "snow", "bloom", "silence"]

var day := 1
var time_of_day := 7.0 # часы 0..24
var weather := "clear"
var season := "spring"
var player_position := Vector2(0, 80)
var jar: Array = [] # массив словарей светлячков
var total_caught := 0
var temple_level := 0 # 0 тусклый, 1 тлеющий, 2 яркий
var temple_energy := 0.0 # 0..1 внутри уровня
var lantern_on := false

var _weather_timer := 0.0
var _phase := ""
var _catch_idle_timer := 0.0
var running := false

func reset_new_game() -> void:
	day = 1
	time_of_day = 7.0
	weather = "clear"
	season = "spring"
	player_position = Vector2(0, 80)
	jar.clear()
	total_caught = 0
	temple_level = 0
	temple_energy = 0.15
	lantern_on = false
	_weather_timer = randf_range(2.0, 4.0)
	_phase = ""
	_catch_idle_timer = 0.0
	_emit_phase()
	jar_changed.emit()

func to_dict() -> Dictionary:
	return {
		"day": day, "time_of_day": time_of_day, "weather": weather, "season": season,
		"player_x": player_position.x, "player_y": player_position.y,
		"jar": jar.duplicate(true), "total_caught": total_caught,
		"temple_level": temple_level, "temple_energy": temple_energy,
		"lantern_on": lantern_on, "weather_timer": _weather_timer,
		"saved_at": Time.get_datetime_string_from_system(false, true),
	}

func from_dict(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	time_of_day = float(d.get("time_of_day", 7.0))
	weather = str(d.get("weather", "clear"))
	season = str(d.get("season", "spring"))
	player_position = Vector2(float(d.get("player_x", 0)), float(d.get("player_y", 80)))
	jar = d.get("jar", []).duplicate(true)
	total_caught = int(d.get("total_caught", 0))
	temple_level = int(d.get("temple_level", 0))
	temple_energy = float(d.get("temple_energy", 0.0))
	lantern_on = bool(d.get("lantern_on", false))
	_weather_timer = float(d.get("weather_timer", 3.0))
	_phase = ""
	_emit_phase()
	jar_changed.emit()
	weather_changed.emit(weather)
	temple_changed.emit(temple_level)

func _process(delta: float) -> void:
	if not running or get_tree().paused:
		return
	var game_hours := delta * Settings.get_time_scale() * 24.0 / DAY_LENGTH_SEC
	time_of_day += game_hours
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		day += 1
		day_changed.emit(day)
	_emit_phase()

	_weather_timer -= game_hours
	if _weather_timer <= 0.0:
		_pick_weather()

	# Храм медленно тускнеет без внимания
	_catch_idle_timer += game_hours
	if _catch_idle_timer > 6.0:
		temple_energy -= game_hours * 0.05
		if temple_energy < 0.0:
			if temple_level > 0:
				temple_level -= 1
				temple_energy = 0.9
				temple_changed.emit(temple_level)
			else:
				temple_energy = 0.0

func get_phase() -> String:
	var t := time_of_day
	if t < 5.0: return "night"
	if t < 7.0: return "dawn"
	if t < 11.0: return "morning"
	if t < 17.0: return "day"
	if t < 19.0: return "sunset"
	if t < 21.5: return "evening"
	return "night"

func _emit_phase() -> void:
	var p := get_phase()
	if p != _phase:
		_phase = p
		phase_changed.emit(p)

func _pick_weather() -> void:
	var weights := {"clear": 40, "fog": 14, "rain": 14, "bloom": 12, "storm": 6, "snow": 5, "silence": 5}
	var p := get_phase()
	if p == "night":
		weights["storm"] += 6
		weights["silence"] += 4
	if p == "dawn" or p == "morning":
		weights["fog"] += 10
	var total := 0
	for k in weights: total += weights[k]
	var r := randi() % total
	var chosen := "clear"
	for k in weights:
		r -= weights[k]
		if r < 0:
			chosen = k
			break
	if chosen == weather:
		chosen = "clear" if weather != "clear" else "bloom"
	weather = chosen
	_weather_timer = randf_range(1.5, 5.0)
	if weather == "silence":
		_weather_timer = randf_range(0.7, 1.5)
	weather_changed.emit(weather)

func get_time_string() -> String:
	var h := int(time_of_day)
	var m := int((time_of_day - h) * 60.0)
	return "%02d:%02d" % [h, m]

# ---------- Банка ----------

static func slot_cost(rarity: String) -> int:
	match rarity:
		"rare": return 2
		"legendary": return 3
	return 1

func jar_used_slots() -> int:
	var n := 0
	for f in jar:
		n += slot_cost(str(f.get("rarity", "common")))
	return n

func jar_is_over() -> bool:
	return jar_used_slots() > JAR_SLOTS

func can_fit(rarity: String) -> bool:
	return jar_used_slots() + slot_cost(rarity) <= JAR_SLOTS

func add_to_jar(data: Dictionary) -> void:
	jar.append(data.duplicate(true))
	total_caught += 1
	_catch_idle_timer = 0.0
	temple_energy += 0.2 + (0.2 if data.get("rarity") == "rare" else 0.0) + (0.5 if data.get("rarity") == "legendary" else 0.0)
	if temple_energy >= 1.0 and temple_level < 2:
		temple_level += 1
		temple_energy = 0.1
		temple_changed.emit(temple_level)
	temple_energy = minf(temple_energy, 1.0)
	jar_changed.emit()
	firefly_caught.emit(data)

func release_from_jar(index: int) -> Dictionary:
	if index < 0 or index >= jar.size():
		return {}
	var data: Dictionary = jar[index]
	jar.remove_at(index)
	jar_changed.emit()
	firefly_released.emit(data)
	return data

func get_summary() -> String:
	return "%s, %s, %s" % [tr("PLACE_glade"), tr("PHASE_" + get_phase()), tr("W_" + weather)]
