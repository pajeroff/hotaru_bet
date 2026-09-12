extends Node2D
## Процедурно нарисованная поляна: трава, тропинки, пруд, кусты, деревья, туманная граница.

const HALF := Vector2(900, 620) # полуразмер поляны

var _grass_tufts: Array = []
var _trees: Array = []
var _bushes: Array = []
var _stones: Array = []
var _t := 0.0
var player_pos := Vector2.ZERO
var wind := 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(900):
		var p := Vector2(rng.randf_range(-HALF.x, HALF.x), rng.randf_range(-HALF.y, HALF.y))
		if p.length() < 150 or _in_pond(p) or _on_path(p):
			continue
		_grass_tufts.append({"pos": p, "h": rng.randf_range(8, 16), "seed": rng.randf() * 10.0, "phase": 0.0})
	# деревья по краям
	for i in range(70):
		var ang := rng.randf() * TAU
		var r := rng.randf_range(0.86, 1.05)
		var p := Vector2(cos(ang) * HALF.x * r, sin(ang) * HALF.y * r)
		_trees.append({"pos": p, "r": rng.randf_range(38, 62), "seed": rng.randf() * 10.0, "shade": rng.randf_range(0.0, 0.15)})
	for i in range(40):
		var p := Vector2(rng.randf_range(-HALF.x, HALF.x), rng.randf_range(-HALF.y, HALF.y))
		if p.length() < 220 or _in_pond(p) or _on_path(p) or (absf(p.x) < HALF.x * 0.7 and absf(p.y) < HALF.y * 0.7):
			continue
		_bushes.append({"pos": p, "r": rng.randf_range(20, 34), "seed": rng.randf() * 10.0})
	for i in range(25):
		var p := Vector2(rng.randf_range(-HALF.x * 0.8, HALF.x * 0.8), rng.randf_range(-HALF.y * 0.8, HALF.y * 0.8))
		if p.length() < 130 or _in_pond(p):
			continue
		_stones.append({"pos": p, "r": rng.randf_range(4, 9)})
	_build_collision()

func _in_pond(p: Vector2) -> bool:
	var c := Vector2(430, 250)
	var d := (p - c) / Vector2(150, 95)
	return d.length() < 1.0

func _on_path(p: Vector2) -> bool:
	# тропинки: от храма вниз, влево-вверх, вправо к пруду
	if absf(p.x) < 28 and p.y > 0 and p.y < HALF.y: return true
	var a := p - Vector2(0, 0)
	var dir1 := Vector2(-0.8, -0.6)
	var proj := a.dot(dir1)
	if proj > 0 and proj < 700 and absf(a.cross(dir1)) < 26: return true
	var dir2 := Vector2(0.85, 0.5)
	var proj2 := a.dot(dir2)
	if proj2 > 0 and proj2 < 330 and absf(a.cross(dir2)) < 22: return true
	return false

func _build_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	# внешняя граница — эллипс из сегментов
	var pts := PackedVector2Array()
	var n := 48
	for i in range(n + 1):
		var ang := TAU * i / n
		pts.append(Vector2(cos(ang) * HALF.x * 0.92, sin(ang) * HALF.y * 0.92))
	for i in range(n):
		var seg := SegmentShape2D.new()
		seg.a = pts[i]
		seg.b = pts[i + 1]
		var cs := CollisionShape2D.new()
		cs.shape = seg
		body.add_child(cs)
	# пруд (эллипс из полигона)
	var pond := CollisionPolygon2D.new()
	var ppts := PackedVector2Array()
	for i in range(24):
		var ang := TAU * i / 24.0
		ppts.append(Vector2(430, 250) + Vector2(cos(ang) * 140, sin(ang) * 86))
	pond.polygon = ppts
	body.add_child(pond)
	# храм
	var temple := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(150, 110)
	temple.shape = rect
	temple.position = Vector2(0, -20)
	body.add_child(temple)
	for b in _bushes:
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = b["r"] * 0.7
		cs.shape = c
		cs.position = b["pos"]
		body.add_child(cs)
	for t in _trees:
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = t["r"] * 0.4
		cs.shape = c
		cs.position = t["pos"]
		body.add_child(cs)

func _process(delta: float) -> void:
	_t += delta
	wind = sin(_t * 0.7) * 0.5 + sin(_t * 1.9) * 0.3
	queue_redraw()

func _draw() -> void:
	# земля
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	draw_rect(Rect2(-HALF * 1.6, HALF * 3.2), Color(0.42, 0.56, 0.42))
	# поляна (эллипс)
	var pts := PackedVector2Array()
	var n := 64
	for i in range(n):
		var ang := TAU * i / n
		var r := 1.0 + sin(ang * 5.0) * 0.02 + cos(ang * 3.0) * 0.015
		pts.append(Vector2(cos(ang) * HALF.x * r, sin(ang) * HALF.y * r))
	draw_colored_polygon(pts, Color(0.55, 0.72, 0.50))
	# пятна травы
	for i in range(60):
		var p := Vector2(rng.randf_range(-HALF.x, HALF.x), rng.randf_range(-HALF.y, HALF.y))
		draw_circle(p, rng.randf_range(40, 110), Color(0.5, 0.7, 0.46, 0.35))
	for i in range(40):
		var p := Vector2(rng.randf_range(-HALF.x, HALF.x), rng.randf_range(-HALF.y, HALF.y))
		draw_circle(p, rng.randf_range(30, 80), Color(0.62, 0.78, 0.52, 0.3))
	# тропинки
	_path(Vector2(0, 60), Vector2(0, HALF.y), 30)
	_path(Vector2(-40, -30), Vector2(-560, -450), 26)
	_path(Vector2(40, 20), Vector2(300, 175), 22)
	# камни у тропинок
	for s in _stones:
		draw_circle(s["pos"] + Vector2(1, 2), s["r"], Color(0.35, 0.36, 0.34, 0.3))
		draw_circle(s["pos"], s["r"], Color(0.70, 0.70, 0.66))
	# пруд
	var pc := Vector2(430, 250)
	draw_set_transform(pc, 0, Vector2(1.6, 1.0))
	draw_circle(Vector2.ZERO, 100, Color(0.78, 0.76, 0.6))
	draw_circle(Vector2.ZERO, 92, Color(0.55, 0.72, 0.80, 0.95))
	draw_circle(Vector2.ZERO, 75, Color(0.50, 0.68, 0.80, 0.9))
	for i in range(3):
		var rr := 30 + i * 20 + fmod(_t * 12.0, 20.0)
		draw_arc(Vector2.ZERO, rr, 0, TAU, 40, Color(1, 1, 1, 0.12 * (1.0 - rr / 95.0)), 1.5)
	draw_set_transform(Vector2.ZERO)
	# лилии
	draw_circle(pc + Vector2(-60, 20), 9, Color(0.45, 0.65, 0.42))
	draw_circle(pc + Vector2(-56, 17), 4, Color(1.0, 0.85, 0.9))
	draw_circle(pc + Vector2(40, -25), 8, Color(0.45, 0.65, 0.42))
	# трава (пучки)
	for g in _grass_tufts:
		var p: Vector2 = g["pos"]
		var d := p.distance_to(player_pos)
		var bend := wind * 2.5 + sin(_t * 1.5 + g["seed"]) * 1.5
		if d < 40.0:
			var push := (p - player_pos).normalized().x * (40.0 - d) * 0.25
			g["phase"] = lerpf(g["phase"], push, 0.2)
		else:
			g["phase"] = lerpf(g["phase"], 0.0, 0.05)
		bend += g["phase"]
		var h: float = g["h"]
		var col := Color(0.38, 0.62, 0.36, 0.9)
		draw_line(p, p + Vector2(bend - 3, -h), col, 1.5)
		draw_line(p, p + Vector2(bend + 1, -h * 1.1), col, 1.5)
		draw_line(p, p + Vector2(bend + 4, -h * 0.8), col, 1.5)
	# кусты
	for b in _bushes:
		var p: Vector2 = b["pos"]
		var r: float = b["r"]
		draw_circle(p + Vector2(0, 6), r * 1.05, Color(0.2, 0.3, 0.2, 0.25))
		draw_circle(p, r, Color(0.36, 0.56, 0.36))
		draw_circle(p + Vector2(-r * 0.4, -r * 0.3), r * 0.7, Color(0.42, 0.62, 0.40))
		draw_circle(p + Vector2(r * 0.35, -r * 0.2), r * 0.6, Color(0.46, 0.66, 0.44))
		if fmod(b["seed"], 3.0) < 1.0:
			draw_circle(p + Vector2(-r * 0.2, -r * 0.5), 3, Color(1.0, 0.8, 0.85))
			draw_circle(p + Vector2(r * 0.3, -r * 0.1), 3, Color(1.0, 0.85, 0.9))
	# деревья
	for t in _trees:
		var p: Vector2 = t["pos"]
		var r: float = t["r"]
		var sway := sin(_t * 0.8 + t["seed"]) * 2.0
		draw_circle(p + Vector2(4, 10), r * 1.1, Color(0.15, 0.25, 0.18, 0.28))
		draw_rect(Rect2(p.x - 6, p.y - 8, 12, 24), Color(0.45, 0.35, 0.28))
		var base := Color(0.30, 0.48, 0.34) - Color(t["shade"], t["shade"], t["shade"], 0)
		draw_circle(p + Vector2(sway, -r * 0.5), r, base)
		draw_circle(p + Vector2(sway - r * 0.45, -r * 0.3), r * 0.7, base.lightened(0.08))
		draw_circle(p + Vector2(sway + r * 0.4, -r * 0.35), r * 0.65, base.lightened(0.12))
		draw_circle(p + Vector2(sway, -r * 0.9), r * 0.55, base.lightened(0.18))

func _path(a: Vector2, b: Vector2, w: float) -> void:
	draw_line(a, b, Color(0.72, 0.66, 0.50, 0.55), w + 8)
	draw_line(a, b, Color(0.80, 0.74, 0.56, 0.9), w)
