extends CanvasLayer
## Плавные переходы между сценами через затемнение.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const LOAD_SCREEN := "res://scenes/ui/load_screen.tscn"
const SETTINGS := "res://scenes/ui/settings_screen.tscn"
const WORLD := "res://scenes/world/world.tscn"

var _fade: ColorRect
var _busy := false
var settings_return_scene := MAIN_MENU

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.08, 0.08, 0.14, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func go_to(path: String, duration := 0.6) -> void:
	if _busy:
		return
	_busy = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_fade, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE)
	await tw.finished
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Не удалось загрузить сцену: %s (код %d)" % [path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	_busy = false

func open_settings(from_scene: String) -> void:
	settings_return_scene = from_scene
	go_to(SETTINGS, 0.4)

func start_new_game() -> void:
	GameState.reset_new_game()
	SaveManager.active_slot = SaveManager.first_free_slot()
	go_to(WORLD, 0.9)

func load_game(slot: int) -> void:
	if SaveManager.load_slot(slot):
		SaveManager.active_slot = slot
		go_to(WORLD, 0.9)
