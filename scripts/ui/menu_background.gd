extends Control
## Живой фон меню: арт с медленным параллаксом, слои дрейфующего тумана, блики на воде,
## летающие светлячки и падающие лепестки.

var _flies: Array = []
var _petals: Array = []
var _t := 0.0
var _bg: Texture2D = null
var _fog_mat: ShaderMaterial
var _fog_rect: ColorRect

const FOG_SHADER := """
shader_type canvas_item;
uniform float t = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }
void fragment() {
	vec2 uv = UV;
	float n = fbm(vec2(uv.x * 3.0 + t * 0.02, uv.y * 6.0 + t * 0.005));
	float n2 = fbm(vec2(uv.x * 5.0 - t * 0.015, uv.y * 9.0));
	float band = smoothstep(0.45, 0.72, uv.y) * (1.0 - smoothstep(0.75, 1.0, uv.y));
	float a = band * (n * 0.55 + n2 * 0.25) * 0.55;
	vec3 col = mix(vec3(0.95, 0.85, 0.92), vec3(1.0, 0.93, 0.85), n2);
	COLOR = vec4(col, a);
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg = _load_bg()
	for i in range(34):
		_flies.append({
			"pos": Vector2(randf(), randf_range(0.35, 1.0)),
			"seed": randf() * 100.0,
			"speed": randf_range(0.01, 0.03),
			"size": randf_range(1.6, 3.6),
			"color": [Color(1.0, 0.9, 0.6), Color(0.75, 0.92, 1.0), Color(0.85, 1.0, 0.8)][randi() % 3],
		})
	for i in range(18):
		_petals.append(_new_petal(true))
	# слой тумана поверх арта, под светлячками
	_fog_rect = ColorRect.new()
	_fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = FOG_SHADER
	_fog_mat = ShaderMaterial.new()
	_fog_mat.shader = sh
	_fog_rect.material = _fog_mat
	add_child(_fog_rect)

func _load_bg() -> Texture2D:
	var path := "res://assets/textures/menu_bg.jpg"
	if ResourceLoader.exists(path):
		var t = load(path)
		if t is Texture2D:
			return t
	# запасной путь: читаем файл напрямую, без импорта
	var img := Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _new_petal(anywhere: bool) -> Dictionary:
	return {
		"pos": Vector2(randf_range(-0.1, 1.0), randf_range(-0.1, 1.0) if anywhere else -0.05),
		"seed": randf() * 100.0,
		"size": randf_range(4.0, 8.0),
		"rot": randf() * TAU,
		"speed": randf_range(0.035, 0.07),
	}

func _process(delta: float) -> void:
	_t += delta
	if _fog_mat:
		_fog_mat.set_shader_parameter("t", _t)
	for f in _flies:
		var s: float = f["seed"]
		var p: Vector2 = f["pos"]
		p += Vector2(sin(_t * 0.4 + s), cos(_t * 0.33 + s * 1.3)) * f["speed"] * delta
		p.x = wrapf(p.x, -0.05, 1.05)
		p.y = wrapf(p.y, 0.3, 1.05)
		f["pos"] = p
	for i in range(_petals.size()):
		var pt: Dictionary = _petals[i]
		var p: Vector2 = pt["pos"]
		p.y += pt["speed"] * delta
		p.x += (0.02 + sin(_t * 0.8 + pt["seed"]) * 0.02) * delta
		pt["rot"] += delta * 1.2
		pt["pos"] = p
		if p.y > 1.08 or p.x > 1.1:
			_petals[i] = _new_petal(false)
	queue_redraw()

func _draw() -> void:
	var sz := size
	if _bg != null:
		var ts := Vector2(_bg.get_size())
		var sc := maxf(sz.x / ts.x, sz.y / ts.y) * 1.05
		var dsz := ts * sc
		var drift := Vector2(sin(_t * 0.05), cos(_t * 0.04)) * 14.0
		draw_texture_rect(_bg, Rect2((sz - dsz) * 0.5 + drift, dsz), false)
	else:
		var pts := PackedVector2Array([Vector2.ZERO, Vector2(sz.x, 0), sz, Vector2(0, sz.y)])
		var cols := PackedColorArray([Color(0.62, 0.55, 0.78), Color(0.75, 0.62, 0.72), Color(0.30, 0.40, 0.36), Color(0.25, 0.36, 0.34)])
		draw_polygon(pts, cols)
	# мягкое «дыхание» солнечного света слева
	var sun := Vector2(sz.x * 0.05, sz.y * 0.55)
	var breathe := 0.5 + 0.5 * sin(_t * 0.5)
	for i in range(5):
		draw_circle(sun, sz.y * (0.18 + i * 0.12), Color(1.0, 0.85, 0.65, (0.05 - i * 0.008) * (0.7 + 0.3 * breathe)))
	# блики на воде (нижняя треть)
	for i in range(22):
		var k := float(i) / 22.0
		var x := fmod(k * sz.x * 1.3 + sin(_t * 0.2 + i) * 20.0, sz.x)
		var y := sz.y * (0.78 + 0.18 * fmod(k * 7.31, 1.0))
		var a := 0.12 * (0.5 + 0.5 * sin(_t * 1.3 + i * 1.7))
		draw_rect(Rect2(x, y, 26.0 + 20.0 * fmod(k * 3.7, 1.0), 2.0), Color(1.0, 0.95, 0.85, a))
	# лепестки
	for pt in _petals:
		var p: Vector2 = pt["pos"] * sz
		var s: float = pt["size"]
		var r: float = pt["rot"]
		var d := Vector2(cos(r), sin(r))
		var n := Vector2(-d.y, d.x) * 0.55
		var poly := PackedVector2Array([p + d * s, p + n * s, p - d * s, p - n * s])
		draw_colored_polygon(poly, Color(1.0, 0.78, 0.85, 0.75))
	# светлячки (поверх тумана — рисуем позже через дочерний слой не нужно: туман полупрозрачен)
	for f in _flies:
		var p: Vector2 = f["pos"] * sz
		var fs: float = f["seed"]
		var pulse := 0.55 + 0.45 * sin(_t * 2.0 + fs)
		var c: Color = f["color"]
		var fsz: float = f["size"]
		draw_circle(p, fsz * 5.0, Color(c.r, c.g, c.b, 0.10 * pulse))
		draw_circle(p, fsz * 2.0, Color(c.r, c.g, c.b, 0.25 * pulse))
		draw_circle(p, fsz, Color(1, 1, 0.95, 0.95 * pulse))
