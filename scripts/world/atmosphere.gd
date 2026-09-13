extends CanvasLayer
## Освещение по времени суток, погода (GPU-частицы, шейдерный туман, вспышки),
## пост-обработка (bloom, виньетка, тонировка), звёзды, эхо, листья.

const TEX_GLOW := preload("res://assets/textures/particle_glow.png")
const TEX_RAIN := preload("res://assets/textures/raindrop.png")
const TEX_PETAL := preload("res://assets/textures/petal.png")
const SH_FOG := preload("res://shaders/fog.gdshader")
const SH_POST := preload("res://shaders/post.gdshader")
const SH_RAIN := preload("res://shaders/rain.gdshader")

var _modulate: CanvasModulate
var _overlay: Control
var _fog_rect: ColorRect
var _fog_mat: ShaderMaterial
var _post_rect: ColorRect
var _post_mat: ShaderMaterial
var _rain: GPUParticles2D
var _snow: GPUParticles2D
var _petals: GPUParticles2D
var _stars: Array = []
var _t := 0.0
var _cur_light := Color(1, 1, 1)
var _fog_a := 0.0
var _dark_a := 0.0
var _flash := 0.0
var _rain_rect: ColorRect
var _rain_mat: ShaderMaterial
var _rain_a := 0.0
var _storm := false
var _star_a := 0.0
var _silence_a := 0.0
var _thunder_timer := 5.0
var _echo_timer := 60.0
var _echo: Dictionary = {}
var _leaf_timer := 4.0
var _leaves: Array = []

func _ready() -> void:
	layer = 5
	# слой частиц погоды (в экранных координатах)
	# дождь — шейдерный слой (косые штрихи), брызги — частицы у земли
	_rain_rect = ColorRect.new()
	_rain_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rain_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rain_mat = ShaderMaterial.new()
	_rain_mat.shader = SH_RAIN
	_rain_rect.material = _rain_mat
	add_child(_rain_rect)
	_rain = _make_weather_particles(TEX_GLOW, 120, Vector3(0, -30, 0), 0.5, 0.05, 0.12, Color(0.8, 0.95, 1.0, 0.5))
	_rain.position = Vector2(640, 720)
	(_rain.process_material as ParticleProcessMaterial).emission_box_extents = Vector3(900, 260, 0)
	(_rain.process_material as ParticleProcessMaterial).gravity = Vector3(0, 120, 0)
	(_rain.process_material as ParticleProcessMaterial).spread = 60.0
	_snow = _make_weather_particles(TEX_GLOW, 220, Vector3(8, 34, 0), 11.0, 0.10, 0.26, Color(0.9, 0.97, 1.0, 0.85))
	_petals = _make_weather_particles(TEX_GLOW, 140, Vector3(24, 40, 0), 9.0, 0.10, 0.22, Color(0.75, 1.0, 0.9, 0.85))
	add_child(_rain)
	add_child(_snow)
	add_child(_petals)
	# туман
	_fog_rect = ColorRect.new()
	_fog_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = SH_FOG
	_fog_rect.material = _fog_mat
	add_child(_fog_rect)
	# overlay для звёзд/вспышек/эха
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	# пост-обработка
	_post_rect = ColorRect.new()
	_post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = SH_POST
	_post_rect.material = _post_mat
	add_child(_post_rect)

	for i in range(90):
		_stars.append(Vector3(randf(), randf() * 0.65, randf()))
	GameState.weather_changed.connect(_on_weather)
	GameState.phase_changed.connect(_on_phase)
	_on_weather(GameState.weather)
	_cur_light = _light_for_time(GameState.time_of_day)
	_echo_timer = randf_range(40.0, 120.0)
	Settings.settings_changed.connect(_apply_quality)
	_apply_quality()

func _make_weather_particles(tex: Texture2D, amount: int, vel: Vector3, life: float, smin: float, smax: float, col: Color) -> GPUParticles2D:
	var p := GPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.texture = tex
	p.emitting = false
	p.preprocess = life
	p.position = Vector2(640, -40)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(900, 20, 0)
	pm.direction = vel.normalized()
	pm.spread = 4.0
	pm.initial_velocity_min = vel.length() * 0.8
	pm.initial_velocity_max = vel.length() * 1.2
	pm.gravity = Vector3(0, 0, 0)
	pm.scale_min = smin
	pm.scale_max = smax
	pm.color = col
	pm.angle_min = -30
	pm.angle_max = 30
	if tex == TEX_PETAL or tex == TEX_GLOW:
		pm.turbulence_enabled = true
		pm.turbulence_noise_strength = 3.0
		pm.turbulence_noise_scale = 3.0
		pm.angular_velocity_min = -90
		pm.angular_velocity_max = 90
	p.process_material = pm
	return p

func _apply_quality() -> void:
	var q := clampi(Settings.particle_quality, 0, 2)
	_post_rect.visible = q >= 1
	_fog_rect.visible = q >= 1
	var muls: Array[float] = [0.25, 0.55, 1.0]
	var blooms: Array[float] = [0.3, 0.5, 0.65]
	var mul: float = muls[q]
	_snow.amount_ratio = mul
	_petals.amount_ratio = mul
	_post_mat.set_shader_parameter("bloom_strength", blooms[q])
	_post_mat.set_shader_parameter("brightness", Settings.brightness)

func attach_modulate(m: CanvasModulate) -> void:
	_modulate = m

func _light_for_time(t: float) -> Color:
	var keys := [
		[0.0, Color(0.34, 0.50, 0.58)],
		[4.5, Color(0.36, 0.52, 0.60)],
		[6.0, Color(0.55, 0.62, 0.66)],
		[8.0, Color(0.70, 0.80, 0.80)],
		[12.0, Color(0.76, 0.86, 0.84)],
		[16.5, Color(0.70, 0.78, 0.78)],
		[18.0, Color(0.60, 0.60, 0.68)],
		[19.5, Color(0.46, 0.54, 0.66)],
		[21.5, Color(0.36, 0.50, 0.60)],
		[24.0, Color(0.34, 0.50, 0.58)],
	]
	for i in range(keys.size() - 1):
		var k0: float = keys[i][0]
		var k1: float = keys[i + 1][0]
		if t >= k0 and t <= k1:
			var c0: Color = keys[i][1]
			var c1: Color = keys[i + 1][1]
			return c0.lerp(c1, smoothstep(0.0, 1.0, (t - k0) / (k1 - k0)))
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
	_rain.emitting = w == "rain" or w == "storm"
	_snow.emitting = w == "snow"
	_petals.emitting = w == "bloom"
	_update_mood()

func _on_phase(_p: String) -> void:
	_update_mood()

func _update_mood() -> void:
	var w := GameState.weather
	var p := GameState.get_phase()
	if w == "silence": AudioManager.set_mood("silence")
	elif w == "fog": AudioManager.set_mood("fog")
	elif w == "rain" or w == "storm": AudioManager.set_mood("rain")
	elif p == "night" or p == "evening": AudioManager.set_mood("night")
	else: AudioManager.set_mood("day")

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	var w := GameState.weather
	var phase := GameState.get_phase()
	_fog_a = move_toward(_fog_a, 1.0 if w == "fog" else 0.0, delta * 0.15)
	_dark_a = move_toward(_dark_a, (0.2 if w == "rain" else (0.35 if w == "storm" else 0.0)), delta * 0.1)
	_silence_a = move_toward(_silence_a, 1.0 if w == "silence" else 0.0, delta * 0.2)
	_star_a = move_toward(_star_a, 1.0 if phase == "night" else 0.0, delta * 0.1)
	var tinted := _light_for_time(GameState.time_of_day).darkened(_dark_a)
	if w == "bloom": tinted = tinted.lerp(Color(1.0, 0.9, 0.85), 0.25)
	if w == "silence": tinted = tinted.lerp(Color(0.85, 0.85, 0.88), 0.4 * _silence_a)
	if w == "fog": tinted = tinted.lerp(Color(0.9, 0.9, 0.95), 0.3 * _fog_a)
	if w == "snow": tinted = tinted.lerp(Color(0.9, 0.93, 1.0), 0.3)
	_cur_light = _cur_light.lerp(tinted, delta * 0.4)
	if _modulate != null:
		_modulate.color = _cur_light
	if _fog_rect.visible:
		_fog_mat.set_shader_parameter("density", _fog_a)
	elif _fog_a > 0.01:
		pass
	# пост-обработка подстраивается под фазу
	var tint := Color(0.90, 1.0, 1.0) if phase != "night" else Color(0.85, 0.98, 1.05)
	_post_mat.set_shader_parameter("tint", tint)
	_post_mat.set_shader_parameter("vignette", 0.3 + 0.2 * _star_a + 0.15 * _dark_a)
	_post_mat.set_shader_parameter("saturation", 1.1 - 0.35 * _silence_a - 0.15 * _fog_a)
	# гроза
	_flash = maxf(_flash - delta * 2.5, 0.0)
	var want_rain := 0.0
	if GameState.weather == "rain": want_rain = 0.55
	elif GameState.weather == "storm": want_rain = 1.0
	_rain_a = move_toward(_rain_a, want_rain, delta * 0.35)
	_rain_mat.set_shader_parameter("intensity", _rain_a)
	_rain_mat.set_shader_parameter("wind", -0.12 - 0.25 * _rain_a + sin(Time.get_ticks_msec() * 0.0004) * 0.05)
	_rain.amount_ratio = clampf(_rain_a, 0.05, 1.0) * (0.5 + 0.5 * float(Settings.particle_quality) / 2.0)
	if w == "storm":
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_thunder_timer = randf_range(6.0, 16.0)
			_flash = 1.0
			get_tree().create_timer(randf_range(0.4, 1.2)).timeout.connect(func(): AudioManager.play_sfx("thunder", -8.0, randf_range(0.6, 0.9)))
	# эхо
	_echo_timer -= delta
	if _echo_timer <= 0.0:
		_echo_timer = randf_range(60.0, 150.0)
		_echo = {"pos": Vector2(randf_range(0.2, 0.8), randf_range(0.25, 0.75)), "t": 3.0}
	if not _echo.is_empty():
		_echo["t"] -= delta
		if _echo["t"] <= 0.0: _echo = {}
	# листья
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
	if _star_a > 0.01:
		for i in range(_stars.size()):
			var s: Vector3 = _stars[i]
			var tw: float = 0.5 + 0.5 * sin(_t * (1.0 + s.z) + i * 0.7)
			var r := 1.0 + s.z * 1.2 + tw * 0.5
			_overlay.draw_circle(Vector2(s.x, s.y) * sz, r * 2.5, Color(1, 1, 0.95, 0.06 * _star_a * tw))
			_overlay.draw_circle(Vector2(s.x, s.y) * sz, r, Color(1, 1, 0.95, 0.5 * _star_a * (0.4 + 0.6 * tw)))
	if not _fog_rect.visible and _fog_a > 0.01:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.88, 0.9, 0.96, 0.45 * _fog_a))
	if _dark_a > 0.001:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.15, 0.2, 0.3, _dark_a * 0.45))
	if _silence_a > 0.01:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.95, 0.95, 0.97, 0.12 * _silence_a))
	for l in _leaves:
		var p: Vector2 = l["pos"] * sz
		var lt: float = l["t"]
		_overlay.draw_set_transform(p, lt * 3.0, Vector2(1.0, 0.5))
		var c := Color(1.0, 0.78, 0.86, 0.8) if l["petal"] else Color(0.7, 0.8, 0.45, 0.8)
		_overlay.draw_circle(Vector2.ZERO, 4.5, c)
		_overlay.draw_set_transform(Vector2.ZERO)
	if _flash > 0.01:
		_overlay.draw_rect(Rect2(Vector2.ZERO, sz), Color(1, 1, 1, _flash * 0.5))
	if not _echo.is_empty():
		var p: Vector2 = _echo["pos"] * sz
		var et: float = _echo["t"]
		var a := clampf(minf(et, 3.0 - et), 0.0, 1.0) * 0.35
		_overlay.draw_circle(p + Vector2(0, -20), 9, Color(0.8, 0.85, 1.0, a))
		_overlay.draw_rect(Rect2(p.x - 9, p.y - 12, 18, 18), Color(0.8, 0.85, 1.0, a))
		_overlay.draw_circle(p, 14, Color(0.8, 0.85, 1.0, a * 0.3))
