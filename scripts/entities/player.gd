extends CharacterBody2D
## Хранитель: спрайтовые анимации ходьбы в 4 направлениях (8 направлений движения),
## мягкая тень, фонарь с тенями, пыль из-под ног.

signal moved(pos: Vector2)
signal idle_time_changed(t: float)

const SPEED := 150.0
const ACCEL := 9.0
const SHEET := preload("res://assets/sprites/player_sheet.png")
const TEX_LIGHT := preload("res://assets/textures/light_soft.png")
const TEX_SHADOW := preload("res://assets/textures/shadow_blob.png")
const TEX_GLOW := preload("res://assets/textures/particle_glow.png")
const FW := 192
const FH := 256
const DIR_NAMES: Array[String] = ["down", "left", "right", "up"]

var facing := Vector2.DOWN
var _row := 0 # 0 down, 1 left, 2 right, 3 up
var _walking := false
var _step_timer := 0.0
var _idle_t := 0.0
var _lantern: PointLight2D
var _lantern_glow: Sprite2D
var _sprite: AnimatedSprite2D
var _shadow: Sprite2D
var _dust: GPUParticles2D
var _flash: Sprite2D
var input_enabled := true
var _action := "" # "catch", "sit"
var _action_t := 0.0
var _sit_after := 12.0
var _bob_phase := 0.0
var _idle_phase := 0.0
var _hand: Sprite2D

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 9
	cs.shape = c
	cs.position = Vector2(0, -2)
	add_child(cs)

	_shadow = Sprite2D.new()
	_shadow.texture = TEX_SHADOW
	_shadow.scale = Vector2(0.42, 0.16)
	_shadow.position = Vector2(2, 2)
	_shadow.modulate = Color(0, 0, 0, 0.38)
	add_child(_shadow)

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.offset = Vector2(0, -FH * 0.5 + 24)
	_sprite.scale = Vector2(0.4, 0.4)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.animation = "idle_down"
	_sprite.play()
	add_child(_sprite)
	_hand = Sprite2D.new()
	_hand.scale = Vector2(0.28, 0.28)
	_hand.z_index = 1
	add_child(_hand)

	_lantern = PointLight2D.new()
	_lantern.texture = TEX_LIGHT
	_lantern.color = Color(1.0, 0.88, 0.65)
	_lantern.texture_scale = 2.6
	_lantern.energy = 0.0
	_lantern.position = Vector2(0, -14)
	_lantern.shadow_enabled = false
	add_child(_lantern)

	_lantern_glow = Sprite2D.new()
	_lantern_glow.texture = TEX_GLOW
	_lantern_glow.scale = Vector2(1.2, 1.2)
	_lantern_glow.modulate = Color(1.0, 0.85, 0.5, 0.0)
	_lantern_glow.position = Vector2(12, -18)
	add_child(_lantern_glow)

	_dust = GPUParticles2D.new()
	_dust.amount = 12
	_dust.lifetime = 0.7
	_dust.emitting = false
	_dust.texture = TEX_GLOW
	_dust.position = Vector2(0, 2)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 16.0
	pm.gravity = Vector3(0, 10, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.18
	pm.color = Color(0.6, 0.95, 0.9, 0.35)
	var dg := Gradient.new()
	dg.set_color(0, Color(0.6, 0.95, 0.9, 0.5))
	dg.set_color(1, Color(0.6, 0.95, 0.9, 0.0))
	var dgt := GradientTexture1D.new()
	dgt.gradient = dg
	pm.color_ramp = dgt
	_dust.process_material = pm
	_dust.material = _add_material()
	add_child(_dust)

	_flash = Sprite2D.new()
	_flash.texture = TEX_LIGHT
	_flash.modulate = Color(1, 0.95, 0.75, 0.0)
	_flash.position = Vector2(0, -24)
	_flash.scale = Vector2(0.6, 0.6)
	add_child(_flash)

	global_position = GameState.player_position
	Inventory.active_changed.connect(_on_item_changed)
	_on_item_changed(Inventory.active_item(), true)

func _frame(col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = SHEET
	at.region = Rect2(col * FW, row * FH, FW, FH)
	return at

func _build_frames() -> SpriteFrames:
	## Low-poly лист: сгенерированные кадры не совпадают по позе, поэтому для каждого направления
	## берём один устойчивый кадр (col 0) и делаем шаг процедурно (боб, наклон, качание).
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for r in range(4):
		var dir_name: String = DIR_NAMES[r]
		for prefix in ["walk_", "idle_"]:
			var an: String = prefix + dir_name
			sf.add_animation(an)
			sf.set_animation_speed(an, 1.0)
			sf.set_animation_loop(an, true)
			sf.add_frame(an, _frame(0, r))
	for extra in ["catch", "sit", "walk_lantern"]:
		sf.add_animation(extra)
		sf.set_animation_speed(extra, 1.0)
		sf.set_animation_loop(extra, extra != "catch")
		sf.add_frame(extra, _frame(0, 0))
	return sf

static func _add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m

func _hand_anchor() -> Vector2:
	match _row:
		1: return Vector2(-16, -14)
		2: return Vector2(16, -14)
		3: return Vector2(10, -18)
	return Vector2(14, -12)

func _on_item_changed(item_id: String, instant := false) -> void:
	_hand.texture = Inventory.icon(item_id)
	_hand.visible = item_id != "" and item_id != "jar"
	# фонарь горит только когда он в руке
	set_lantern(item_id == "lantern", instant)
	if item_id == "lantern" and not instant:
		AudioManager.play_sfx("lantern", -8.0, 1.2)

func set_lantern(on: bool, instant := false) -> void:
	GameState.lantern_on = on
	if _lantern == null or _lantern_glow == null:
		return
	var tw := create_tween().set_parallel(true)
	var d := 0.01 if instant else 0.5
	tw.tween_property(_lantern, "energy", 0.8 if on else 0.0, d).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_lantern_glow, "modulate:a", 0.8 if on else 0.0, d)
	if not instant:
		AudioManager.play_sfx("lantern", -6.0, 1.3 if on else 0.9)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = velocity.lerp(dir * SPEED, 1.0 - exp(-ACCEL * delta))
	move_and_slide()
	_walking = velocity.length() > 15.0
	if dir.length() > 0.1:
		facing = dir.normalized()
		# по диагонали показываем боковой ряд (он читается лучше), чисто вверх/вниз — фронтальный
		if absf(facing.x) > absf(facing.y) * 0.6:
			_row = 1 if facing.x < 0 else 2
		else:
			_row = 3 if facing.y < 0 else 0
	var dir_name: String = DIR_NAMES[_row]
	var anim: String = ("walk_" if _walking else "idle_") + dir_name
	if _walking and GameState.lantern_on and _row == 0:
		anim = "walk_lantern"
	if _action != "":
		_action_t -= delta
		if _walking or _action_t <= 0.0:
			_action = ""
		else:
			anim = _action
	elif not _walking and _idle_t > _sit_after:
		_action = "sit"
		_action_t = 9999.0
		anim = "sit"
	if _sprite.animation != anim:
		_sprite.play(anim)
	_hand.z_index = -1 if _row == 3 else 1
	_hand.flip_h = _row == 1
	_sprite.speed_scale = clampf(velocity.length() / SPEED, 0.7, 1.15) if _walking else 1.0
	# лёгкое "дыхание" стоя
	# процедурная "жизнь" поверх кадров: вертикальный боб в такт шагам и мягкий squash&stretch
	var spd := clampf(velocity.length() / SPEED, 0.0, 1.0)
	_bob_phase += delta * 9.0 * spd
	_idle_phase += delta * 1.6
	# шаг: подпрыгивание в такт + покачивание влево-вправо; стоя — медленное дыхание
	var bob := absf(sin(_bob_phase)) * 3.0 * spd + sin(_idle_phase) * 0.8 * (1.0 - spd)
	var sway := sin(_bob_phase) * 0.06 * spd
	var stretch := 1.0 + sin(_bob_phase * 2.0) * 0.03 * spd + sin(_idle_phase) * 0.012 * (1.0 - spd)
	_sprite.position.y = lerpf(_sprite.position.y, -bob, delta * 20.0)
	_sprite.scale = Vector2(0.4 / stretch, 0.4 * stretch)
	_hand.position = _hand.position.lerp(_hand_anchor() + Vector2(0, -bob * 0.6 + sin(_bob_phase) * 1.5 * spd), delta * 15.0)
	_hand.rotation = lerpf(_hand.rotation, sway * 2.0 + sin(_idle_phase) * 0.04, delta * 8.0)
	# лёгкий наклон корпуса по направлению движения, по диагонали чуть сильнее (иллюзия 8 направлений)
	var diag := 0.0
	if _walking and (_row == 1 or _row == 2):
		diag = signf(velocity.x) * velocity.y / SPEED * 0.10
	_sprite.rotation = lerpf(_sprite.rotation, velocity.x / SPEED * 0.05 + diag + sway, delta * 8.0)
	_shadow.scale = Vector2(0.42, 0.16) * (1.0 - bob * 0.04)
	_dust.emitting = _walking
	if _walking:
		_idle_t = 0.0
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.34
			AudioManager.play_sfx("step", -14.0, randf_range(0.85, 1.15))
	else:
		_idle_t += delta
	_lantern_glow.position = _hand.position + Vector2(0, 4)
	_lantern.position = _hand.position
	_lantern_glow.modulate.a = lerpf(_lantern_glow.modulate.a, (0.75 + 0.15 * sin(Time.get_ticks_msec() * 0.006)) if GameState.lantern_on else 0.0, delta * 6.0)
	_flash.modulate.a = maxf(_flash.modulate.a - delta * 2.0, 0.0)
	_flash.scale = _flash.scale.lerp(Vector2(0.6, 0.6), delta * 4.0)
	GameState.player_position = global_position
	moved.emit(global_position)
	idle_time_changed.emit(_idle_t)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("toggle_lantern"):
		# F — быстро взять/убрать фонарь
		var idx: int = Inventory.hotbar.find("lantern")
		if idx >= 0:
			Inventory.set_active(idx if Inventory.active_item() != "lantern" else (1 if idx == 0 else 0))

func flash() -> void:
	_flash.modulate.a = 0.6
	_flash.scale = Vector2(1.2, 1.2)
	play_catch()

func play_catch() -> void:
	_action = "catch"
	_action_t = 0.6
	_row = 0
	_sprite.play("catch")
	_sprite.frame = 0

func get_idle_time() -> float:
	return _idle_t
