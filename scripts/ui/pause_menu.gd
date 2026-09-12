extends CanvasLayer
## Пауза: продолжить, настройки, сохранить, выйти в меню.

signal resumed

var _root: Control
var _slot_box: HBoxContainer
var _main_box: VBoxContainer

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.theme = UITheme.make_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.1, 0.16, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(panel)
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 12)
	panel.add_child(_main_box)
	_main_box.add_child(UITheme.title(tr("PAUSE_TITLE"), 40))

	var b_resume := UITheme.button(tr("RESUME"))
	b_resume.pressed.connect(resume)
	_main_box.add_child(b_resume)
	var b_settings := UITheme.button(tr("MENU_SETTINGS"))
	b_settings.pressed.connect(_open_settings)
	_main_box.add_child(b_settings)
	var b_save := UITheme.button(tr("SAVE_GAME"))
	b_save.pressed.connect(func(): _slot_box.visible = not _slot_box.visible)
	_main_box.add_child(b_save)

	_slot_box = HBoxContainer.new()
	_slot_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_box.add_theme_constant_override("separation", 8)
	_slot_box.visible = false
	for i in range(SaveManager.SLOT_COUNT):
		var sb := UITheme.button("%s %d" % [tr("SLOT"), i + 1], 80)
		sb.pressed.connect(func():
			SaveManager.active_slot = i
			SaveManager.save_to_slot(i)
			_slot_box.visible = false
		)
		_slot_box.add_child(sb)
	_main_box.add_child(_slot_box)

	var b_menu := UITheme.button(tr("TO_MENU"))
	b_menu.pressed.connect(func():
		SaveManager.autosave()
		AudioManager.set_ambient("wind", 0.25)
		SceneRouter.go_to(SceneRouter.MAIN_MENU, 0.8)
	)
	_main_box.add_child(b_menu)
	UITheme.fade_in(panel, 0.3)
	b_resume.grab_focus()
	# приглушаем звук
	var idx := AudioServer.get_bus_index("Master")
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_method(func(v): AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Settings.master_volume * v, 0.0001))), 1.0, 0.35, 0.4)

func _open_settings() -> void:
	var s = load("res://scenes/ui/settings_screen.tscn").instantiate()
	s.embedded = true
	_root.visible = false
	s.closed.connect(func(): _root.visible = true)
	add_child(s)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _root.visible:
		resume()
		get_viewport().set_input_as_handled()

func resume() -> void:
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Settings.master_volume, 0.0001)))
	get_tree().paused = false
	resumed.emit()
	queue_free()
