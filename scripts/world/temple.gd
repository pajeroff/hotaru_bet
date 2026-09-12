extends Node2D
## Храм: спрайт с внутренним свечением, пульсирующий свет, тень, фонари с огоньками.

const TEX := preload("res://assets/sprites/temple.png")
const TEX_LIGHT := preload("res://assets/textures/light_soft.png")
const TEX_SHADOW := preload("res://assets/textures/shadow_blob.png")
const TEX_GLOW := preload("res://assets/textures/particle_glow.png")
const SH_GLOW := preload("res://shaders/glow_sprite.gdshader")

var _t := 0.0
var _glow := 0.3
var _target_glow := 0.3
var _light: PointLight2D
var _sprite: Sprite2D
var _mat: ShaderMaterial
var _embers: GPUParticles2D
var _lantern_lights: Array = []

func _ready() -> void:
	var sh := Sprite2D.new()
	sh.texture = TEX_SHADOW
	sh.scale = Vector2(3.6, 1.3)
	sh.position = Vector2(8, 26)
	sh.modulate = Color(0, 0, 0, 0.35)
	add_child(sh)

	_sprite = Sprite2D.new()
	_sprite.texture = TEX
	_sprite.scale = Vector2(0.62, 0.62)
	_sprite.offset = Vector2(0, -TEX.get_height() * 0.5 + 40)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mat = ShaderMaterial.new()
	_mat.shader = SH_GLOW
	_sprite.material = _mat
	add_child(_sprite)

	_light = PointLight2D.new()
	_light.texture = TEX_LIGHT
	_light.color = Color(1.0, 0.82, 0.55)
	_light.texture_scale = 3.0
	_light.energy = 0.8
	_light.position = Vector2(0, -60)
	_light.shadow_enabled = true
	_light.shadow_filter = PointLight2D.SHADOW_FILTER_PCF13
	_light.shadow_filter_smooth = 6.0
	_light.shadow_color = Color(0.1, 0.08, 0.2, 0.6)
	add_child(_light)
	var occ := LightOccluder2D.new()
	var poly := OccluderPolygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-90, -20), Vector2(90, -20), Vector2(90, 30), Vector2(-90, 30)])
	occ.occluder = poly
	add_child(occ)

	# искорки, поднимающиеся из дверей храма
	_embers = GPUParticles2D.new()
	_embers.amount = 24
	_embers.lifetime = 4.0
	_embers.texture = TEX_GLOW
	_embers.position = Vector2(0, -50)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(40, 10, 0)
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 8.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.3
	pm.color = Color(1.0, 0.85, 0.5, 0.9)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.9, 0.6, 0))
	grad.add_point(0.2, Color(1, 0.9, 0.6, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1, 0.6, 0.3, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	_embers.process_material = pm
	add_child(_embers)

	# точечные огоньки у фонариков вокруг
	for i in range(6):
		var ang := TAU * i / 6.0 + 0.3
		var l := PointLight2D.new()
		l.texture = TEX_LIGHT
		l.color = Color(1.0, 0.75, 0.45)
		l.texture_scale = 0.5
		l.energy = 0.6
		l.position = Vector2(cos(ang) * 170, sin(ang) * 120 + 10)
		add_child(l)
		_lantern_lights.append(l)

	GameState.temple_changed.connect(func(_l): _update_target())
	GameState.firefly_caught.connect(func(_d): _pulse_burst())
	_update_target()
	_glow = _target_glow

func _update_target() -> void:
	var lvl := clampi(GameState.temple_level, 0, 4)
	var glows: Array[float] = [0.35, 0.7, 1.1, 1.4, 1.7]
	var amounts: Array[int] = [12, 24, 40, 56, 72]
	_target_glow = glows[lvl]
	_embers.amount = amounts[lvl]

func _pulse_burst() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_glow", _target_glow + 0.6, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "_glow", _target_glow, 1.5).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	_t += delta
	_glow = lerpf(_glow, _target_glow, delta * 0.5)
	var beat := 0.85 + 0.15 * (0.5 + 0.5 * sin(_t * 1.4)) * (0.5 + 0.5 * sin(_t * 2.8))
	_light.energy = _glow * beat * 1.3
	_light.texture_scale = 2.6 + _glow * 0.8
	_mat.set_shader_parameter("glow", _glow * beat)
	for i in range(_lantern_lights.size()):
		var l: PointLight2D = _lantern_lights[i]
		l.energy = 0.45 + 0.25 * sin(_t * 3.0 + i * 1.7)
