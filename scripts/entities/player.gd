extends CharacterBody2D
## Хранитель. Ходит в 8 направлениях, ловит светлячков, включает фонарь.

signal moved(pos: Vector2)
signal idle_time_changed(t: float)

const SPEED := 150.0
const ACCEL := 9.0

var facing := Vector2.DOWN
var _anim_t := 0.0
var _walking := false
var _step_timer := 0.0
var _idle_t := 0.0
var _lantern: PointLight2D
var _catch_flash := 0.0
var input_enabled := true
var _bob := 0.0

func _ready() -> void:
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 9
	cs.shape = c
	cs.position = Vector2(0, 4)
	add_child(cs)
	_lantern = PointLight2D.new()
	_lantern.texture = _tex()
	_lantern.color = Color(1.0, 0.9, 0.7)
	_lantern.texture_scale = 2.4
	_lantern.energy = 0.0
	_lantern.position = Vector2(0, -6)
	add_child(_lantern)
	global_position = GameState.player_position
	set_lantern(GameState.lantern_on, true)

func _tex() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func set_lantern(on: bool, instant := false) -> void:
	GameState.lantern_on = on
	var tw := create_tween()
	tw.tween_property(_lantern, "energy", 1.1 if on else 0.0, 0.01 if instant else 0.5).set_trans(Tween.TRANS_SINE)
	if not instant:
		AudioManager.play_sfx("lantern", -6.0, 1.3 if on else 0.9)

func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if input_enabled:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target := dir * SPEED
	velocity = velocity.lerp(target, 1.0 - exp(-ACCEL * delta))
	move_and_slide()
	_walking = velocity.length() > 15.0
	if dir.length() > 0.1:
		facing = dir.normalized()
	if _walking:
		_anim_t += delta * 8.0 * (velocity.length() / SPEED)
		_idle_t = 0.0
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.34
			AudioManager.play_sfx("step", -14.0, randf_range(0.85, 1.15))
	else:
		_anim_t = lerpf(_anim_t, roundf(_anim_t / PI) * PI, delta * 10.0)
		_idle_t += delta
	_bob = sin(_anim_t) * (2.5 if _walking else 0.0)
	_catch_flash = maxf(_catch_flash - delta * 2.0, 0.0)
	GameState.player_position = global_position
	moved.emit(global_position)
	idle_time_changed.emit(_idle_t)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("toggle_lantern"):
		set_lantern(not GameState.lantern_on)

func flash() -> void:
	_catch_flash = 1.0

func get_idle_time() -> float:
	return _idle_t

func _draw() -> void:
	var bob := absf(_bob)
	var y := -bob
	# тень
	draw_set_transform(Vector2(0, 12), 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11, Color(0.1, 0.15, 0.1, 0.25))
	draw_set_transform(Vector2.ZERO)
	# ноги
	var leg_swing := sin(_anim_t) * 4.0 if _walking else 0.0
	var side := 1.0 if facing.x >= 0 else -1.0
	draw_rect(Rect2(-6 + leg_swing * 0.5, 4 + y, 5, 9), Color(0.55, 0.45, 0.40))
	draw_rect(Rect2(1 - leg_swing * 0.5, 4 + y, 5, 9), Color(0.55, 0.45, 0.40))
	# тело (тёплая туника)
	draw_rect(Rect2(-9, -12 + y, 18, 18), Color(0.96, 0.87, 0.72))
	draw_rect(Rect2(-9, -12 + y, 18, 4), Color(0.90, 0.72, 0.62))
	draw_line(Vector2(0, -8 + y), Vector2(0, 4 + y), Color(0.90, 0.72, 0.62), 1.5)
	# руки
	var arm_swing := cos(_anim_t) * 3.0 if _walking else 0.0
	draw_rect(Rect2(-12, -9 + y + arm_swing * 0.5, 4, 10), Color(0.98, 0.88, 0.78))
	draw_rect(Rect2(8, -9 + y - arm_swing * 0.5, 4, 10), Color(0.98, 0.88, 0.78))
	# голова
	draw_circle(Vector2(0, -20 + y), 9, Color(0.99, 0.90, 0.80))
	# волосы
	draw_circle(Vector2(0, -23 + y), 9, Color(0.62, 0.48, 0.40))
	draw_rect(Rect2(-9, -23 + y, 18, 5), Color(0.62, 0.48, 0.40))
	# лицо — зависит от направления
	if facing.y > -0.5:
		var ex := facing.x * 2.0
		var ey := -19 + y + facing.y * 1.0
		draw_circle(Vector2(-3 + ex, ey), 1.3, Color(0.3, 0.25, 0.3))
		draw_circle(Vector2(3 + ex, ey), 1.3, Color(0.3, 0.25, 0.3))
		draw_circle(Vector2(-5 + ex, ey + 3), 1.8, Color(1.0, 0.75, 0.75, 0.6))
		draw_circle(Vector2(5 + ex, ey + 3), 1.8, Color(1.0, 0.75, 0.75, 0.6))
	# фонарь в руке
	if GameState.lantern_on:
		var lp := Vector2(12 * side, -2 + y)
		draw_line(Vector2(10 * side, -6 + y), lp, Color(0.5, 0.42, 0.36), 1.5)
		draw_circle(lp + Vector2(0, 5), 8, Color(1.0, 0.85, 0.5, 0.25))
		draw_rect(Rect2(lp.x - 3, lp.y, 6, 8), Color(1.0, 0.85, 0.55))
	# вспышка при ловле
	if _catch_flash > 0.0:
		draw_circle(Vector2(0, -10 + y), 30 * (1.0 - _catch_flash) + 10, Color(1.0, 0.95, 0.75, _catch_flash * 0.5))
