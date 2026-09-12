extends Node2D
## Древний храм в центре поляны. Пульсирует, как сердце; яркость зависит от уровня.

var _t := 0.0
var _glow := 0.3
var _target_glow := 0.3
var _light: PointLight2D
var _lanterns: Array = []

func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = _make_light_texture(256)
	_light.color = Color(1.0, 0.85, 0.6)
	_light.texture_scale = 2.2
	_light.energy = 0.8
	_light.position = Vector2(0, -30)
	add_child(_light)
	for i in range(6):
		var ang := TAU * i / 6.0 + 0.3
		_lanterns.append({"pos": Vector2(cos(ang) * 150, sin(ang) * 110 + 10), "seed": randf() * 10.0})
	GameState.temple_changed.connect(func(_l): _update_target())
	GameState.firefly_caught.connect(func(_d): _pulse_burst())
	_update_target()
	_glow = _target_glow

func _update_target() -> void:
	_target_glow = [0.35, 0.65, 1.0, 1.3, 1.6][clampi(GameState.temple_level, 0, 4)]

func _pulse_burst() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_glow", _target_glow + 0.5, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_glow", _target_glow, 1.5).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	_t += delta
	_glow = lerpf(_glow, _target_glow, delta * 0.5)
	var beat := 0.85 + 0.15 * (0.5 + 0.5 * sin(_t * 1.4)) * (0.5 + 0.5 * sin(_t * 2.8))
	_light.energy = _glow * beat * 1.4
	_light.texture_scale = 2.0 + _glow * 0.6
	queue_redraw()

func _draw() -> void:
	var beat := 0.85 + 0.15 * sin(_t * 1.4)
	# тень
	draw_set_transform(Vector2(0, 40), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 110, Color(0.1, 0.15, 0.1, 0.25))
	draw_set_transform(Vector2.ZERO)
	# каменное основание
	draw_rect(Rect2(-90, -10, 180, 56), Color(0.66, 0.64, 0.60))
	draw_rect(Rect2(-80, -20, 160, 12), Color(0.72, 0.70, 0.66))
	# ступени
	draw_rect(Rect2(-36, 40, 72, 10), Color(0.72, 0.70, 0.66))
	draw_rect(Rect2(-42, 50, 84, 10), Color(0.66, 0.64, 0.60))
	# колонны
	for x in [-62, -22, 22, 62]:
		draw_rect(Rect2(x - 7, -78, 14, 62), Color(0.62, 0.42, 0.38))
	# внутреннее свечение
	var inner := Color(1.0, 0.85, 0.55, 0.35 + 0.45 * _glow * beat)
	draw_rect(Rect2(-56, -74, 112, 56), Color(0.18, 0.14, 0.22))
	draw_rect(Rect2(-56, -74, 112, 56), inner)
	draw_circle(Vector2(0, -46), 14 + 4 * _glow * beat, Color(1.0, 0.95, 0.8, 0.5 + 0.4 * _glow))
	# крыша
	var roof := PackedVector2Array([Vector2(-105, -76), Vector2(105, -76), Vector2(70, -122), Vector2(-70, -122)])
	draw_colored_polygon(roof, Color(0.42, 0.30, 0.34))
	var roof2 := PackedVector2Array([Vector2(-80, -120), Vector2(80, -120), Vector2(40, -150), Vector2(-40, -150)])
	draw_colored_polygon(roof2, Color(0.48, 0.34, 0.38))
	draw_line(Vector2(-108, -76), Vector2(108, -76), Color(0.55, 0.40, 0.42), 4)
	draw_line(Vector2(-118, -70), Vector2(-100, -80), Color(0.48, 0.34, 0.38), 5)
	draw_line(Vector2(118, -70), Vector2(100, -80), Color(0.48, 0.34, 0.38), 5)
	# фонарики и камешки вокруг
	for l in _lanterns:
		var p: Vector2 = l["pos"]
		var fl := 0.7 + 0.3 * sin(_t * 3.0 + l["seed"] * 4.0)
		draw_rect(Rect2(p.x - 2, p.y - 20, 4, 20), Color(0.5, 0.42, 0.36))
		draw_circle(p + Vector2(0, -24), 10 * fl + 6, Color(1.0, 0.8, 0.5, 0.18 * fl))
		draw_rect(Rect2(p.x - 6, p.y - 30, 12, 12), Color(0.95, 0.75, 0.45, 0.9))
		draw_circle(p + Vector2(8, 4), 3, Color(0.7, 0.7, 0.66))
		draw_circle(p + Vector2(-9, 2), 2.5, Color(0.75, 0.74, 0.7))

static func _make_light_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := size / 2.0
	for y in range(size):
		for x in range(size):
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
