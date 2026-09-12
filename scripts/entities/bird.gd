extends Node2D
## Птица: сидит, иногда перелетает на новое место с тенью на земле.

var _t := 0.0
var _state := "sit"
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _fly_t := 0.0
var _fly_dur := 3.0
var _wait := randf_range(4.0, 14.0)
var _dir := 1.0
var _hop := 0.0

func _process(delta: float) -> void:
	_t += delta
	if _state == "sit":
		_wait -= delta
		if randf() < delta * 0.3:
			_hop = 1.0
		_hop = maxf(_hop - delta * 4.0, 0.0)
		if _wait <= 0.0:
			_state = "fly"
			_from = position
			_to = Vector2(randf_range(-1500, 1500), randf_range(-1050, 1050))
			_fly_t = 0.0
			_fly_dur = _from.distance_to(_to) / 220.0
			_dir = 1.0 if _to.x > _from.x else -1.0
	else:
		_fly_t += delta
		var k := clampf(_fly_t / _fly_dur, 0.0, 1.0)
		position = _from.lerp(_to, k)
		if k >= 1.0:
			_state = "sit"
			_wait = randf_range(6.0, 20.0)
	queue_redraw()

func _draw() -> void:
	var flying := _state == "fly"
	var k := clampf(_fly_t / _fly_dur, 0.0, 1.0) if flying else 0.0
	var height := sin(k * PI) * 90.0 if flying else 0.0
	# тень на земле
	draw_set_transform(Vector2(0, 4), 0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 6.0 - height * 0.03, Color(0, 0, 0, 0.18 - height * 0.001))
	draw_set_transform(Vector2.ZERO)
	var y := -height - _hop * 6.0
	var body := Color(0.45, 0.38, 0.42)
	draw_set_transform(Vector2(0, y), 0, Vector2(_dir, 1.0))
	draw_circle(Vector2(0, 0), 5, body)
	draw_circle(Vector2(4, -3), 3.2, body)
	draw_line(Vector2(6.5, -3), Vector2(9, -2.5), Color(0.9, 0.7, 0.3), 1.5)
	if flying:
		var flap := sin(_t * 18.0) * 7.0
		draw_line(Vector2(-1, -1), Vector2(-6, -1 - flap), body, 2.5)
		draw_line(Vector2(-1, -1), Vector2(-6, -1 + flap * 0.4), body, 2.0)
	else:
		draw_line(Vector2(-4, 0), Vector2(-9, -2), body, 2.0)
	draw_set_transform(Vector2.ZERO)
