extends Node2D
## Поляна: шейдерная земля с тропинками, пруд с водой, спрайты деревьев/кустов/камней с тенями,
## Y-сортировка, ветер, реакция травы на игрока.

const HALF := Vector2(1800, 1250)
const POND_CENTER := Vector2(760, 480)
const POND_RADII := Vector2(260, 160)
const POND2_CENTER := Vector2(-1100, -650)
const POND2_RADII := Vector2(150, 100)

const TEX_GRASS := preload("res://assets/textures/grass.png")
const TEX_PATH := preload("res://assets/textures/path.png")
const TEX_SHADOW := preload("res://assets/textures/shadow_blob.png")
const SPRITE_NAMES: Array[String] = ["tree_a", "tree_b", "tree_sakura", "bush", "bush_flower", "rock", "lantern", "grass_tuft", "bench", "well", "torii", "stupa", "mushrooms", "log", "flowers", "signpost", "reeds", "tree_old", "fox_statue", "stump"]
var SPR := {}
const SWAY_KINDS: Array[String] = ["tree_a", "tree_b", "tree_sakura", "tree_old", "bush", "bush_flower", "grass_tuft", "flowers", "reeds", "mushrooms"]
const TALL_KINDS: Array[String] = ["tree_a", "tree_b", "tree_sakura", "tree_old", "torii", "well"]
const SH_WIND := preload("res://shaders/wind_sway.gdshader")
const SH_GROUND := preload("res://shaders/ground.gdshader")
const SH_WATER := preload("res://shaders/water.gdshader")

var player_pos := Vector2.ZERO
var wind := 0.0
var _t := 0.0
var _swaying: Array = [] # [Sprite2D, ShaderMaterial]
var _grass: Array = []   # [Sprite2D, ShaderMaterial, base_pos]
var props_root: Node2D   # Y-sorted контейнер (сюда же кладём игрока)
var _tall: Array = []    # высокие спрайты, которые становятся полупрозрачными над игроком
var _butterflies: Array = []
var _birds: Array = []
var _anim_root: Node2D

func _ready() -> void:
	for n in SPRITE_NAMES:
		var tex := load("res://assets/sprites/%s.png" % n) as Texture2D
		if tex == null:
			push_warning("Спрайт не найден или не импортирован: " + n)
			continue
		SPR[n] = tex
	_build_ground()
	_build_pond()
	props_root = Node2D.new()
	props_root.y_sort_enabled = true
	props_root.z_index = 2
	add_child(props_root)
	_populate()
	_build_collision()

# ---------- земля ----------
func _build_ground() -> void:
	# фон дальнего леса за поляной
	var far := ColorRect.new()
	far.color = Color(0.12, 0.20, 0.16)
	far.position = -HALF * 2.0
	far.size = HALF * 4.0
	far.z_index = -3
	add_child(far)

	var ground := Sprite2D.new()
	ground.texture = _white_tex()
	ground.scale = HALF * 2.0 * 1.15 / Vector2(ground.texture.get_size())
	ground.z_index = -2
	var m := ShaderMaterial.new()
	m.shader = SH_GROUND
	m.set_shader_parameter("grass_tex", TEX_GRASS)
	m.set_shader_parameter("path_tex", TEX_PATH)
	m.set_shader_parameter("path_mask", _make_path_mask())
	m.set_shader_parameter("tile_scale", 10.0)
	ground.material = m
	add_child(ground)

func _white_tex() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _make_path_mask() -> ImageTexture:
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_R8)
	img.fill(Color.BLACK)
	var world_from_uv := func(x: int, y: int) -> Vector2:
		return Vector2((float(x) / s - 0.5) * HALF.x * 2.3, (float(y) / s - 0.5) * HALF.y * 2.3)
	for y in range(s):
		for x in range(s):
			var p: Vector2 = world_from_uv.call(x, y)
			if _on_path(p):
				img.set_pixel(x, y, Color.WHITE)
	# мягкие края
	img.resize(int(s / 2.0), int(s / 2.0), Image.INTERPOLATE_BILINEAR)
	img.resize(s, s, Image.INTERPOLATE_CUBIC)
	return ImageTexture.create_from_image(img)

const PATHS := [
	[Vector2(0, 60), Vector2(0, 1150), 34],          # на юг
	[Vector2(0, 0), Vector2(-1000, -600), 30],       # на северо-запад к малому пруду
	[Vector2(0, 0), Vector2(520, 380), 26],          # к большому пруду
	[Vector2(0, 700), Vector2(1200, 900), 26],       # на юго-восток к торие
	[Vector2(0, 700), Vector2(-1250, 750), 26],      # на юго-запад к колодцу
	[Vector2(0, 0), Vector2(900, -800), 24],         # на северо-восток к старому дереву
]

func _on_path(p: Vector2) -> bool:
	for seg in PATHS:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var w: float = seg[2]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(p) < w:
			return true
	if (p / Vector2(210, 160)).length() < 1.0: return true
	if ((p - Vector2(-1250, 750)) / Vector2(120, 90)).length() < 1.0: return true
	if ((p - Vector2(1200, 900)) / Vector2(110, 80)).length() < 1.0: return true
	return false

func _in_pond(p: Vector2, margin := 1.0) -> bool:
	if ((p - POND_CENTER) / (POND_RADII * margin)).length() < 1.0: return true
	return ((p - POND2_CENTER) / (POND2_RADII * margin)).length() < 1.0

# ---------- пруд ----------
func _build_pond() -> void:
	for pdata in [[POND_CENTER, POND_RADII], [POND2_CENTER, POND2_RADII]]:
		var c: Vector2 = pdata[0]
		var rr: Vector2 = pdata[1]
		var pond := Sprite2D.new()
		pond.texture = _white_tex()
		pond.position = c
		pond.scale = rr * 2.0 / Vector2(pond.texture.get_size())
		pond.z_index = -1
		var m := ShaderMaterial.new()
		m.shader = SH_WATER
		pond.material = m
		add_child(pond)

# ---------- пропсы ----------
func _add_prop(kind: String, pos: Vector2, scale_mul := 1.0, sway := true, shadow := 1.0) -> Sprite2D:
	var spr := Sprite2D.new()
	if not SPR.has(kind):
		return spr
	spr.texture = SPR[kind]
	spr.position = pos
	spr.scale = Vector2.ONE * scale_mul
	spr.centered = true
	var h := spr.texture.get_height()
	spr.offset = Vector2(0, -h * 0.5 + 6) # "ноги" в точке pos
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if shadow > 0.0:
		var sh := Sprite2D.new()
		sh.texture = TEX_SHADOW
		sh.position = pos + Vector2(6, 4)
		var w := spr.texture.get_width() * scale_mul
		sh.scale = Vector2(w / 128.0 * 0.9, w / 128.0 * 0.35) * shadow
		sh.modulate = Color(0, 0, 0, 0.35)
		sh.z_index = 1
		add_child(sh)
	# окклюдер для теней от фонаря/храма
	if kind.begins_with("tree") or kind == "rock" or kind.begins_with("bush"):
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var pts := PackedVector2Array()
		var rr := (10.0 if kind.begins_with("tree") else 18.0) * scale_mul
		for i in range(8):
			var ang := TAU * i / 8.0
			pts.append(pos + Vector2(cos(ang) * rr, sin(ang) * rr * 0.6))
		poly.polygon = pts
		occ.occluder = poly
		occ.sdf_collision = false
		add_child(occ)
	if sway and SWAY_KINDS.has(kind):
		var m := ShaderMaterial.new()
		m.shader = SH_WIND
		m.set_shader_parameter("phase", randf() * TAU)
		m.set_shader_parameter("player_push", 0.0)
		m.set_shader_parameter("strength", 0.02 if kind.begins_with("tree") else 0.035)
		spr.material = m
		_swaying.append([spr, m])
	if TALL_KINDS.has(kind):
		_tall.append(spr)
	props_root.add_child(spr)
	return spr

func _populate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# плотный лес кольцами по краю
	var rings: Array[float] = [1.0, 1.08, 1.16, 1.25, 1.35]
	for ring in rings:
		var n := int(110 * ring)
		for i in range(n):
			var ang := TAU * i / n + rng.randf_range(-0.03, 0.03)
			var r: float = rng.randf_range(0.93, 1.02) * ring
			var p := Vector2(cos(ang) * HALF.x * r, sin(ang) * HALF.y * r)
			var kind := "tree_a" if rng.randf() < 0.55 else ("tree_b" if rng.randf() < 0.75 else "tree_sakura")
			_add_prop(kind, p, rng.randf_range(0.85, 1.2), true, 1.0)
	# рощицы внутри поляны
	var groves := [Vector2(-700, 300), Vector2(800, -300), Vector2(-500, -1000), Vector2(1200, 300), Vector2(-1400, 100), Vector2(400, 1000)]
	for g in groves:
		var gc: Vector2 = g
		for i in range(rng.randi_range(4, 8)):
			var p := gc + Vector2(rng.randf_range(-180, 180), rng.randf_range(-130, 130))
			if _in_pond(p, 1.4) or _on_path(p): continue
			_add_prop("tree_sakura" if rng.randf() < 0.35 else ("tree_b" if rng.randf() < 0.5 else "tree_a"), p, rng.randf_range(0.8, 1.05))
	# ключевые точки интереса
	_add_prop("tree_old", Vector2(900, -800), 1.0)
	_add_prop("fox_statue", Vector2(830, -720), 0.9, false, 0.6)
	_add_prop("fox_statue", Vector2(970, -720), 0.9, false, 0.6)
	_add_prop("torii", Vector2(1200, 960), 1.0, false, 0.9)
	_add_prop("stupa", Vector2(1290, 880), 0.9, false, 0.7)
	_add_prop("well", Vector2(-1250, 700), 1.0, false, 0.9)
	_add_prop("bench", Vector2(-1330, 800), 0.9, false, 0.7)
	_add_prop("bench", Vector2(-150, 260), 0.85, false, 0.7)
	_add_prop("bench", Vector2(150, 260), 0.85, false, 0.7)
	_add_prop("signpost", Vector2(60, 640), 0.9, false, 0.5)
	_add_prop("signpost", Vector2(-60, 1000), 0.9, false, 0.5)
	_add_prop("stupa", Vector2(-260, -120), 0.8, false, 0.6)
	_add_prop("stupa", Vector2(260, -120), 0.8, false, 0.6)
	_add_prop("torii", Vector2(0, 1120), 0.9, false, 0.9)
	# камыш вокруг прудов
	for pdata in [[POND_CENTER, POND_RADII, 14], [POND2_CENTER, POND2_RADII, 9]]:
		var c: Vector2 = pdata[0]
		var rr: Vector2 = pdata[1]
		var cnt: int = pdata[2]
		for i in range(cnt):
			var ang := rng.randf() * TAU
			var p := c + Vector2(cos(ang) * rr.x * rng.randf_range(1.05, 1.15), sin(ang) * rr.y * rng.randf_range(1.05, 1.2))
			_add_prop("reeds" if rng.randf() < 0.7 else "rock", p, rng.randf_range(0.6, 0.95), true, 0.4)
	# кусты
	for i in range(140):
		var p := Vector2(rng.randf_range(-HALF.x * 0.88, HALF.x * 0.88), rng.randf_range(-HALF.y * 0.88, HALF.y * 0.88))
		if p.length() < 260 or _in_pond(p, 1.3) or _on_path(p): continue
		_add_prop("bush_flower" if rng.randf() < 0.4 else "bush", p, rng.randf_range(0.7, 1.15), true, 0.8)
	# камни, пни, брёвна, грибы, цветы
	var scatter := {"rock": 50, "stump": 22, "log": 14, "mushrooms": 40, "flowers": 90}
	for kind in scatter:
		for i in range(scatter[kind]):
			var p := Vector2(rng.randf_range(-HALF.x * 0.88, HALF.x * 0.88), rng.randf_range(-HALF.y * 0.88, HALF.y * 0.88))
			if p.length() < 230 or _in_pond(p, 1.2) or _on_path(p): continue
			_add_prop(str(kind), p, rng.randf_range(0.55, 1.0), true, 0.6 if kind != "flowers" else 0.0)
	# пучки травы
	for i in range(700):
		var p := Vector2(rng.randf_range(-HALF.x * 0.92, HALF.x * 0.92), rng.randf_range(-HALF.y * 0.92, HALF.y * 0.92))
		if p.length() < 220 or _in_pond(p, 1.15) or _on_path(p): continue
		var spr := _add_prop("grass_tuft", p, rng.randf_range(0.45, 0.9), true, 0.0)
		if spr.material == null:
			continue
		spr.modulate = Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.8), rng.randf())
		_grass.append([spr, spr.material, p])
	# фонари вдоль главной тропы
	var lantern_rows: Array[int] = [200, 380, 560, 760, 940]
	for y in lantern_rows:
		_add_prop("lantern", Vector2(-52, y), 0.7, false, 0.6)
		_add_prop("lantern", Vector2(52, y), 0.7, false, 0.6)
	_build_wildlife()

# ---------- живность: бабочки днём, птицы ----------
func _build_wildlife() -> void:
	_anim_root = Node2D.new()
	_anim_root.z_index = 4
	add_child(_anim_root)
	for i in range(28):
		var b := Node2D.new()
		b.set_script(preload("res://scripts/entities/butterfly.gd"))
		b.position = Vector2(randf_range(-HALF.x * 0.8, HALF.x * 0.8), randf_range(-HALF.y * 0.8, HALF.y * 0.8))
		_anim_root.add_child(b)
		_butterflies.append(b)
	for i in range(6):
		var bird := Node2D.new()
		bird.set_script(preload("res://scripts/entities/bird.gd"))
		bird.position = Vector2(randf_range(-HALF.x, HALF.x), randf_range(-HALF.y, HALF.y))
		_anim_root.add_child(bird)
		_birds.append(bird)

# ---------- коллизии ----------
func _build_collision() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	var n := 48
	for i in range(n):
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var seg := SegmentShape2D.new()
		seg.a = Vector2(cos(a0) * HALF.x * 0.88, sin(a0) * HALF.y * 0.88)
		seg.b = Vector2(cos(a1) * HALF.x * 0.88, sin(a1) * HALF.y * 0.88)
		var cs := CollisionShape2D.new()
		cs.shape = seg
		body.add_child(cs)
	for pdata in [[POND_CENTER, POND_RADII], [POND2_CENTER, POND2_RADII]]:
		var c: Vector2 = pdata[0]
		var rr: Vector2 = pdata[1]
		var pond := CollisionPolygon2D.new()
		var ppts := PackedVector2Array()
		for i in range(24):
			var ang := TAU * i / 24.0
			ppts.append(c + Vector2(cos(ang) * rr.x * 0.95, sin(ang) * rr.y * 0.95))
		pond.polygon = ppts
		body.add_child(pond)
	var temple := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(200, 130)
	temple.shape = rect
	temple.position = Vector2(0, -10)
	body.add_child(temple)
	for c in props_root.get_children():
		if not c is Sprite2D: continue
		var s := c as Sprite2D
		var tex_name := ""
		for k in SPR:
			if SPR[k] == s.texture: tex_name = str(k)
		var r: float = 0.0
		match tex_name:
			"tree_a", "tree_b", "tree_sakura": r = 18.0 * s.scale.x
			"tree_old": r = 40.0 * s.scale.x
			"bush", "bush_flower": r = 26.0 * s.scale.x
			"rock": r = 22.0 * s.scale.x
			"lantern", "signpost", "fox_statue", "stupa": r = 10.0
			"stump": r = 16.0 * s.scale.x
			"log": r = 28.0 * s.scale.x
			"well": r = 40.0 * s.scale.x
			"bench": r = 26.0 * s.scale.x
			"torii": r = 0.0
		if r <= 0.0: continue
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = r
		cs.shape = circ
		cs.position = s.position
		body.add_child(cs)

# ---------- обновление ----------
func _process(delta: float) -> void:
	_t += delta
	wind = sin(_t * 0.7) * 0.5 + sin(_t * 1.9) * 0.3
	for g in _grass:
		var spr: Sprite2D = g[0]
		var m: ShaderMaterial = g[1]
		var p: Vector2 = g[2]
		var d: float = p.distance_to(player_pos)
		if d > 120.0:
			continue
		var push := 0.0
		if d < 46.0:
			push = signf(p.x - player_pos.x) * (1.0 - d / 46.0)
		var cur_v = m.get_shader_parameter("player_push")
		var cur: float = float(cur_v) if cur_v != null else 0.0
		if absf(cur) > 0.001 or absf(push) > 0.001:
			m.set_shader_parameter("player_push", lerpf(cur, push, delta * 8.0))
	# высокие объекты перед игроком становятся полупрозрачными
	for t in _tall:
		var spr: Sprite2D = t
		var dp := spr.position - player_pos
		if dp.length_squared() > 250000.0:
			if spr.modulate.a < 1.0:
				spr.modulate.a = 1.0
			continue
		var h := spr.texture.get_height() * spr.scale.y
		var w := spr.texture.get_width() * spr.scale.x
		var covering := dp.y > 0.0 and dp.y < h * 0.95 and absf(dp.x) < w * 0.45
		var target_a := 0.4 if covering else 1.0
		spr.modulate.a = lerpf(spr.modulate.a, target_a, delta * 8.0)
