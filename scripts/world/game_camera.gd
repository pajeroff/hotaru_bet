extends Camera2D
## Плавно следует за игроком, покачивается при ходьбе, зум колесом мыши с ограничениями.

const ZOOM_MIN := 0.7   # максимально далеко
const ZOOM_MAX := 1.8   # максимально близко
const ZOOM_DEFAULT := 1.05
const ZOOM_STEP := 0.1

var target: CharacterBody2D
var _t := 0.0
var _target_zoom := ZOOM_DEFAULT

func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 4.0
	zoom = Vector2.ONE * ZOOM_DEFAULT
	_target_zoom = ZOOM_DEFAULT
	process_callback = Camera2D.CAMERA2D_PROCESS_IDLE

func set_limits(half: Vector2) -> void:
	limit_left = int(-half.x * 1.25)
	limit_right = int(half.x * 1.25)
	limit_top = int(-half.y * 1.25)
	limit_bottom = int(half.y * 1.25)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_zoom = clampf(_target_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_zoom = clampf(_target_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)

func _process(delta: float) -> void:
	if target == null:
		return
	_t += delta
	var z := lerpf(zoom.x, _target_zoom, 1.0 - exp(-delta * 8.0))
	zoom = Vector2(z, z)
	var speed: float = target.velocity.length()
	var sway := Vector2(sin(_t * 6.0), sin(_t * 12.0) * 0.6) * clampf(speed / 150.0, 0.0, 1.0) * 1.2 / z
	global_position = target.global_position + Vector2(0, -20) + sway
