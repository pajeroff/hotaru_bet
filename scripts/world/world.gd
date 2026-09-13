extends Node2D
## Корневая сцена игрового мира: собирает поляну, храм, игрока, камеру, светлячков, HUD.

const GladeScript := preload("res://scripts/world/glade.gd")
const TempleScript := preload("res://scripts/world/temple.gd")
const PlayerScript := preload("res://scripts/entities/player.gd")
const FirefliesScript := preload("res://scripts/world/firefly_manager.gd")
const CameraScript := preload("res://scripts/world/game_camera.gd")
const AtmosphereScript := preload("res://scripts/world/atmosphere.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const PondScript := preload("res://scripts/world/pond_reflection.gd")
const PauseScript := preload("res://scripts/ui/pause_menu.gd")
const JarScript := preload("res://scripts/ui/jar_panel.gd")

var player
var glade
var fireflies
var hud
var atmosphere
var _pond_reflection
var _autosave_timer := 0.0
var _overlay_open := false

const AUTOSAVE_SEC := 120.0

func _ready() -> void:
	var day_light := CanvasModulate.new()
	day_light.color = Color(1, 1, 1)
	add_child(day_light)

	glade = GladeScript.new()
	add_child(glade)

	_pond_reflection = PondScript.new()
	add_child(_pond_reflection)

	var temple = TempleScript.new()
	temple.position = Vector2(0, 30)
	glade.props_root.add_child(temple)

	player = PlayerScript.new()
	glade.props_root.add_child(player)
	player.moved.connect(func(p): glade.player_pos = p)

	fireflies = FirefliesScript.new()
	fireflies.player = player
	fireflies.z_index = 6
	add_child(fireflies)
	_pond_reflection.fireflies = fireflies

	var cam = CameraScript.new()
	cam.target = player
	cam.set_limits(glade.HALF)
	add_child(cam)
	cam.make_current()
	cam.global_position = player.global_position
	cam.reset_smoothing()

	atmosphere = AtmosphereScript.new()
	add_child(atmosphere)
	atmosphere.attach_modulate(day_light)

	hud = HudScript.new()
	add_child(hud)
	hud.set_firefly_manager(fireflies)
	fireflies.hud = hud

	GameState.running = true
	if SaveManager.seconds_since_save() == INF:
		SaveManager.mark_session_start()
	# предварительно заселяем поляну
	for i in range(FireflyData.target_count(GameState.get_phase(), GameState.weather)):
		fireflies.spawn_one()

func _exit_tree() -> void:
	GameState.running = false

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_SEC:
		_autosave_timer = 0.0
		SaveManager.autosave()

func _unhandled_input(event: InputEvent) -> void:
	if _overlay_open:
		return
	if event.is_action_pressed("pause"):
		_open_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_jar"):
		_open_jar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_inventory"):
		_open_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hotbar_1"):
		Inventory.set_active(0)
	elif event.is_action_pressed("hotbar_2"):
		Inventory.set_active(1)
	elif event.is_action_pressed("hotbar_3"):
		Inventory.set_active(2)
	elif event.is_action_pressed("hotbar_4"):
		Inventory.set_active(3)
	elif event.is_action_pressed("hotbar_5"):
		Inventory.set_active(4)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		fireflies.try_catch()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k := event as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != 0 else k.keycode
		var speed := ""
		match code:
			KEY_F1: speed = "normal"
			KEY_F2: speed = "fast"
			KEY_F3: speed = "faster"
		if speed != "":
			Settings.time_speed = speed
			Settings.save()
			Settings.settings_changed.emit()
			AudioManager.play_sfx("click", -10.0)
			get_viewport().set_input_as_handled()

func _open_pause() -> void:
	_overlay_open = true
	player.input_enabled = false
	get_tree().paused = true
	var pm = PauseScript.new()
	add_child(pm)
	pm.resumed.connect(func():
		_overlay_open = false
		player.input_enabled = true
	)

func _open_inventory() -> void:
	_overlay_open = true
	player.input_enabled = false
	var inv = preload("res://scripts/ui/inventory_panel.gd").new()
	add_child(inv)
	inv.closed.connect(func():
		_overlay_open = false
		player.input_enabled = true
	)

func _open_jar() -> void:
	_overlay_open = true
	player.input_enabled = false
	var jp = JarScript.new()
	add_child(jp)
	jp.closed.connect(func():
		_overlay_open = false
		player.input_enabled = true
	)
