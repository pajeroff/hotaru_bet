extends CanvasLayer
## Освещение по времени суток, погода (частицы, вспышки, туман), звёзды, эхо, листья.

var _modulate: CanvasModulate
var _overlay: Control # рисует погоду поверх мира (экранное пространство)
var _t := 0.0
var _cur_light := Color(1, 1, 1)
var _target_light := Color(1, 1, 1)
var _particles: Array = []
var _stars: Array = []
var _fog_a := 0.0
var _rain_a := 0.0
var _snow_a := 0.0
var _petal_a := 0.0
var _dark_a := 0.0
var _flash := 0.0
var _thunder_timer := 5.0
var _echo_timer := 60.0
var _echo: Dictionary = {}
var _leaf_timer := 4.0
var _leaves: Array = []
var _star_a := 0.0
var _silence_a := 0.0

func _ready() -> void:
	layer = 5
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	for i in range(120):
		_stars.append(Vector2(randf(), randf() * 0.6))
	for i in range(220):
		_particles.append(Vector2(randf(), randf()))
	GameState.weather_changed.connect(_on_weather)
	GameState.phase_changed.connect(_on_phase)
	_on_weather(GameState.weather)
	_cur_light = _light_for_time(GameState.time_of_day)
	_echo_timer = randf_range(40.0, 120.0)

func attach_modulate(m: CanvasModulate) -> void:
	_modulate = m

func _light_for_time(t: float) -> Color:
	# ключевые точки суток
	var keys := [
		[0.0, Color(0.40, 0.45, 0.72)],
		[4.5, Color(0.42, 0.47, 0.74)],
		[6.0, Color(0.92, 0.72, 0.70)],
		[8.0, Color(1.00, 0.94, 0.86)],
		[12.0, Color(1.00, 1.00, 0.98)],
		[16.5, Color(1.00, 0.96, 0.88)],
		[18.0, Color(1.00, 0.80, 0.58)],
		[19.5, Color(0.80, 0.60, 0.62)],
		[21.5, Color(0.48, 0.50, 0.76)],
		[24.0, Color(0.40, 0.45, 0.72)],
	]
	for i in range(keys.size() - 1):
		if t >= keys[i][0] and t <= keys[i + 1][0]:
			var k0: float = keys[i][0]
			var k1: float = keys[i + 1][0]
			var c0: Color = keys[i][1]
			var c1: Color = keys[i + 1][1]
			var f := (t - k0) / (k1 - k0)
			return c0.lerp(c1, smoothstep(0.0, 1.0, f))
	return keys[0][1]

func _on_weather(w: String) -> void:
	match w:
		"clear": AudioManager.set_ambient("wind", 0.35)
		"fog": AudioManager.set_ambient("fog", 0.35)
		"rain": AudioManager.set_ambient("rain", 0.45)
		"storm": AudioManager.set_ambient("storm", 0.6)
		"snow": AudioManager.set_ambient("snow", 0.2)
		"bloom": AudioManager.set_ambient("bloom", 0.3)
		"silence": AudioManager.set_ambient("silence", 0.15)
	_update_mood()

func _on_phase(_p: String) -> void:
	_update_mood()

func _update_mood() -> void:
	var w := GameState.weather
	var p := GameState.get_phase()
	if w == "silence":
		AudioManager.set_mood("silence")
	elif w == "fog":
		AudioManager.set_mood("fog")
	elif w == "rain" or w == "storm":
		AudioManager.set_mood("rain")
	elif p == "night" or p == "evening":
		AudioManager.set_mood("night")
	else:
		AudioManager.set_mood("day")

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	var w := GameState.weather
	var phase := GameState.get_phase()
	_target_light = _light_for_time(GameState.time_of_day)
	_fog_a = move_toward(_fog_a, 1.0 if w == "fog" else 0.0, delta * 0.15)
	_rain_a = move_toward(_rain_a, 1.0 if (w == "rain" or w == "storm") else 0.0, delta * 0.3)
	_snow_a = move_toward(_snow_a, 1.0 if w == "snow" else 0.0, delta * 0.2)
	_petal_a = move_toward(_petal_a, 1.0 if w == "bloom" else 0.0, delta * 0.2)
	_dark_a = move_toward(_dark_a, (0.18 if w == "rain" else (0.3 if w == "storm" else 0.0)), delta * 0.1)
	_silence_a = move_toward(_silence_a, 1.0 if w == "silence" else 0.0, delta * 0.2)
	_star_a = move_toward(_star_a, 1.0 if phase == "night" else 0.0, delta * 0.1)
	var tinted := _target_light.darkened(_dark_a)
	if w == "bloom":
		tinted = tinted.lerp(Color(1.0, 0.9, 0.85), 0.25)
	if w == "silence":
		tinted = tinted.lerp(Color(0.85, 0.85, 0.88), 0.4 * _silence_a)
	if w == "fog":
		tinted = tinted.lerp(Color(0.9, 0.9, 0.95), 0.3 * _fog_a)
	_cur_light = _cur_light.lerp(tinted, delta * 0.4)
	if _modulate != null:
		var b := Settings.brightness
		_modulate.color = Color(_cur_light.r * b, _cur_light.g * b, _cur_light.b * b)
	# частицы
	var sz := _overlay.size
	if sz.x <= 0: sz = Vector2(1280, 720)
	var speed_y := 0.0
	var speed_x := 0.0
	if _rain_a > 0.01:
		speed_y = 1.6; speed_x = 0.15
	elif _snow_a > 0.01:
		speed_y = 0.08; speed_x = 0.03
	elif _petal_a > 0.01:
		speed_y = 0.12; speed_x = 0.08
	for i in range(_particles.size()):
		var p: Vector2 = _particles[i]
		p.y += speed_y * delta
		p.x += (speed_x + sin(_t + i) * 0.03) * delta
		if p.y > 1.0: p.y -= 1.0; p.x = randf()
		if p.x > 1.0: p.x -= 1.0
		_particles[i] = p
	# гроза: вспышки
	_flash = maxf(_flash - delta * 2.5, 0.0)
	if w == "storm":
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = randf_range(6.0, 16.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 1.2)).timeout.connect(func(): AudioManager.play_sfx("thunder", -8.0, randf_range(0.6, 0.9)))
	# эхо другого игрока
	_echo_timer -= delta
	if _echo_timer <= 0.0:
		_echo_timer = randf_range(60.0, 150.0)
		_echo = {"pos": Vector2(randf_range(0.2, 0.8), randf_range(0.25, 0.75)), "t": 3.0}
	if not _echo.is_empty():
		_echo["t"] -= delta
		if _echo["t"] <= 0.0: _echo = {}
	# листья/лепестки время от времени
	_leaf_timer -= delta
	if _leaf_timer <= 0.0:
		_leaf_timer = randf_range(3.0, 9.0)
		_leaves.append({"pos": Vector2(-0.05, randf_range(0.1, 0.8)), "seed": randf() * 10.0, "t": 0.0, "petal": randf() < 0.4 or w == "bloom"})
	for l in _leaves:
		l["t"] += delta
		var lt: float = l["t"]
		var lsd: float = l["seed"]
		l["pos"] += Vector2(0.06, 0.02 + sin(lt * 2.0 + lsd) * 0.03) * delta
	_leaves = _leaves.filter(func(l): return l["pos"].x < 1.1)
	_overlay.queue_redraw()

func _draw_overlay() -> void:
	var sz := _overlay.size
	var quality: float = [0.4, 0.75, 1.0][clampi(Settings.particle_quality, 0, 2)]
	var count := int(_particles.size() * quality)
	# звёзды
	if _star_a > 0.01:
		for i in range(_stars.size()):
			var s: Vector2 = _stars[i]
			var tw: float = 0.5 + 0.5 * sin(_t * 1.5 + i * 0.7)
			_overlay.draw_circle(s * sz, 1.2 + tw * 0.6, Color(1, 1, 0.95, 0.35 * _star_a * (0.4 + 0.6 * tw)))
	# затемнение дождя
	if _dark_a > 0.001:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.2, 0.25, 0.35, _dark_a * 0.5))
	# дождь
	if _rain_a > 0.01:
		for i in range(count):
			var p: Vector2 = _particles[i] * sz
			_overlay.draw_line(p, p + Vector2(-3, 16), Color(0.8, 0.9, 1.0, 0.35 * _rain_a), 1.2)
	# снег
	if _snow_a > 0.01:
		for i in range(count):
			var p: Vector2 = _particles[i] * sz
			_overlay.draw_circle(p, 2.0 + fmod(i, 3), Color(1, 1, 1, 0.6 * _snow_a))
	# лепестки
	if _petal_a > 0.01:
		for i in range(int(count * 0.4)):
			var p: Vector2 = _particles[i] * sz
			var ang := _t * 2.0 + i
			_overlay.draw_set_transform(p, ang, Vector2(1.0, 0.6))
			_overlay.draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.78, 0.86, 0.7 * _petal_a))
			_overlay.draw_set_transform(Vector2.ZERO)
	# туман
	if _fog_a > 0.01:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.9, 0.9, 0.95, 0.35 * _fog_a))
		for i in range(8):
			var y := sz.y * (i / 8.0) + sin(_t * 0.15 + i) * 30.0
			var x := fmod(_t * 12.0 * (1.0 + i * 0.1) + i * 300.0, sz.x + 600.0) - 300.0
			_overlay.draw_circle(Vector2(x, y), 220, Color(1, 1, 1, 0.07 * _fog_a))
	# тишина: ровный свет, лёгкая вуаль
	if _silence_a > 0.01:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.95, 0.95, 0.97, 0.12 * _silence_a))
	# листья
	for l in _leaves:
		var p: Vector2 = l["pos"] * sz
		var lt: float = l["t"]
		_overlay.draw_set_transform(p, lt * 3.0, Vector2(1.0, 0.5))
		var c := Color(1.0, 0.78, 0.86, 0.8) if l["petal"] else Color(0.7, 0.8, 0.45, 0.8)
		_overlay.draw_circle(Vector2.ZERO, 4.5, c)
		_overlay.draw_set_transform(Vector2.ZERO)
	# вспышка грозы
	if _flash > 0.01:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, _flash * 0.5))
	# эхо другого игрока
	if not _echo.is_empty():
		var p: Vector2 = _echo["pos"] * sz
		var et: float = _echo["t"]
		var a := clampf(minf(et, 3.0 - et), 0.0, 1.0) * 0.35
		_overlay.draw_circle(p + Vector2(0, -20), 9, Color(0.8, 0.85, 1.0, a))
		_overlay.draw_rect(Rect2(p.x - 9, p.y - 12, 18, 18), Color(0.8, 0.85, 1.0, a))
		_overlay.draw_circle(p, 14, Color(0.8, 0.85, 1.0, a * 0.3))
