extends Node2D
## Светлячок: светится, пульсирует, оставляет шлейф, имеет характер движения.

signal caught(firefly)
signal fled(firefly)

var data: Dictionary
var color := Color(1, 0.85, 0.45)
var rarity := "common"
var emotion := "calm"
var _t := randf() * 100.0
var _seed := randf() * 100.0
var _vel := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_timer := 0.0
var _trail: Array = []
var _light: PointLight2D
var _player = null
var _state := "free" # free, fleeing, caught, releasing
var _flee_timer := 0.0
var _visible_scale := 0.0
var _hide_alpha := 1.0
var glow_size := 3.0
var _dim := 1.0

static var _light_tex: ImageTexture

func setup(d: Dictionary, player) -> void:
	data = d
	color = FireflyData.color_of(d)
	rarity = str(d.get("rarity", "common"))
	emotion = str(d.get("emotion", "calm"))
	_player = player
	glow_size = 3.0 if rarity == "common" else (4.2 if rarity == "rare" else 6.0)

func _ready() -> void:
	z_index = 5
	if _light_tex == null:
		var s := 64
		var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
		for y in range(s):
			for x in range(s):
				var dd := Vector2(x - s / 2.0, y - s / 2.0).length() / (s / 2.0)
				var a := clampf(1.0 - dd, 0.0, 1.0)
				img.set_pixel(x, y, Color(1, 1, 1, a * a))
		_light_tex = ImageTexture.create_from_image(img)
	_light = PointLight2D.new()
	_light.texture = _light_tex
	_light.color = color
	_light.texture_scale = 1.2 if rarity == "common" else (1.8 if rarity == "rare" else 2.6)
	_light.energy = 0.0
	add_child(_light)
	_new_wander()

func _new_wander() -> void:
	_wander = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10.0, 35.0)
	_wander_timer = randf_range(1.0, 3.0)

func _process(delta: float) -> void:
	_t += delta
	_visible_scale = move_toward(_visible_scale, 1.0 if _state != "caught" else 0.0, delta * 1.5)
	var pulse := 0.6 + 0.4 * sin(_t * (2.2 if rarity == "common" else 1.5) + _seed)
	var night_boost := 1.35 if GameState.get_phase() == "night" else 1.0
	_light.energy = pulse * _visible_scale * _hide_alpha * night_boost * (0.8 if rarity == "common" else 1.3) * _dim
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_new_wander()
	if _state == "caught":
		queue_redraw()
		return
	var desired := _wander
	if _player != null and _state == "free":
		var ppos: Vector2 = _player.global_position
		var to_p := ppos - global_position
		var d := to_p.length()
		var pspeed: float = _player.velocity.length()
		var idle: float = _player.get_idle_time()
		match emotion:
			"friendly":
				if d < 160 and d > 28: desired += to_p.normalized() * 30.0
			"shy":
				if d < 90 and pspeed > 90:
					_state = "fleeing"
					_flee_timer = 1.6
					_vel = -to_p.normalized() * 220.0
					fled.emit(self)
			"curious":
				if idle > 2.0 and d < 220 and d > 30: desired += to_p.normalized() * 40.0
			"secret":
				# держится на краю от игрока
				if d < 200: desired -= to_p.normalized() * 25.0
		# при долгом стоянии все подлетают ближе
		if idle > 5.0 and d < 260 and d > 26:
			desired += to_p.normalized() * 22.0
	if _state == "fleeing":
		_flee_timer -= delta
		if _flee_timer <= 0.0:
			_state = "free"
	# мягкое движение
	_vel = _vel.lerp(desired, delta * 1.2)
	var jitter := Vector2(sin(_t * 3.1 + _seed), cos(_t * 2.3 + _seed * 2.0)) * 14.0
	global_position += (_vel + jitter) * delta
	# держим внутри поляны
	var lim := Vector2(820, 560)
	if absf(global_position.x) > lim.x or absf(global_position.y) > lim.y:
		_wander = -global_position.normalized() * 25.0
		global_position = global_position.clamp(-lim, lim)
	# шлейф
	if _trail.is_empty() or _trail[-1].distance_to(global_position) > 3.0:
		_trail.append(global_position)
		if _trail.size() > 14:
			_trail.pop_front()
	queue_redraw()

func set_hidden_alpha(a: float) -> void:
	_hide_alpha = a

func set_dim(d: float) -> void:
	_dim = d

func try_catch() -> bool:
	if _state != "free":
		return false
	if emotion == "shy" and randf() < 0.25:
		_state = "fleeing"
		_flee_timer = 1.4
		var ppos: Vector2 = _player.global_position
		_vel = (global_position - ppos).normalized() * 220.0
		fled.emit(self)
		return false
	_state = "caught"
	caught.emit(self)
	var tw := create_tween()
	var ppos2: Vector2 = _player.global_position
	tw.tween_property(self, "global_position", ppos2 + Vector2(0, -14), 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(queue_free)
	return true

func play_release(from: Vector2) -> void:
	global_position = from
	_state = "releasing"
	_visible_scale = 1.0
	_vel = Vector2(randf_range(-40, 40), -70)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(func(): _state = "free")

func _draw() -> void:
	var pulse := 0.6 + 0.4 * sin(_t * (2.2 if rarity == "common" else 1.5) + _seed)
	var a := _visible_scale * _hide_alpha * _dim
	# шлейф
	for i in range(_trail.size()):
		var f := float(i) / maxf(_trail.size(), 1)
		var tp: Vector2 = _trail[i]
		var p := to_local(tp)
		draw_circle(p, glow_size * 0.5 * f, Color(color.r, color.g, color.b, 0.25 * f * a))
	# ореол
	draw_circle(Vector2.ZERO, glow_size * 4.0 * pulse + 2, Color(color.r, color.g, color.b, 0.10 * a))
	draw_circle(Vector2.ZERO, glow_size * 2.0 * pulse + 1, Color(color.r, color.g, color.b, 0.25 * a))
	# ядро
	draw_circle(Vector2.ZERO, glow_size * (0.8 + 0.3 * pulse), Color(color.r, color.g, color.b, 0.95 * a))
	draw_circle(Vector2.ZERO, glow_size * 0.45, Color(1, 1, 1, 0.9 * a))
	if rarity == "legendary":
		# лучики
		for i in range(6):
			var ang := _t * 0.8 + i * TAU / 6.0
			var r := glow_size * (3.0 + pulse * 1.5)
			draw_line(Vector2.ZERO, Vector2(cos(ang), sin(ang)) * r, Color(color.r, color.g, color.b, 0.35 * a), 1.0)
