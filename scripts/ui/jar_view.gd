class_name JarView
extends Control
## Банка с живыми светлячками внутри (рисуется через _draw). Используется в HUD и в окне банки.

const TEX_JAR := preload("res://assets/ui/jar.png")
const TEX_GLOW := preload("res://assets/textures/particle_glow.png")

@export var big := false          # крупный режим для окна банки (больше светлячков, следы)
@export var highlight := -1       # индекс подсвеченного (выбранного) светлячка

var _flies: Array = []            # {pos, vel, phase, color, size, idx}
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameState.jar_changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	var old := _flies
	_flies = []
	var per := 3 if big else 1
	for i in range(GameState.jar.size()):
		var f: Dictionary = GameState.jar[i]
		var col := FireflyData.color_of(f)
		var rar := str(f.get("rarity", "common"))
		for k in range(per):
			var prev = old[i * per + k] if i * per + k < old.size() else null
			_flies.append({
				"pos": prev["pos"] if prev != null else Vector2(randf(), randf()),
				"vel": Vector2.ZERO,
				"phase": randf() * TAU,
				"speed": randf_range(0.7, 1.3),
				"color": col,
				"size": (1.3 if rar == "legendary" else (1.1 if rar == "rare" else 1.0)),
				"idx": i,
			})
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	var inner := _inner_rect()
	for fl in _flies:
		var p: Vector2 = fl["pos"]
		var ph: float = fl["phase"]
		var sp: float = fl["speed"]
		# броуновское блуждание в нормированных координатах
		var wander := Vector2(sin(_t * 0.9 * sp + ph) + sin(_t * 2.3 * sp + ph * 1.7) * 0.4, cos(_t * 1.1 * sp + ph * 0.6) + sin(_t * 1.9 * sp + ph) * 0.4)
		var v: Vector2 = fl["vel"]
		v = v.lerp(wander * 0.12, delta * 2.0)
		p += v * delta
		# мягкий отскок от стенок
		if p.x < 0.05: v.x = absf(v.x); p.x = 0.05
		if p.x > 0.95: v.x = -absf(v.x); p.x = 0.95
		if p.y < 0.05: v.y = absf(v.y); p.y = 0.05
		if p.y > 0.95: v.y = -absf(v.y); p.y = 0.95
		fl["pos"] = p
		fl["vel"] = v
	if not _flies.is_empty() or big:
		queue_redraw()
	if inner.size == Vector2.ZERO:
		return

func _inner_rect() -> Rect2:
	# область стекла внутри банки (по пропорциям текстуры)
	var r := _jar_rect()
	return Rect2(r.position + Vector2(r.size.x * 0.15, r.size.y * 0.30), Vector2(r.size.x * 0.70, r.size.y * 0.62))

func _jar_rect() -> Rect2:
	var ts := TEX_JAR.get_size()
	var sc := minf(size.x / ts.x, size.y / ts.y)
	var s := ts * sc
	return Rect2((size - s) * 0.5, s)

func _draw() -> void:
	var jr := _jar_rect()
	var inner := _inner_rect()
	# лёгкое свечение внутри банки, если есть светлячки
	if not _flies.is_empty():
		var avg := Color(0, 0, 0, 0)
		for fl in _flies:
			avg += fl["color"]
		avg /= float(_flies.size())
		var pulse := 0.5 + 0.5 * sin(_t * 1.5)
		draw_texture_rect(TEX_GLOW, inner.grow(inner.size.x * 0.25), false, Color(avg.r, avg.g, avg.b, 0.18 + 0.08 * pulse))
	# банка (за светлячками — стекло полупрозрачно, они видны сквозь)
	draw_texture_rect(TEX_JAR, jr, false)
	var glow_size := inner.size.x * (0.30 if big else 0.42)
	for fl in _flies:
		var p: Vector2 = inner.position + (fl["pos"] as Vector2) * inner.size
		var c: Color = fl["color"]
		var ph: float = fl["phase"]
		var blink := 0.55 + 0.45 * sin(_t * 3.0 * fl["speed"] + ph)
		var sz: float = glow_size * fl["size"]
		var sel := int(fl["idx"]) == highlight
		if sel:
			sz *= 1.5
			blink = 0.8 + 0.2 * sin(_t * 8.0)
		var gs := Vector2(sz, sz)
		draw_texture_rect(TEX_GLOW, Rect2(p - gs * 0.5, gs), false, Color(c.r, c.g, c.b, 0.55 * blink))
		draw_circle(p, (3.2 if big else 2.2) * fl["size"], Color(1, 1, 0.95, 0.9 * blink))
		draw_circle(p, (1.6 if big else 1.1) * fl["size"], Color(1, 1, 1, blink))
	# «+N» при переполнении
	if GameState.jar_is_over():
		var over := GameState.jar_used_slots() - GameState.JAR_SLOTS
		var font := ThemeDB.fallback_font
		draw_string(font, jr.position + Vector2(jr.size.x * 0.72, jr.size.y * 0.3), "+%d" % over, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 0.75, 0.6))
