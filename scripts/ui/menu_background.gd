extends Control
## Пастельный рассветный фон с туманом и медленно летающими светлячками.

var _flies: Array = []
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://assets/textures/menu_bg.jpg"):
		_bg = load("res://assets/textures/menu_bg.jpg")
	for i in range(28):
		_flies.append({
			"pos": Vector2(randf(), randf()),
			"seed": randf() * 100.0,
			"speed": randf_range(0.01, 0.03),
			"size": randf_range(2.0, 4.5),
			"color": [Color(1.0, 0.9, 0.6), Color(0.7, 0.9, 1.0), Color(0.8, 1.0, 0.8)][randi() % 3],
		})

func _process(delta: float) -> void:
	_t += delta
	for f in _flies:
		var s: float = f["seed"]
		var p: Vector2 = f["pos"]
		p += Vector2(sin(_t * 0.4 + s), cos(_t * 0.33 + s * 1.3)) * f["speed"] * delta
		p.x = wrapf(p.x, -0.05, 1.05)
		p.y = wrapf(p.y, -0.05, 1.05)
		f["pos"] = p
	queue_redraw()

var _bg: Texture2D = null

func _draw() -> void:
	var sz := size
	# ключевой арт, cover-масштаб с медленным дрейфом (параллакс)
	if _bg != null:
		var ts := Vector2(_bg.get_size())
		var sc := maxf(sz.x / ts.x, sz.y / ts.y) * 1.06
		var dsz := ts * sc
		var drift := Vector2(sin(_t * 0.05), cos(_t * 0.04)) * 12.0
		draw_texture_rect(_bg, Rect2((sz - dsz) * 0.5 + drift, dsz), false)
	else:
		# запасной рассвет: небо -> туман -> тёмная зелень
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)])
		var cols := PackedColorArray([Color(0.62, 0.55, 0.78), Color(0.75, 0.62, 0.72), Color(0.30, 0.40, 0.36), Color(0.25, 0.36, 0.34)])
		draw_polygon(pts, cols)
		var sun := Vector2(sz.x * 0.3, sz.y * 0.42)
		for i in range(6):
			draw_circle(sun, 40.0 + i * 55.0, Color(1.0, 0.82, 0.62, 0.10 - i * 0.015))
		var hor := sz.y * 0.55
		draw_rect(Rect2(0, hor, sz.x, sz.y * 0.25), Color(0.9, 0.85, 0.9, 0.18))
	# тёплая вуаль + туман
	for i in range(5):
		var y := sz.y * (0.6 + i * 0.08) + sin(_t * 0.2 + i) * 8.0
		draw_rect(Rect2(0, y, sz.x, sz.y * 0.1), Color(1, 1, 1, 0.05))
	for f in _flies:
		var p: Vector2 = f["pos"] * sz
		var fs: float = f["seed"]
		var pulse := 0.6 + 0.4 * sin(_t * 2.0 + fs)
		var c: Color = f["color"]
		var fsz: float = f["size"]
		draw_circle(p, fsz * 4.0, Color(c.r, c.g, c.b, 0.10 * pulse))
		draw_circle(p, fsz, Color(c.r, c.g, c.b, 0.9 * pulse))

