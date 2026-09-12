extends Node2D
## Отражения светлячков в пруду.

const POND_CENTER := Vector2(430, 250)
const POND_RADII := Vector2(150, 92)
var fireflies = null
var _t := 0.0

func _ready() -> void:
	z_index = 1

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if fireflies == null:
		return
	for f in fireflies.get_children():
		if not f is Node2D or not f.has_method("try_catch"):
			continue
		var p: Vector2 = f.global_position
		# отражение: зеркалим по горизонтальной оси пруда
		var rp := Vector2(p.x, POND_CENTER.y * 2.0 - p.y + 30.0)
		var d := (rp - POND_CENTER) / POND_RADII
		if d.length() < 1.0:
			var wob := sin(_t * 3.0 + p.x * 0.05) * 2.0
			var c: Color = f.color
			var a := (1.0 - d.length()) * 0.45 * f._visible_scale
			draw_circle(rp + Vector2(wob, 0), 6, Color(c.r, c.g, c.b, a * 0.3))
			draw_circle(rp + Vector2(wob, 0), 2.5, Color(c.r, c.g, c.b, a))
