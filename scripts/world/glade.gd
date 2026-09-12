extends Node2D
## Поляна: шейдерная земля с тропинками, пруд с водой, спрайты деревьев/кустов/камней с тенями,
## Y-сортировка, ветер, реакция травы на игрока.

const HALF := Vector2(900, 620)
const POND_CENTER := Vector2(430, 250)
const POND_RADII := Vector2(160, 100)

const TEX_GRASS := preload("res://assets/textures/grass.png")
const TEX_PATH := preload("res://assets/textures/path.png")
const TEX_SHADOW := preload("res://assets/textures/shadow_blob.png")
const SPR := {
	"tree_a": preload("res://assets/sprites/tree_a.png"),
	"tree_b": preload("res://assets/sprites/tree_b.png"),
	"tree_sakura": preload("res://assets/sprites/tree_sakura.png"),
	"bush": preload("res://assets/sprites/bush.png"),
	"bush_flower": preload("res://assets/sprites/bush_flower.png"),
	"rock": preload("res://assets/sprites/rock.png"),
	"lantern": preload("res://assets/sprites/lantern.png"),
	"grass_tuft": preload("res://assets/sprites/grass_tuft.png"),
}
const SH_WIND := preload("res://shaders/wind_sway.gdshader")
const SH_GROUND := preload("res://shaders/ground.gdshader")
const SH_WATER := preload("res://shaders/water.gdshader")

var player_pos := Vector2.ZERO
var wind := 0.0
var _t := 0.0
var _swaying: Array = [] # [Sprite2D, ShaderMaterial]
var _grass: Array = []   # [Sprite2D, ShaderMaterial, base_pos]
var props_root: Node2D   # Y-sorted контейнер (сюда же кладём игрока)

func _ready() -> void:
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
	far.color = Color(0.16, 0.26, 0.20)
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
	m.set_shader_parameter("tile_scale", 5.0)
	ground.material = m
	add_child(ground)

func _white_tex() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

func _make_path_mask() -> ImageTexture:
	var s := 256
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
	img.resize(s / 2, s / 2, Image.INTERPOLATE_BILINEAR)
	img.resize(s, s, Image.INTERPOLATE_CUBIC)
	return ImageTexture.create_from_image(img)

func _on_path(p: Vector2) -> bool:
	if absf(p.x) < 30 and p.y > 0 and p.y < HALF.y: return true
	var dir1 := Vector2(-0.8, -0.6).normalized()
	var proj := p.dot(dir1)
	if proj > 0 and proj < 720 and absf(p.cross(dir1)) < 28: return true
	var dir2 := Vector2(0.85, 0.5).normalized()
	var proj2 := p.dot(dir2)
	if proj2 > 0 and proj2 < 330 and absf(p.cross(dir2)) < 24: return true
	# площадка у храма
	if (p / Vector2(190, 140)).length() < 1.0: return true
	return false

func _in_pond(p: Vector2, margin := 1.0) -> bool:
	return ((p - POND_CENTER) / (POND_RADII * margin)).length() < 1.0

# ---------- пруд ----------
func _build_pond() -> void:
	var pond := Sprite2D.new()
	pond.texture = _white_tex()
	pond.position = POND_CENTER
	pond.scale = POND_RADII * 2.0 / Vector2(pond.texture.get_size())
	pond.z_index = -1
	var m := ShaderMaterial.new()
	m.shader = SH_WATER
	pond.material = m
	add_child(pond)

# ---------- пропсы ----------
func _add_prop(kind: String, pos: Vector2, scale_mul := 1.0, sway := true, shadow := 1.0) -> Sprite2D:
	var spr := Sprite2D.new()
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
	if sway:
		var m := ShaderMaterial.new()
		m.shader = SH_WIND
		m.set_shader_parameter("phase", randf() * TAU)
		m.set_shader_parameter("strength", 0.02 if kind.begins_with("tree") else 0.035)
		spr.material = m
		_swaying.append([spr, m])
	props_root.add_child(spr)
	return spr

func _populate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# деревья кольцом по краю (плотный лес)
	for ring in [1.0, 1.12, 1.25]:
		var n := int(48 * ring)
		for i in range(n):
			var ang := TAU * i / n + rng.randf_range(-0.05, 0.05)
			var r := rng.randf_range(0.9, 1.02) * ring
			var p := Vector2(cos(ang) * HALF.x * r, sin(ang) * HALF.y * r)
			var kind := "tree_a" if rng.randf() < 0.55 else ("tree_b" if rng.randf() < 0.75 else "tree_sakura")
			_add_prop(kind, p, rng.randf_range(0.85, 1.15), true, 1.0)
	# отдельные деревья внутри
	for i in range(6):
		var p := Vector2(rng.randf_range(-HALF.x * 0.8, HALF.x * 0.8), rng.randf_range(-HALF.y * 0.8, HALF.y * 0.8))
		if p.length() < 300 or _in_pond(p, 1.4) or _on_path(p): continue
		_add_prop("tree_sakura" if rng.randf() < 0.5 else "tree_a", p, rng.randf_range(0.8, 1.0))
	# кусты
	for i in range(40):
		var p := Vector2(rng.randf_range(-HALF.x * 0.85, HALF.x * 0.85), rng.randf_range(-HALF.y * 0.85, HALF.y * 0.85))
		if p.length() < 240 or _in_pond(p, 1.3) or _on_path(p): continue
		_add_prop("bush_flower" if rng.randf() < 0.4 else "bush", p, rng.randf_range(0.7, 1.1), true, 0.8)
	# камни
	for i in range(18):
		var p := Vector2(rng.randf_range(-HALF.x * 0.85, HALF.x * 0.85), rng.randf_range(-HALF.y * 0.85, HALF.y * 0.85))
		if p.length() < 200 or _in_pond(p, 1.15): continue
		_add_prop("rock", p, rng.randf_range(0.5, 1.0), false, 0.7)
	# камни у пруда
	for i in range(7):
		var ang := rng.randf() * TAU
		var p := POND_CENTER + Vector2(cos(ang) * POND_RADII.x * 1.08, sin(ang) * POND_RADII.y * 1.1)
		_add_prop("rock", p, rng.randf_range(0.35, 0.6), false, 0.5)
	# пучки травы (много, с ветром и реакцией на игрока)
	for i in range(220):
		var p := Vector2(rng.randf_range(-HALF.x * 0.9, HALF.x * 0.9), rng.randf_range(-HALF.y * 0.9, HALF.y * 0.9))
		if p.length() < 200 or _in_pond(p, 1.15) or _on_path(p): continue
		var spr := _add_prop("grass_tuft", p, rng.randf_range(0.5, 0.9), true, 0.0)
		spr.modulate = Color(1, 1, 1).lerp(Color(0.85, 0.95, 0.8), rng.randf())
		_grass.append([spr, spr.material, p])
	# фонари вдоль тропинки к храму
	for y in [180, 320, 460]:
		_add_prop("lantern", Vector2(-48, y), 0.7, false, 0.6)
		_add_prop("lantern", Vector2(48, y), 0.7, false, 0.6)

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
	var pond := CollisionPolygon2D.new()
	var ppts := PackedVector2Array()
	for i in range(24):
		var ang := TAU * i / 24.0
		ppts.append(POND_CENTER + Vector2(cos(ang) * POND_RADII.x * 0.95, sin(ang) * POND_RADII.y * 0.95))
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
			if SPR[k] == s.texture: tex_name = k
		var r := 0.0
		match tex_name:
			"tree_a", "tree_b", "tree_sakura": r = 18.0 * s.scale.x
			"bush", "bush_flower": r = 26.0 * s.scale.x
			"rock": r = 22.0 * s.scale.x
			"lantern": r = 10.0
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
		var d := p.distance_to(player_pos)
		var push := 0.0
		if d < 46.0:
			push = signf(p.x - player_pos.x) * (1.0 - d / 46.0)
		var cur: float = m.get_shader_parameter("player_push")
		m.set_shader_parameter("player_push", lerpf(cur, push, delta * 8.0))
		spr.visible = d < 1400.0
