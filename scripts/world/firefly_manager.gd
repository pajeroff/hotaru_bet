extends Node2D
## Спавнит светлячков по времени суток и погоде, обрабатывает ловлю и отпускание.

const FireflyScene := preload("res://scripts/entities/firefly.gd")

var player
var _flies: Array = []
var _spawn_timer := 0.0
var _sparks: Array = [] # оставшиеся искры после отпускания: {pos, t, color}
var _fog := 0.0
var nearest

func _ready() -> void:
	GameState.firefly_released.connect(_on_released)
	GameState.weather_changed.connect(func(_w): _spawn_timer = 0.5)

func _process(delta: float) -> void:
	_flies = _flies.filter(func(f): return is_instance_valid(f))
	var phase := GameState.get_phase()
	var weather := GameState.weather
	var target := FireflyData.target_count(phase, weather)
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = randf_range(1.0, 3.0)
		if _flies.size() < target:
			spawn_one()
		elif _flies.size() > target + 3:
			# лишние тихо улетают (исчезают за границей)
			var f = _flies.pop_back()
			var tw := f.create_tween()
			tw.tween_property(f, "modulate:a", 0.0, 2.0)
			tw.tween_callback(f.queue_free)
	# скрытные — видны только в тумане
	_fog = move_toward(_fog, 1.0 if weather == "fog" else 0.0, delta * 0.3)
	var over := GameState.jar_is_over()
	for f in _flies:
		if f.emotion == "secret":
			f.set_hidden_alpha(_fog)
		f.set_dim(0.55 if over else 1.0)
	# искры
	for s in _sparks:
		s["t"] -= delta
	_sparks = _sparks.filter(func(s): return s["t"] > 0.0)
	# ближайший для подсказки
	nearest = null
	if player != null:
		var best := 40.0
		for f in _flies:
			if f._state != "free" or (f.emotion == "secret" and _fog < 0.5):
				continue
			var d: float = f.global_position.distance_to(player.global_position)
			if d < best:
				best = d
				nearest = f
	queue_redraw()

func spawn_one() -> void:
	var kind := FireflyData.pick_kind(GameState.get_phase(), GameState.weather)
	var data := FireflyData.make(kind)
	var f = FireflyScene.new()
	f.setup(data, player)
	var p := Vector2.ZERO
	for i in range(10):
		p = Vector2(randf_range(-780, 780), randf_range(-520, 520))
		if p.length() > 120 and (player == null or p.distance_to(player.global_position) > 120):
			break
	if data["emotion"] == "secret" and player != null:
		p = player.global_position + Vector2(cos(randf() * TAU), sin(randf() * TAU)) * 260.0
	f.position = p
	add_child(f)
	_flies.append(f)

func try_catch() -> bool:
	if nearest == null:
		return false
	var f = nearest
	if f.try_catch():
		GameState.add_to_jar(f.data)
		AudioManager.play_sfx("chime", -4.0, randf_range(0.95, 1.08))
		if player.has_method("flash"):
			player.flash()
		_flies.erase(f)
		return true
	return false

func _on_released(data: Dictionary) -> void:
	if player == null:
		return
	var f = FireflyScene.new()
	f.setup(data, player)
	add_child(f)
	f.play_release(player.global_position + Vector2(0, -16))
	_flies.append(f)
	_sparks.append({"pos": player.global_position + Vector2(randf_range(-10, 10), -8), "t": 6.0, "color": FireflyData.color_of(data)})
	AudioManager.play_sfx("release", -6.0)

func _draw() -> void:
	for s in _sparks:
		var a := clampf(s["t"] / 6.0, 0.0, 1.0)
		var c: Color = s["color"]
		draw_circle(s["pos"], 6.0 + (1.0 - a) * 4.0, Color(c.r, c.g, c.b, 0.15 * a))
		draw_circle(s["pos"], 2.0, Color(c.r, c.g, c.b, 0.8 * a))

func get_count() -> int:
	return _flies.size()
