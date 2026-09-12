extends Node2D
## Светлячок: светящееся ядро + PointLight2D + GPU-шлейф частиц; характер движения.

signal caught(firefly)
signal fled(firefly)

const TEX_LIGHT := preload("res://assets/textures/light_soft.png")
const TEX_GLOW := preload("res://assets/textures/particle_glow.png")

var data: Dictionary
var color := Color(1, 0.85, 0.45)
var rarity := "common"
var emotion := "calm"
var glow_size := 3.0
var _t := randf() * 100.0
var _seed := randf() * 100.0
var _vel := Vector2.ZERO
var _wander := Vector2.ZERO
var _wander_timer := 0.0
var _light: PointLight2D
var _core: Sprite2D
var _halo: Sprite2D
var _trail: GPUParticles2D
var _player = null
var _state := "free"
var _flee_timer := 0.0
var _visible_scale := 0.0
var _hide_alpha := 1.0
var _dim := 1.0
var _bob := 0.0

func setup(d: Dictionary, player) -> void:
	data = d
	color = FireflyData.color_of(d)
	rarity = str(d.get("rarity", "common"))
	emotion = str(d.get("emotion", "calm"))
	_player = player
	glow_size = 1.0 if rarity == "common" else (1.4 if rarity == "rare" else 2.0)

func _ready() -> void:
	z_index = 5
	_halo = Sprite2D.new()
	_halo.texture = TEX_GLOW
	_halo.scale = Vector2.ONE * glow_size * 0.9
	_halo.modulate = Color(color.r, color.g, color.b, 0.25)
	add_child(_halo)
	_core = Sprite2D.new()
	_core.texture = TEX_GLOW
	_core.scale = Vector2.ONE * glow_size * 0.28
	_core.modulate = Color(color.r * 0.7 + 0.3, color.g * 0.7 + 0.3, color.b * 0.7 + 0.3, 1)
	var outline := Sprite2D.new()
	outline.texture = TEX_GLOW
	outline.scale = Vector2.ONE * glow_size * 0.36
	outline.modulate = Color(color.r * 0.35, color.g * 0.3, color.b * 0.35, 0.55)
	outline.show_behind_parent = true
	_core.add_child(outline)
	add_child(_core)
	var q := clampi(Settings.particle_quality, 0, 2)
	_light = PointLight2D.new()
	_light.texture = TEX_LIGHT
	_light.color = color
	_light.texture_scale = 0.45 * glow_size
	_light.energy = 0.0
	_light.enabled = q >= 2 or rarity != "common"
	add_child(_light)
	_trail = GPUParticles2D.new()
	_trail.amount = (6 if rarity == "common" else 12) if q < 2 else (16 if rarity == "common" else 28)
	_trail.visible = q >= 1
	_trail.lifetime = 0.9
	_trail.texture = TEX_GLOW
	_trail.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 4.0
	pm.spread = 180.0
	pm.scale_min = 0.05 * glow_size
	pm.scale_max = 0.14 * glow_size
	var grad := Gradient.new()
	grad.set_color(0, Color(color.r, color.g, color.b, 0.7))
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	_trail.process_material = pm
	add_child(_trail)
	_new_wander()

func _new_wander() -> void:
	_wander = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(10.0, 35.0)
	_wander_timer = randf_range(1.0, 3.0)

func _process(delta: float) -> void:
	_t += delta
	_visible_scale = move_toward(_visible_scale, 1.0 if _state != "caught" else 0.0, delta * 1.5)
	var pulse := 0.6 + 0.4 * sin(_t * (2.2 if rarity == "common" else 1.5) + _seed)
	var night_boost := 1.25 if GameState.get_phase() == "night" else 1.0
	var a := _visible_scale * _hide_alpha * _dim
	_light.energy = pulse * a * night_boost * (0.35 if rarity == "common" else 0.55)
	_halo.modulate.a = 0.18 * a * pulse + 0.08 * a
	_halo.scale = Vector2.ONE * glow_size * (0.8 + 0.3 * pulse)
	_core.modulate.a = a
	_core.scale = Vector2.ONE * glow_size * (0.24 + 0.06 * pulse)
	_trail.emitting = a > 0.2 and _state != "caught"
	if rarity == "legendary":
		_halo.rotation += delta * 0.5
	_core.scale.x = _core.scale.x * (1.0 + 0.25 * absf(sin(_t * 20.0)))
	if _state == "caught":
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_new_wander()
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
				if d < 200: desired -= to_p.normalized() * 25.0
		if idle > 5.0 and d < 260 and d > 26:
			desired += to_p.normalized() * 22.0
	if _state == "fleeing":
		_flee_timer -= delta
		if _flee_timer <= 0.0:
			_state = "free"
	_vel = _vel.lerp(desired, delta * 1.2)
	var jitter := Vector2(sin(_t * 3.1 + _seed), cos(_t * 2.3 + _seed * 2.0)) * 14.0
	global_position += (_vel + jitter) * delta
	_bob = sin(_t * 2.0 + _seed) * 3.0
	_core.position.y = _bob
	_halo.position.y = _bob
	_light.position.y = _bob
	var lim := Vector2(1580, 1100)
	if absf(global_position.x) > lim.x or absf(global_position.y) > lim.y:
		_wander = -global_position.normalized() * 25.0
		global_position = global_position.clamp(-lim, lim)

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
	var ppos2: Vector2 = _player.global_position
	var tw := create_tween()
	tw.tween_property(self, "global_position", ppos2 + Vector2(0, -24), 0.35).set_trans(Tween.TRANS_SINE)
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
