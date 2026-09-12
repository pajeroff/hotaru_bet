extends Node2D
## Бабочка: летает петлями, машет крыльями, видна днём.

var _t := randf() * 100.0
var _seed := randf() * 10.0
var _home := Vector2.ZERO
const COLORS: Array[Color] = [Color(1.0, 0.85, 0.5), Color(0.75, 0.85, 1.0), Color(1.0, 0.8, 0.9), Color(1.0, 1.0, 0.95)]
var _color: Color = COLORS[randi() % 4]
var _alpha := 0.0

func _ready() -> void:
	_home = position

func _process(delta: float) -> void:
	_t += delta
	var phase := GameState.get_phase()
	var want := 1.0 if (phase == "morning" or phase == "day" or phase == "dawn") and GameState.weather != "rain" and GameState.weather != "storm" and GameState.weather != "snow" else 0.0
	_alpha = move_toward(_alpha, want, delta * 0.5)
	visible = _alpha > 0.01
	if not visible:
		return
	position = _home + Vector2(sin(_t * 0.7 + _seed) * 90.0 + sin(_t * 2.1) * 12.0, cos(_t * 0.5 + _seed * 2.0) * 60.0 + sin(_t * 3.3) * 6.0)
	queue_redraw()

func _draw() -> void:
	var flap := absf(sin(_t * 14.0 + _seed))
	var c := Color(_color.r, _color.g, _color.b, _alpha)
	var w := 5.0 * (0.3 + 0.7 * flap)
	draw_set_transform(Vector2.ZERO, sin(_t * 0.7 + _seed) * 0.3, Vector2.ONE)
	draw_circle(Vector2(0, 8), 5, Color(0, 0, 0, 0.1 * _alpha))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(-w, -5), Vector2(-w * 1.1, 1), Vector2(-w * 0.5, 4)]), c)
	draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, -5), Vector2(w * 1.1, 1), Vector2(w * 0.5, 4)]), c)
	draw_line(Vector2(0, -3), Vector2(0, 4), Color(0.3, 0.25, 0.3, _alpha), 1.5)
	draw_set_transform(Vector2.ZERO)
