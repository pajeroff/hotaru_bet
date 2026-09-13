class_name ClockWidget
extends Control
## Круглые аналоговые часы на бумажном циферблате: 12-часовая стрелка, минутная, AM/PM и цвет неба.

const TEX_CLOCK := preload("res://assets/ui/clock.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var ts := TEX_CLOCK.get_size()
	var sc := minf(size.x / ts.x, size.y / ts.y)
	var s := ts * sc
	var rect := Rect2((size - s) * 0.5, s)
	var c := rect.get_center()
	var r := s.x * 0.44   # радиус диска
	var t: float = GameState.time_of_day
	# подложка-небо: оттенок по времени
	var sky := _sky_color(t)
	draw_circle(c, r, sky)
	draw_texture_rect(TEX_CLOCK, rect, false)
	# метки часов
	for i in range(12):
		var a := float(i) / 12.0 * TAU - PI / 2.0
		var d := Vector2(cos(a), sin(a))
		var long := i % 3 == 0
		draw_line(c + d * r * (0.78 if long else 0.86), c + d * r * 0.93, Color(0.7, 0.9, 0.92, 0.8 if long else 0.4), 2.0 if long else 1.0, true)
	# солнце / луна маленькие индикаторы по дуге дня
	var day_a := (t / 24.0) * TAU - PI / 2.0
	var sun_p := c + Vector2(cos(day_a), sin(day_a)) * r * 0.62
	var is_day := t >= 6.0 and t < 19.0
	draw_circle(sun_p, 6.0, Color(1.0, 0.85, 0.4, 0.85) if is_day else Color(0.85, 0.9, 1.0, 0.85))
	draw_circle(sun_p, 10.0, Color(1.0, 0.85, 0.4, 0.2) if is_day else Color(0.8, 0.85, 1.0, 0.18))
	# стрелки
	var h12 := fmod(t, 12.0)
	var ha := h12 / 12.0 * TAU - PI / 2.0
	var ma := fmod(t, 1.0) * TAU - PI / 2.0
	var ink := Color(0.85, 0.97, 0.98)
	draw_line(c, c + Vector2(cos(ha), sin(ha)) * r * 0.5, ink, 4.0, true)
	draw_line(c, c + Vector2(cos(ma), sin(ma)) * r * 0.74, ink, 2.5, true)
	draw_circle(c, 4.5, Color(0.55, 0.95, 0.95))
	draw_circle(c, 2.0, Color(0.05, 0.1, 0.12))

static func _sky_color(t: float) -> Color:
	var stops := [
		[0.0, Color(0.05, 0.10, 0.14)], [5.0, Color(0.06, 0.12, 0.16)], [6.5, Color(0.14, 0.22, 0.26)],
		[9.0, Color(0.18, 0.32, 0.36)], [14.0, Color(0.20, 0.36, 0.38)], [18.0, Color(0.16, 0.24, 0.30)],
		[20.0, Color(0.10, 0.16, 0.22)], [22.0, Color(0.06, 0.11, 0.15)], [24.0, Color(0.05, 0.10, 0.14)],
	]
	for i in range(stops.size() - 1):
		var a0: float = stops[i][0]
		var a1: float = stops[i + 1][0]
		if t >= a0 and t <= a1:
			var k := (t - a0) / (a1 - a0)
			return (stops[i][1] as Color).lerp(stops[i + 1][1], k)
	return stops[0][1]
