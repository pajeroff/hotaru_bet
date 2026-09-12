extends Node2D
## Отражения светлячков в пруду.

const POND_CENTER := Vector2(760, 480)
const POND_RADII := Vector2(260, 160)
const TEX_GLOW := preload("res://assets/textures/particle_glow.png")
var fireflies = null
var _t := 0.0

func _ready() -> void:
	z_index = 0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if fireflies == null or Settings.particle_quality < 1:
		return
	for f in fireflies.get_children():
		if not f is Node2D or not f.has_method("try_catch"):
			continue
		var p: Vector2 = f.global_position
		var rp := Vector2(p.x, POND_CENTER.y * 2.0 - p.y + 30.0)
		var d := (rp - POND_CENTER) / POND_RADII
		if d.length() < 1.0:
			var wob := sin(_t * 3.0 + p.x * 0.05) * 2.0
			var c: Color = f.color
			var vs: float = f._visible_scale
			var a := (1.0 - d.length()) * 0.5 * vs
			draw_texture_rect(TEX_GLOW, Rect2(rp + Vector2(wob - 14, -8), Vector2(28, 16)), false, Color(c.r, c.g, c.b, a * 0.6))
			draw_texture_rect(TEX_GLOW, Rect2(rp + Vector2(wob - 5, -3), Vector2(10, 6)), false, Color(1, 1, 1, a))
