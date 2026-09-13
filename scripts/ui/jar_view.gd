class_name JarView
extends Control
## Стеклянная банка (рисуется процедурно) с живыми светлячками внутри.

const TEX_GLOW := preload("res://assets/textures/particle_glow.png")

@export var big := false
@export var highlight := -1

var _flies: Array = []
var _t := 0.0
var _sprites := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.jar_changed.connect(_rebuild)
	_rebuild()

func _sprite_for(kind: String) -> Texture2D:
	if not _sprites.has(kind):
		var path := "res://assets/sprites/fireflies/%s.png" % kind
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
		else:
			var img := Image.new()
			if img.load(path) == OK:
				tex = ImageTexture.create_from_image(img)
		_sprites[kind] = tex
	return _sprites[kind]

func _rebuild() -> void:
	var old := _flies
	_flies = []
	for i in range(GameState.jar.size()):
		var f: Dictionary = GameState.jar[i]
		var prev = old[i] if i < old.size() else null
		_flies.append({
			"pos": prev["pos"] if prev != null else Vector2(randf_range(0.2, 0.8), randf_range(0.2, 0.8)),
			"vel": Vector2.ZERO,
			"phase": randf() * TAU,
			"speed": randf_range(0.7, 1.3),
			"color": FireflyData.color_of(f),
			"kind": str(f.get("kind", "gold")),
			"size": (1.35 if f.get("rarity") == "legendary" else (1.15 if f.get("rarity") == "rare" else 1.0)),
			"idx": i,
		})
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	for fl in _flies:
		var p: Vector2 = fl["pos"]
		var ph: float = fl["phase"]
		var sp: float = fl["speed"]
		var wander := Vector2(sin(_t * 0.9 * sp + ph) + sin(_t * 2.3 * sp + ph * 1.7) * 0.4, cos(_t * 1.1 * sp + ph * 0.6) + sin(_t * 1.9 * sp + ph) * 0.4)
		var v: Vector2 = fl["vel"]
		v = v.lerp(wander * 0.12, delta * 2.0)
		p += v * delta
		# держим внутри эллипса банки
		var d := p - Vector2(0.5, 0.5)
		var e := Vector2(d.x / 0.40, d.y / 0.42)
		if e.length() > 1.0:
			var n := Vector2(e.x / 0.40, e.y / 0.42).normalized()
			v = v.bounce(n) * 0.6
			p = Vector2(0.5, 0.5) + Vector2(e.normalized().x * 0.40, e.normalized().y * 0.42) * 0.98
		fl["pos"] = p
		fl["vel"] = v
	queue_redraw()

func _jar_rect() -> Rect2:
	var aspect := 0.66
	var h := size.y
	var w := h * aspect
	if w > size.x:
		w = size.x
		h = w / aspect
	return Rect2((size - Vector2(w, h)) * 0.5, Vector2(w, h))

func _draw() -> void:
	var jr := _jar_rect()
	var w := jr.size.x
	var h := jr.size.y
	var o := jr.position
	# --- силуэт банки ---
	var body := Rect2(o + Vector2(0, h * 0.20), Vector2(w, h * 0.80))
	var neck := Rect2(o + Vector2(w * 0.22, h * 0.10), Vector2(w * 0.56, h * 0.12))
	var cork := Rect2(o + Vector2(w * 0.18, 0), Vector2(w * 0.64, h * 0.12))
	var glass := Color(0.55, 0.85, 0.90, 0.16)
	var edge := Color(0.70, 0.95, 0.98, 0.55)
	# свечение внутри
	if not _flies.is_empty():
		var avg := Color(0, 0, 0, 0)
		for fl in _flies:
			avg += fl["color"]
		avg /= float(_flies.size())
		var pulse := 0.5 + 0.5 * sin(_t * 1.5)
		draw_texture_rect(TEX_GLOW, body.grow(w * 0.3), false, Color(avg.r, avg.g, avg.b, 0.22 + 0.10 * pulse))
	_rounded(body, w * 0.18, glass)
	_rounded(neck, w * 0.06, glass)
	_rounded(cork, w * 0.08, Color(0.25, 0.17, 0.12, 0.95))
	_rounded(Rect2(cork.position + Vector2(w * 0.06, 0), Vector2(cork.size.x - w * 0.12, cork.size.y * 0.35)), w * 0.04, Color(0.38, 0.27, 0.19, 0.95))
	# блик
	draw_rect(Rect2(body.position + Vector2(w * 0.12, h * 0.10), Vector2(w * 0.07, h * 0.45)), Color(1, 1, 1, 0.10))
	# --- светлячки ---
	var inner := Rect2(body.position + Vector2(w * 0.06, h * 0.04), body.size - Vector2(w * 0.12, h * 0.10))
	var fsz := w * (0.30 if big else 0.42)
	for fl in _flies:
		var p: Vector2 = inner.position + (fl["pos"] as Vector2) * inner.size
		var c: Color = fl["color"]
		var ph: float = fl["phase"]
		var blink := 0.55 + 0.45 * sin(_t * 3.0 * fl["speed"] + ph)
		var sz: float = fsz * fl["size"]
		var sel := int(fl["idx"]) == highlight
		if sel:
			sz *= 1.4
			blink = 0.85 + 0.15 * sin(_t * 8.0)
		var gs := Vector2(sz, sz) * 1.6
		draw_texture_rect(TEX_GLOW, Rect2(p - gs * 0.5, gs), false, Color(c.r, c.g, c.b, 0.45 * blink))
		var tex := _sprite_for(fl["kind"])
		if tex != null:
			var ss := Vector2(sz, sz)
			var flip := (fl["vel"] as Vector2).x < 0.0
			var rct := Rect2(p - ss * 0.5, ss)
			if flip:
				rct = Rect2(p + Vector2(ss.x * 0.5, -ss.y * 0.5), Vector2(-ss.x, ss.y))
			draw_texture_rect(tex, rct, false, Color(1, 1, 1, 0.75 + 0.25 * blink))
		else:
			draw_circle(p, 3.0 * fl["size"], Color(1, 1, 0.95, blink))
	# кромка стекла поверх
	_rounded_outline(body, w * 0.18, edge)
	_rounded_outline(neck, w * 0.06, edge)

func _rounded(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)

func _rounded_outline(r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = col
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
