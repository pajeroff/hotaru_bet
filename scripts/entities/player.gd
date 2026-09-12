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
const FW := 96
const FH := 128
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
	_sprite.offset = Vector2(0, -FH * 0.5 + 8)
	_sprite.scale = Vector2(0.7, 0.7)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.animation = "idle_down"
	_sprite.play()
	add_child(_sprite)

	_lantern = PointLight2D.new()
	_lantern.texture = TEX_LIGHT
	_lantern.color = Color(1.0, 0.88, 0.65)
	_lantern.texture_scale = 2.6
	_lantern.energy = 0.0
	_lantern.position = Vector2(0, -20)
	_lantern.shadow_enabled = true
	_lantern.shadow_filter = PointLight2D.SHADOW_FILTER_PCF13
	_lantern.shadow_filter_smooth = 4.0
	_lantern.shadow_color = Color(0.1, 0.08, 0.2, 0.5)
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
	pm.scale_min = 0.1
	pm.scale_max = 0.22
	pm.color = Color(0.8, 0.75, 0.6, 0.35)
	_dust.process_material = pm
	add_child(_dust)

	_flash = Sprite2D.new()
	_flash.texture = TEX_LIGHT
	_flash.modulate = Color(1, 0.95, 0.75, 0.0)
	_flash.position = Vector2(0, -24)
	_flash.scale = Vector2(0.6, 0.6)
	add_child(_flash)

	global_position = GameState.player_position
	set_lantern(GameState.lantern_on, true)

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for r in range(4):
		var dir_name: String = DIR_NAMES[r]
		var walk: String = "walk_" + dir_name
		var idle: String = "idle_" + dir_name
		sf.add_animation(walk)
		sf.set_animation_speed(walk, 8.0)
		sf.set_animation_loop(walk, true)
		sf.add_animation(idle)
		sf.set_animation_speed(idle, 1.0)
		for c in range(4):
			var at := AtlasTexture.new()
			at.atlas = SHEET
			at.region = Rect2(c * FW, r * FH, FW, FH)
			sf.add_frame(walk, at)
			if c == 0 and r != 0:
				sf.add_frame(idle, at)
	# дополнительные анимации из второго блока листа (строки 4..7)
	var extra := {"idle_down": [4, 3.0, true], "catch": [5, 7.0, false], "sit": [6, 2.0, true], "walk_lantern": [7, 8.0, true]}
	for anim_name in extra:
		var row: int = extra[anim_name][0]
		var fps: float = extra[anim_name][1]
		var loop: bool = extra[anim_name][2]
		var an := str(anim_name)
		if not sf.has_animation(an):
			sf.add_animation(an)
		sf.set_animation_speed(an, fps)
		sf.set_animation_loop(an, loop)
		for c in range(4):
			var at := AtlasTexture.new()
			at.atlas = SHEET
			at.region = Rect2(c * FW, row * FH, FW, FH)
			sf.add_frame(an, at)
		if an == "idle_down":
			# пинг-понг для дыхания
			for c in [2, 1]:
				var at2 := AtlasTexture.new()
				at2.atlas = SHEET
				at2.region = Rect2(c * FW, row * FH, FW, FH)
				sf.add_frame(an, at2)
	return sf

func set_lantern(on: bool, instant := false) -> void:
	GameState.lantern_on = on
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
		if absf(facing.x) > absf(facing.y):
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
	_sprite.speed_scale = clampf(velocity.length() / SPEED, 0.6, 1.2) if _walking else 1.0
	# лёгкое "дыхание" стоя
	_sprite.scale.y = 0.7
	# лёгкий наклон корпуса при движении
	_sprite.rotation = lerpf(_sprite.rotation, velocity.x / SPEED * 0.05, delta * 6.0)
	_sprite.scale.x = 0.7 * (1.0 + absf(sin(Time.get_ticks_msec() * 0.012)) * 0.02 if _walking else 1.0)
	_dust.emitting = _walking
	if _walking:
		_idle_t = 0.0
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.34
			_shadow.scale = Vector2(0.46, 0.18)
			AudioManager.play_sfx("step", -14.0, randf_range(0.85, 1.15))
	else:
		_idle_t += delta
	_lantern_glow.position.x = 12 if _row != 1 else -12
	_lantern_glow.modulate.a = lerpf(_lantern_glow.modulate.a, (0.75 + 0.15 * sin(Time.get_ticks_msec() * 0.006)) if GameState.lantern_on else 0.0, delta * 6.0)
	_shadow.scale = _shadow.scale.lerp(Vector2(0.42, 0.16), delta * 6.0)
	_flash.modulate.a = maxf(_flash.modulate.a - delta * 2.0, 0.0)
	_flash.scale = _flash.scale.lerp(Vector2(0.6, 0.6), delta * 4.0)
	GameState.player_position = global_position
	moved.emit(global_position)
	idle_time_changed.emit(_idle_t)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("toggle_lantern"):
		set_lantern(not GameState.lantern_on)

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
