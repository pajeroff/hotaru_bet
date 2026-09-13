class_name ClockWidget
extends Control
## Круглые часы: тёмный диск с цветом неба, 12 меток, стрелки, солнце/луна по дуге суток.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.46
	var t: float = GameState.time_of_day
	# диск и кромка
	draw_circle(c, r + 2.0, Color(UITheme.EDGE.r, UITheme.EDGE.g, UITheme.EDGE.b, 0.6))
	draw_circle(c, r, _sky_color(t))
	# мягкий градиент-виньетка
	draw_circle(c, r * 0.92, Color(0, 0, 0, 0.12))
	# метки часов
	for i in range(12):
		var a := float(i) / 12.0 * TAU - PI / 2.0
		var d := Vector2(cos(a), sin(a))
		var long := i % 3 == 0
		draw_line(c + d * r * (0.80 if long else 0.88), c + d * r * 0.95, Color(0.75, 0.92, 0.94, 0.9 if long else 0.45), 2.0 if long else 1.0, true)
	# солнце / луна по дуге суток (0ч внизу, 12ч вверху)
	var day_a := (t / 24.0) * TAU + PI / 2.0
	var sp := c + Vector2(cos(day_a), sin(day_a)) * r * 0.66
	var is_day := t >= 6.0 and t < 19.0
	var sc := Color(1.0, 0.85, 0.45) if is_day else Color(0.8, 0.9, 1.0)
	draw_circle(sp, 9.0, Color(sc.r, sc.g, sc.b, 0.18))
	draw_circle(sp, 5.0, sc)
	# стрелки
	var h12 := fmod(t, 12.0)
	var ha := h12 / 12.0 * TAU - PI / 2.0
	var ma := fmod(t, 1.0) * TAU - PI / 2.0
	var ink := Color(0.92, 0.98, 0.98)
	draw_line(c, c + Vector2(cos(ha), sin(ha)) * r * 0.50, ink, 3.5, true)
	draw_line(c, c + Vector2(cos(ma), sin(ma)) * r * 0.74, ink, 2.0, true)
	draw_circle(c, 4.0, UITheme.CYAN)
	draw_circle(c, 1.8, Color(0.04, 0.09, 0.12))

static func _sky_color(t: float) -> Color:
	var stops := [
		[0.0, Color(0.05, 0.10, 0.15)], [5.0, Color(0.07, 0.13, 0.18)], [6.5, Color(0.16, 0.25, 0.30)],
		[9.0, Color(0.20, 0.36, 0.40)], [14.0, Color(0.22, 0.40, 0.42)], [18.0, Color(0.18, 0.27, 0.34)],
		[20.0, Color(0.11, 0.18, 0.24)], [22.0, Color(0.07, 0.12, 0.17)], [24.0, Color(0.05, 0.10, 0.15)],
	]
	for i in range(stops.size() - 1):
		var a0: float = stops[i][0]
		var a1: float = stops[i + 1][0]
		if t >= a0 and t <= a1:
			return (stops[i][1] as Color).lerp(stops[i + 1][1], (t - a0) / (a1 - a0))
	return stops[0][1]
