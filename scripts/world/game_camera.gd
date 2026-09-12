extends Camera2D
## Плавно следует за игроком, едва заметно покачивается при ходьбе.

var target: CharacterBody2D
var _t := 0.0

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 4.0
	zoom = Vector2(1.45, 1.45)
	limit_left = -1000
	limit_right = 1000
	limit_top = -700
	limit_bottom = 700

func _process(delta: float) -> void:
	if target == null:
		return
	_t += delta
	var speed: float = target.velocity.length()
	var sway := Vector2(sin(_t * 6.0), sin(_t * 12.0) * 0.6) * clampf(speed / 150.0, 0.0, 1.0) * 1.2
	global_position = target.global_position + Vector2(0, -10) + sway
