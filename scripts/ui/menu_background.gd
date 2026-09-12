extends Control
## Пастельный рассветный фон с туманом и медленно летающими светлячками.

var _flies: Array = []
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
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

func _draw() -> void:
	var sz := size
	# Небо — вертикальный градиент
	var steps := 24
	for i in range(steps):
		var a := float(i) / steps
		var c := Color(0.95, 0.80, 0.78).lerp(Color(0.78, 0.80, 0.92), a)
		draw_rect(Rect2(0, sz.y * a, sz.x, sz.y / steps + 1), c)
	# Солнце
	draw_circle(Vector2(sz.x * 0.72, sz.y * 0.30), 90, Color(1.0, 0.93, 0.78, 0.55))
	draw_circle(Vector2(sz.x * 0.72, sz.y * 0.30), 60, Color(1.0, 0.96, 0.85, 0.8))
	# Дальние холмы
	_hill(sz, 0.62, Color(0.72, 0.76, 0.86, 0.9), 0.0)
	_hill(sz, 0.70, Color(0.62, 0.70, 0.78, 0.95), 2.0)
	_hill(sz, 0.80, Color(0.55, 0.66, 0.66, 1.0), 4.0)
	# Туман
	for i in range(6):
		var y := sz.y * (0.55 + i * 0.07) + sin(_t * 0.2 + i) * 8.0
		draw_rect(Rect2(0, y, sz.x, sz.y * 0.09), Color(1, 1, 1, 0.10))
	# Светлячки
	for f in _flies:
		var p: Vector2 = f["pos"] * sz
		var pulse := 0.6 + 0.4 * sin(_t * 2.0 + f["seed"])
		var c: Color = f["color"]
		draw_circle(p, f["size"] * 3.5, Color(c.r, c.g, c.b, 0.12 * pulse))
		draw_circle(p, f["size"], Color(c.r, c.g, c.b, 0.85 * pulse))

func _hill(sz: Vector2, base: float, color: Color, offset: float) -> void:
	var pts := PackedVector2Array()
	var n := 40
	for i in range(n + 1):
		var x := sz.x * i / n
		var y := sz.y * base + sin(i * 0.5 + offset) * 22.0 + cos(i * 0.21 + offset) * 30.0
		pts.append(Vector2(x, y))
	pts.append(Vector2(sz.x, sz.y))
	pts.append(Vector2(0, sz.y))
	draw_colored_polygon(pts, color)
